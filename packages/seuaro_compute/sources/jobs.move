// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

/// Compute-job escrow with optimistic settlement and replay verification
/// (invariants COMP-01, COMP-02).
///
/// Trust tier implemented here: REPLAY. A deterministic job (identified by
/// `spec_hash`) is re-executed by independent verifiers named by the client.
/// No TEE attestation or unverified output can release funds.
///
/// Flow:
///   1. Client `post`s a job: reward, required provider bond, verifier set and
///      quorum, deadlines.
///   2. A provider `accept`s by locking the bond.
///   3. Provider `submit`s a result hash before the result deadline.
///   4. During the challenge window any verifier may `challenge`.
///      - No challenge: after the window, anyone may `finalize`; the provider
///        receives reward + bond.
///      - Challenged: verifiers `vote` with their own replay result. When
///        `quorum` votes agree on a hash, the outcome is fixed and anyone may
///        `close` the job. If that hash matches the provider's, the provider is
///        paid; otherwise the client gets the reward back plus the bond.
///   5. Timeouts keep funds from getting stuck: no provider -> client cancels;
///      no result in time -> client gets reward + bond; dispute without a
///      quorum in time -> client refunded, provider bond returned.
///
/// Every exit pays out exactly reward + bond (the bond is zero before a
/// provider accepts). Residual risk: a verifier quorum that colludes with the
/// provider; clients choose verifiers and quorum (see THREAT-MODEL.md).
module seuaro_compute::jobs;

use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::event;

const ENotClient: u64 = 1;
const ENotProvider: u64 = 2;
const ENotVerifier: u64 = 3;
const EWrongState: u64 = 4;
const EZeroReward: u64 = 5;
const EBadVerifierSet: u64 = 6;
const EBadDeadline: u64 = 7;
const EWrongBond: u64 = 8;
const EConflictOfInterest: u64 = 9;
const ETooLate: u64 = 10;
const ETooEarly: u64 = 11;
const EAlreadyVoted: u64 = 12;
const EBadHash: u64 = 13;

const MAX_VERIFIERS: u64 = 16;
const MAX_WINDOW_MS: u64 = 30 * 24 * 60 * 60 * 1000;
/// After a challenge, verifiers have this long to reach a quorum.
const DISPUTE_WINDOW_MS: u64 = 7 * 24 * 60 * 60 * 1000;

/// Verification trust tiers (COMP-02). Only REPLAY is implemented.
const TIER_REPLAY: u8 = 1;

const OPEN: u8 = 0;
const ASSIGNED: u8 = 1;
const SUBMITTED: u8 = 2;
const DISPUTED: u8 = 3;
const RESOLVED: u8 = 4;

// Settlement outcomes reported in `JobSettled`.
const OUTCOME_CANCELLED: u8 = 0;
const OUTCOME_PAID_OPTIMISTIC: u8 = 1;
const OUTCOME_PAID_BY_QUORUM: u8 = 2;
const OUTCOME_REJECTED_BY_QUORUM: u8 = 3;
const OUTCOME_PROVIDER_TIMEOUT: u8 = 4;
const OUTCOME_DISPUTE_TIMEOUT: u8 = 5;

public struct Job<phantom T> has key {
    id: UID,
    client: address,
    spec_hash: vector<u8>,
    tier: u8,
    reward: Balance<T>,
    bond_required: u64,
    bond: Balance<T>,
    provider: address,
    verifiers: vector<address>,
    quorum: u64,
    accept_by_ms: u64,
    result_window_ms: u64,
    challenge_window_ms: u64,
    result_by_ms: u64,
    challenge_end_ms: u64,
    dispute_end_ms: u64,
    result_hash: vector<u8>,
    voters: vector<address>,
    votes: vector<vector<u8>>,
    /// Set when a quorum agreed: true if it matched the provider's result.
    upheld: bool,
    state: u8,
}

public struct JobPosted has copy, drop {
    job_id: ID,
    client: address,
    spec_hash: vector<u8>,
    tier: u8,
    reward: u64,
    bond_required: u64,
    quorum: u64,
}

public struct JobAccepted has copy, drop { job_id: ID, provider: address, result_by_ms: u64 }

public struct ResultSubmitted has copy, drop { job_id: ID, result_hash: vector<u8>, challenge_end_ms: u64 }

public struct Challenged has copy, drop { job_id: ID, by: address }

public struct Voted has copy, drop { job_id: ID, verifier: address, result_hash: vector<u8> }

public struct JobSettled has copy, drop {
    job_id: ID,
    outcome: u8,
    to_provider: u64,
    to_client: u64,
}

public fun post<T>(
    payment: Coin<T>,
    spec_hash: vector<u8>,
    bond_required: u64,
    verifiers: vector<address>,
    quorum: u64,
    accept_window_ms: u64,
    result_window_ms: u64,
    challenge_window_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let client = ctx.sender();
    let reward = payment.value();
    assert!(reward > 0, EZeroReward);
    assert!(spec_hash.length() == 32, EBadHash);
    let n = verifiers.length();
    assert!(n > 0 && n <= MAX_VERIFIERS && quorum > 0 && quorum <= n, EBadVerifierSet);
    assert!(2 * quorum > n, EBadVerifierSet); // a quorum must be a strict majority
    assert!(no_duplicates(&verifiers) && !verifiers.contains(&client), EBadVerifierSet);
    assert!(
        valid_window(accept_window_ms) && valid_window(result_window_ms) && valid_window(challenge_window_ms),
        EBadDeadline,
    );

    let job = Job<T> {
        id: object::new(ctx),
        client,
        spec_hash,
        tier: TIER_REPLAY,
        reward: payment.into_balance(),
        bond_required,
        bond: balance::zero(),
        provider: @0x0,
        verifiers,
        quorum,
        accept_by_ms: clock.timestamp_ms() + accept_window_ms,
        result_window_ms,
        challenge_window_ms,
        result_by_ms: 0,
        challenge_end_ms: 0,
        dispute_end_ms: 0,
        result_hash: vector[],
        voters: vector[],
        votes: vector[],
        upheld: false,
        state: OPEN,
    };
    let job_id = object::id(&job);
    event::emit(JobPosted {
        job_id,
        client,
        spec_hash: job.spec_hash,
        tier: TIER_REPLAY,
        reward,
        bond_required,
        quorum,
    });
    transfer::share_object(job);
    job_id
}

public fun accept<T>(self: &mut Job<T>, bond: Coin<T>, clock: &Clock, ctx: &TxContext) {
    let provider = ctx.sender();
    assert!(self.state == OPEN, EWrongState);
    assert!(clock.timestamp_ms() <= self.accept_by_ms, ETooLate);
    assert!(provider != self.client && !self.verifiers.contains(&provider), EConflictOfInterest);
    assert!(bond.value() == self.bond_required, EWrongBond);
    self.bond.join(bond.into_balance());
    self.provider = provider;
    self.result_by_ms = clock.timestamp_ms() + self.result_window_ms;
    self.state = ASSIGNED;
    event::emit(JobAccepted { job_id: object::id(self), provider, result_by_ms: self.result_by_ms });
}

public fun submit<T>(self: &mut Job<T>, result_hash: vector<u8>, clock: &Clock, ctx: &TxContext) {
    assert!(ctx.sender() == self.provider, ENotProvider);
    assert!(self.state == ASSIGNED, EWrongState);
    assert!(result_hash.length() == 32, EBadHash);
    let now = clock.timestamp_ms();
    assert!(now <= self.result_by_ms, ETooLate);
    self.result_hash = result_hash;
    self.challenge_end_ms = now + self.challenge_window_ms;
    self.state = SUBMITTED;
    event::emit(ResultSubmitted {
        job_id: object::id(self),
        result_hash: self.result_hash,
        challenge_end_ms: self.challenge_end_ms,
    });
}

public fun challenge<T>(self: &mut Job<T>, clock: &Clock, ctx: &TxContext) {
    let who = ctx.sender();
    assert!(self.verifiers.contains(&who), ENotVerifier);
    assert!(self.state == SUBMITTED, EWrongState);
    let now = clock.timestamp_ms();
    assert!(now <= self.challenge_end_ms, ETooLate);
    self.state = DISPUTED;
    self.dispute_end_ms = now + DISPUTE_WINDOW_MS;
    event::emit(Challenged { job_id: object::id(self), by: who });
}

/// A verifier reports the hash it obtained by replaying the job. When `quorum`
/// verifiers agree on one hash the outcome is fixed; anyone can then `close`.
public fun vote<T>(self: &mut Job<T>, result_hash: vector<u8>, clock: &Clock, ctx: &TxContext) {
    let who = ctx.sender();
    assert!(self.verifiers.contains(&who), ENotVerifier);
    assert!(self.state == DISPUTED, EWrongState);
    assert!(clock.timestamp_ms() <= self.dispute_end_ms, ETooLate);
    assert!(!self.voters.contains(&who), EAlreadyVoted);
    assert!(result_hash.length() == 32, EBadHash);
    self.voters.push_back(who);
    self.votes.push_back(result_hash);
    event::emit(Voted { job_id: object::id(self), verifier: who, result_hash });

    if (count(&self.votes, &result_hash) >= self.quorum) {
        self.upheld = result_hash == self.result_hash;
        self.state = RESOLVED;
    }
}

/// Pay out a dispute the verifier quorum has resolved.
public fun close<T>(self: Job<T>, ctx: &mut TxContext) {
    assert!(self.state == RESOLVED, EWrongState);
    if (self.upheld) {
        let pay = self.reward.value() + self.bond.value();
        settle(self, pay, OUTCOME_PAID_BY_QUORUM, ctx);
    } else {
        settle(self, 0, OUTCOME_REJECTED_BY_QUORUM, ctx);
    }
}

/// Optimistic path: no challenge during the window -> provider is paid.
public fun finalize<T>(self: Job<T>, clock: &Clock, ctx: &mut TxContext) {
    assert!(self.state == SUBMITTED, EWrongState);
    assert!(clock.timestamp_ms() > self.challenge_end_ms, ETooEarly);
    let pay = self.reward.value() + self.bond.value();
    settle(self, pay, OUTCOME_PAID_OPTIMISTIC, ctx);
}

/// Client withdraws a job no provider accepted in time.
public fun cancel<T>(self: Job<T>, clock: &Clock, ctx: &mut TxContext) {
    assert!(ctx.sender() == self.client, ENotClient);
    assert!(self.state == OPEN, EWrongState);
    assert!(clock.timestamp_ms() > self.accept_by_ms, ETooEarly);
    settle(self, 0, OUTCOME_CANCELLED, ctx);
}

/// Provider missed the result deadline: client gets the reward and the bond.
public fun claim_timeout<T>(self: Job<T>, clock: &Clock, ctx: &mut TxContext) {
    assert!(ctx.sender() == self.client, ENotClient);
    assert!(self.state == ASSIGNED, EWrongState);
    assert!(clock.timestamp_ms() > self.result_by_ms, ETooEarly);
    settle(self, 0, OUTCOME_PROVIDER_TIMEOUT, ctx);
}

/// Verifiers failed to reach a quorum in time: client refunded, bond returned.
public fun expire_dispute<T>(self: Job<T>, clock: &Clock, ctx: &mut TxContext) {
    assert!(self.state == DISPUTED, EWrongState);
    assert!(clock.timestamp_ms() > self.dispute_end_ms, ETooEarly);
    let bond = self.bond.value();
    settle(self, bond, OUTCOME_DISPUTE_TIMEOUT, ctx);
}

/// The only path that moves funds out. `to_provider` goes to the provider and
/// the exact remainder of reward + bond to the client.
fun settle<T>(self: Job<T>, to_provider: u64, outcome: u8, ctx: &mut TxContext) {
    let Job {
        id,
        client,
        spec_hash: _,
        tier: _,
        mut reward,
        bond_required: _,
        bond,
        provider,
        verifiers: _,
        quorum: _,
        accept_by_ms: _,
        result_window_ms: _,
        challenge_window_ms: _,
        result_by_ms: _,
        challenge_end_ms: _,
        dispute_end_ms: _,
        result_hash: _,
        voters: _,
        votes: _,
        upheld: _,
        state: _,
    } = self;
    reward.join(bond);
    let total = reward.value();
    assert!(to_provider <= total, EWrongBond);
    let to_client = total - to_provider;
    if (to_provider > 0) {
        transfer::public_transfer(coin::take(&mut reward, to_provider, ctx), provider);
    };
    if (to_client > 0) {
        transfer::public_transfer(coin::take(&mut reward, to_client, ctx), client);
    };
    reward.destroy_zero();
    event::emit(JobSettled { job_id: id.to_inner(), outcome, to_provider, to_client });
    id.delete();
}

fun count(votes: &vector<vector<u8>>, h: &vector<u8>): u64 {
    let mut n = 0;
    let mut i = 0;
    while (i < votes.length()) {
        if (&votes[i] == h) n = n + 1;
        i = i + 1;
    };
    n
}

fun no_duplicates(v: &vector<address>): bool {
    let mut i = 0;
    while (i < v.length()) {
        let mut j = i + 1;
        while (j < v.length()) {
            if (v[i] == v[j]) return false;
            j = j + 1;
        };
        i = i + 1;
    };
    true
}

fun valid_window(ms: u64): bool { ms > 0 && ms <= MAX_WINDOW_MS }

// === Views ===

public fun state<T>(self: &Job<T>): u8 { self.state }

public fun tier<T>(self: &Job<T>): u8 { self.tier }

public fun provider<T>(self: &Job<T>): address { self.provider }

public fun reward_value<T>(self: &Job<T>): u64 { self.reward.value() }

public fun bond_value<T>(self: &Job<T>): u64 { self.bond.value() }

public fun challenge_end_ms<T>(self: &Job<T>): u64 { self.challenge_end_ms }

public fun dispute_window_ms(): u64 { DISPUTE_WINDOW_MS }

public fun tier_replay(): u8 { TIER_REPLAY }
