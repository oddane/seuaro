// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module seuaro_compute::jobs_tests;

use seuaro_compute::jobs::{Self, Job};
use std::unit_test::assert_eq;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};

const CLIENT: address = @0xC1;
const PROVIDER: address = @0xF1;
const V1: address = @0x51;
const V2: address = @0x52;
const V3: address = @0x53;

const REWARD: u64 = 1_000;
const BOND: u64 = 200;
const WINDOW: u64 = 60_000;

fun h(b: u8): vector<u8> {
    let mut v = vector[];
    let mut i = 0;
    while (i < 32) {
        v.push_back(b);
        i = i + 1;
    };
    v
}

fun verifiers(): vector<address> { vector[V1, V2, V3] }

fun posted(): (Scenario, Clock) {
    let mut sc = ts::begin(CLIENT);
    let clock = clock::create_for_testing(sc.ctx());
    let pay = coin::mint_for_testing<SUI>(REWARD, sc.ctx());
    jobs::post(pay, h(1), BOND, verifiers(), 2, WINDOW, WINDOW, WINDOW, &clock, sc.ctx());
    (sc, clock)
}

/// Posted, accepted by PROVIDER and result h(7) submitted at t=0.
fun submitted(): (Scenario, Clock) {
    let (mut sc, clock) = posted();
    sc.next_tx(PROVIDER);
    let mut job = sc.take_shared<Job<SUI>>();
    job.accept(coin::mint_for_testing<SUI>(BOND, sc.ctx()), &clock, sc.ctx());
    job.submit(h(7), &clock, sc.ctx());
    ts::return_shared(job);
    (sc, clock)
}

fun challenged(): (Scenario, Clock) {
    let (mut sc, clock) = submitted();
    sc.next_tx(V1);
    let mut job = sc.take_shared<Job<SUI>>();
    job.challenge(&clock, sc.ctx());
    ts::return_shared(job);
    (sc, clock)
}

fun salt(who: address): vector<u8> { sui::address::to_bytes(who) }

fun commit_as(sc: &mut Scenario, clock: &Clock, who: address, hash: vector<u8>) {
    sc.next_tx(who);
    let mut job = sc.take_shared<Job<SUI>>();
    job.commit_vote(jobs::commitment(hash, salt(who), who), clock, sc.ctx());
    ts::return_shared(job);
}

fun reveal_as(sc: &mut Scenario, clock: &Clock, who: address, hash: vector<u8>) {
    sc.next_tx(who);
    let mut job = sc.take_shared<Job<SUI>>();
    job.reveal_vote(hash, salt(who), clock, sc.ctx());
    ts::return_shared(job);
}

fun end_commit_window(clock: &mut Clock) {
    clock.increment_for_testing(jobs::commit_window_ms() + 1);
}

fun close_as(sc: &mut Scenario, who: address) {
    sc.next_tx(who);
    let job = sc.take_shared<Job<SUI>>();
    job.close(sc.ctx());
}

fun received(sc: &mut Scenario, who: address): u64 {
    sc.next_tx(who);
    if (ts::has_most_recent_for_address<Coin<SUI>>(who)) {
        let c = ts::take_from_address<Coin<SUI>>(sc, who);
        let v = c.value();
        ts::return_to_address(who, c);
        v
    } else {
        0
    }
}

fun finish(sc: Scenario, clock: Clock) {
    clock.destroy_for_testing();
    sc.end();
}

#[test]
fun optimistic_path_pays_provider_reward_and_bond() {
    let (mut sc, mut clock) = submitted();
    clock.increment_for_testing(WINDOW + 1);
    sc.next_tx(V3); // anyone can finalize
    let job = sc.take_shared<Job<SUI>>();
    assert_eq!(job.tier(), jobs::tier_replay());
    job.finalize(&clock, sc.ctx());
    assert_eq!(received(&mut sc, PROVIDER), REWARD + BOND);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::ETooEarly)]
fun cannot_finalize_during_challenge_window() {
    let (mut sc, mut clock) = submitted();
    clock.increment_for_testing(WINDOW);
    sc.next_tx(PROVIDER);
    let job = sc.take_shared<Job<SUI>>();
    job.finalize(&clock, sc.ctx());
    finish(sc, clock);
}

#[test]
fun quorum_upholding_result_pays_provider() {
    let (mut sc, mut clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7));
    commit_as(&mut sc, &clock, V2, h(7));
    end_commit_window(&mut clock);
    reveal_as(&mut sc, &clock, V1, h(7));
    reveal_as(&mut sc, &clock, V2, h(7));
    close_as(&mut sc, CLIENT);
    assert_eq!(received(&mut sc, PROVIDER), REWARD + BOND);
    assert_eq!(received(&mut sc, CLIENT), 0);
    finish(sc, clock);
}

#[test]
fun quorum_rejecting_result_refunds_client_with_bond() {
    let (mut sc, mut clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7)); // one verifier sides with the provider
    commit_as(&mut sc, &clock, V2, h(9));
    commit_as(&mut sc, &clock, V3, h(9)); // majority finds a different result
    end_commit_window(&mut clock);
    reveal_as(&mut sc, &clock, V1, h(7));
    reveal_as(&mut sc, &clock, V2, h(9));
    reveal_as(&mut sc, &clock, V3, h(9));
    close_as(&mut sc, PROVIDER);
    assert_eq!(received(&mut sc, CLIENT), REWARD + BOND);
    assert_eq!(received(&mut sc, PROVIDER), 0);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EWrongState)]
fun one_vote_is_not_a_quorum() {
    let (mut sc, mut clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7));
    end_commit_window(&mut clock);
    reveal_as(&mut sc, &clock, V1, h(7));
    close_as(&mut sc, PROVIDER);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EAlreadyVoted)]
fun verifier_cannot_vote_twice() {
    let (mut sc, clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7));
    commit_as(&mut sc, &clock, V1, h(9));
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::ENotVerifier)]
fun outsider_cannot_challenge() {
    let (mut sc, clock) = submitted();
    sc.next_tx(CLIENT);
    let mut job = sc.take_shared<Job<SUI>>();
    job.challenge(&clock, sc.ctx());
    ts::return_shared(job);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::ETooLate)]
fun challenge_after_window_rejected() {
    let (mut sc, mut clock) = submitted();
    clock.increment_for_testing(WINDOW + 1);
    sc.next_tx(V1);
    let mut job = sc.take_shared<Job<SUI>>();
    job.challenge(&clock, sc.ctx());
    ts::return_shared(job);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EConflictOfInterest)]
fun verifier_cannot_be_provider() {
    let (mut sc, clock) = posted();
    sc.next_tx(V1);
    let mut job = sc.take_shared<Job<SUI>>();
    job.accept(coin::mint_for_testing<SUI>(BOND, sc.ctx()), &clock, sc.ctx());
    ts::return_shared(job);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EWrongBond)]
fun provider_must_lock_exact_bond() {
    let (mut sc, clock) = posted();
    sc.next_tx(PROVIDER);
    let mut job = sc.take_shared<Job<SUI>>();
    job.accept(coin::mint_for_testing<SUI>(BOND - 1, sc.ctx()), &clock, sc.ctx());
    ts::return_shared(job);
    finish(sc, clock);
}

#[test]
fun provider_timeout_gives_client_reward_and_bond() {
    let (mut sc, mut clock) = posted();
    sc.next_tx(PROVIDER);
    let mut job = sc.take_shared<Job<SUI>>();
    job.accept(coin::mint_for_testing<SUI>(BOND, sc.ctx()), &clock, sc.ctx());
    ts::return_shared(job);
    clock.increment_for_testing(WINDOW + 1);
    sc.next_tx(CLIENT);
    let job = sc.take_shared<Job<SUI>>();
    job.claim_timeout(&clock, sc.ctx());
    assert_eq!(received(&mut sc, CLIENT), REWARD + BOND);
    finish(sc, clock);
}

#[test]
fun client_cancels_unaccepted_job() {
    let (mut sc, mut clock) = posted();
    clock.increment_for_testing(WINDOW + 1);
    sc.next_tx(CLIENT);
    let job = sc.take_shared<Job<SUI>>();
    job.cancel(&clock, sc.ctx());
    assert_eq!(received(&mut sc, CLIENT), REWARD);
    finish(sc, clock);
}

#[test]
fun dispute_without_quorum_refunds_client_and_returns_bond() {
    let (mut sc, mut clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7));
    commit_as(&mut sc, &clock, V2, h(7)); // V2 commits but never reveals
    end_commit_window(&mut clock);
    reveal_as(&mut sc, &clock, V1, h(7));
    clock.increment_for_testing(jobs::dispute_window_ms() + 1);
    sc.next_tx(CLIENT);
    let job = sc.take_shared<Job<SUI>>();
    job.expire_dispute(&clock, sc.ctx());
    assert_eq!(received(&mut sc, CLIENT), REWARD);
    assert_eq!(received(&mut sc, PROVIDER), BOND);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EBadVerifierSet)]
fun quorum_must_be_a_majority() {
    let mut sc = ts::begin(CLIENT);
    let clock = clock::create_for_testing(sc.ctx());
    let pay = coin::mint_for_testing<SUI>(REWARD, sc.ctx());
    jobs::post(pay, h(1), BOND, verifiers(), 1, WINDOW, WINDOW, WINDOW, &clock, sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EBadVerifierSet)]
fun client_cannot_verify_own_job() {
    let mut sc = ts::begin(CLIENT);
    let clock = clock::create_for_testing(sc.ctx());
    let pay = coin::mint_for_testing<SUI>(REWARD, sc.ctx());
    jobs::post(pay, h(1), BOND, vector[CLIENT, V1, V2], 2, WINDOW, WINDOW, WINDOW, &clock, sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EBadHash)]
fun spec_hash_must_be_32_bytes() {
    let mut sc = ts::begin(CLIENT);
    let clock = clock::create_for_testing(sc.ctx());
    let pay = coin::mint_for_testing<SUI>(REWARD, sc.ctx());
    jobs::post(pay, b"short", BOND, verifiers(), 2, WINDOW, WINDOW, WINDOW, &clock, sc.ctx());
    finish(sc, clock);
}

// === Commit-reveal (anti vote-copying) ===

#[test, expected_failure(abort_code = jobs::ETooEarly)]
fun cannot_reveal_during_commit_window() {
    let (mut sc, clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7));
    reveal_as(&mut sc, &clock, V1, h(7));
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EBadReveal)]
fun reveal_must_match_commitment() {
    let (mut sc, mut clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7));
    end_commit_window(&mut clock);
    reveal_as(&mut sc, &clock, V1, h(9)); // changed answer after seeing others
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::EBadReveal)]
fun copied_commitment_cannot_be_revealed() {
    let (mut sc, mut clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7));
    // V2 copies V1's commitment bytes verbatim instead of doing the work.
    sc.next_tx(V2);
    let mut job = sc.take_shared<Job<SUI>>();
    job.commit_vote(jobs::commitment(h(7), salt(V1), V1), &clock, sc.ctx());
    ts::return_shared(job);
    end_commit_window(&mut clock);
    // Even knowing V1's answer and salt, V2's reveal is bound to V2's address.
    sc.next_tx(V2);
    let mut job = sc.take_shared<Job<SUI>>();
    job.reveal_vote(h(7), salt(V1), &clock, sc.ctx());
    ts::return_shared(job);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::ENotCommitted)]
fun cannot_reveal_without_commit() {
    let (mut sc, mut clock) = challenged();
    commit_as(&mut sc, &clock, V1, h(7));
    end_commit_window(&mut clock);
    reveal_as(&mut sc, &clock, V2, h(7));
    finish(sc, clock);
}

#[test, expected_failure(abort_code = jobs::ETooLate)]
fun cannot_commit_after_commit_window() {
    let (mut sc, mut clock) = challenged();
    end_commit_window(&mut clock);
    commit_as(&mut sc, &clock, V1, h(7));
    finish(sc, clock);
}
