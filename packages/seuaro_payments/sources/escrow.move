// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

/// Merchant escrow with a buyer-protection window (invariant PAY-01).
///
/// Flow:
///   * The buyer locks a payment for a merchant, naming an arbiter and a
///     protection window.
///   * Any time: the buyer may `release` (pay the merchant) or the merchant
///     may `refund` (return everything to the buyer).
///   * Before the window ends, the buyer may `dispute`.
///   * After the window ends with no dispute, the merchant may `claim`.
///   * A dispute is settled by the arbiter with `resolve` (any split).
///   * If the arbiter does not act within ARBITRATION_WINDOW_MS after the
///     protection window, the buyer may `reclaim` (funds never get stuck).
///
/// Guarantees:
///   * Payouts always sum to exactly the deposit; no path pays more.
///   * Each action is restricted to one named party.
///   * `dispute` (now <= deadline) and `claim` (now > deadline) can never both
///     be valid, so ordering between them cannot be exploited. Time comes from
///     the consensus clock, which is identical on every validator.
module seuaro_payments::escrow;

use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::event;

const ENotBuyer: u64 = 1;
const ENotMerchant: u64 = 2;
const ENotArbiter: u64 = 3;
const EZeroAmount: u64 = 4;
const EBadWindow: u64 = 5;
const EPartiesNotDistinct: u64 = 6;
const EWindowClosed: u64 = 7;
const EWindowOpen: u64 = 8;
const EDisputed: u64 = 9;
const ENotDisputed: u64 = 10;
const EInvalidSplit: u64 = 11;
const EArbitrationOpen: u64 = 12;

/// Longest allowed buyer-protection window: 90 days.
const MAX_PROTECTION_WINDOW_MS: u64 = 90 * 24 * 60 * 60 * 1000;
/// How long the arbiter has after the protection window ends: 30 days.
const ARBITRATION_WINDOW_MS: u64 = 30 * 24 * 60 * 60 * 1000;

// Outcome codes reported in `Settled`.
const OUTCOME_RELEASED: u8 = 0;
const OUTCOME_REFUNDED: u8 = 1;
const OUTCOME_CLAIMED: u8 = 2;
const OUTCOME_RESOLVED: u8 = 3;
const OUTCOME_RECLAIMED: u8 = 4;

public struct Escrow<phantom T> has key {
    id: UID,
    buyer: address,
    merchant: address,
    arbiter: address,
    funds: Balance<T>,
    amount: u64,
    deadline_ms: u64,
    disputed: bool,
}

public struct EscrowCreated has copy, drop {
    escrow_id: ID,
    buyer: address,
    merchant: address,
    arbiter: address,
    amount: u64,
    deadline_ms: u64,
}

public struct Disputed has copy, drop { escrow_id: ID, at_ms: u64 }

public struct Settled has copy, drop {
    escrow_id: ID,
    outcome: u8,
    to_merchant: u64,
    to_buyer: u64,
}

/// Lock `payment` in a new shared escrow. Returns the escrow's ID.
public fun create<T>(
    payment: Coin<T>,
    merchant: address,
    arbiter: address,
    protection_window_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    let buyer = ctx.sender();
    let amount = payment.value();
    assert!(amount > 0, EZeroAmount);
    assert!(
        protection_window_ms > 0 && protection_window_ms <= MAX_PROTECTION_WINDOW_MS,
        EBadWindow,
    );
    assert!(
        buyer != merchant && arbiter != buyer && arbiter != merchant,
        EPartiesNotDistinct,
    );

    let deadline_ms = clock.timestamp_ms() + protection_window_ms;
    let escrow = Escrow<T> {
        id: object::new(ctx),
        buyer,
        merchant,
        arbiter,
        funds: payment.into_balance(),
        amount,
        deadline_ms,
        disputed: false,
    };
    let escrow_id = object::id(&escrow);
    event::emit(EscrowCreated { escrow_id, buyer, merchant, arbiter, amount, deadline_ms });
    transfer::share_object(escrow);
    escrow_id
}

/// Buyer pays the merchant in full. Allowed at any time, including during a dispute.
public fun release<T>(self: Escrow<T>, ctx: &mut TxContext) {
    assert!(ctx.sender() == self.buyer, ENotBuyer);
    let amount = self.amount;
    settle(self, amount, OUTCOME_RELEASED, ctx);
}

/// Merchant returns everything to the buyer. Allowed at any time.
public fun refund<T>(self: Escrow<T>, ctx: &mut TxContext) {
    assert!(ctx.sender() == self.merchant, ENotMerchant);
    settle(self, 0, OUTCOME_REFUNDED, ctx);
}

/// Buyer opens a dispute while the protection window is open.
public fun dispute<T>(self: &mut Escrow<T>, clock: &Clock, ctx: &TxContext) {
    assert!(ctx.sender() == self.buyer, ENotBuyer);
    assert!(!self.disputed, EDisputed);
    let now = clock.timestamp_ms();
    assert!(now <= self.deadline_ms, EWindowClosed);
    self.disputed = true;
    event::emit(Disputed { escrow_id: object::id(self), at_ms: now });
}

/// Merchant collects after the window closed without a dispute.
public fun claim<T>(self: Escrow<T>, clock: &Clock, ctx: &mut TxContext) {
    assert!(ctx.sender() == self.merchant, ENotMerchant);
    assert!(!self.disputed, EDisputed);
    assert!(clock.timestamp_ms() > self.deadline_ms, EWindowOpen);
    let amount = self.amount;
    settle(self, amount, OUTCOME_CLAIMED, ctx);
}

/// Arbiter settles a dispute: `to_merchant` goes to the merchant, the rest to the buyer.
public fun resolve<T>(self: Escrow<T>, to_merchant: u64, ctx: &mut TxContext) {
    assert!(ctx.sender() == self.arbiter, ENotArbiter);
    assert!(self.disputed, ENotDisputed);
    assert!(to_merchant <= self.amount, EInvalidSplit);
    settle(self, to_merchant, OUTCOME_RESOLVED, ctx);
}

/// Buyer recovers the funds if the arbiter has not acted in time.
public fun reclaim<T>(self: Escrow<T>, clock: &Clock, ctx: &mut TxContext) {
    assert!(ctx.sender() == self.buyer, ENotBuyer);
    assert!(self.disputed, ENotDisputed);
    assert!(clock.timestamp_ms() > self.deadline_ms + ARBITRATION_WINDOW_MS, EArbitrationOpen);
    settle(self, 0, OUTCOME_RECLAIMED, ctx);
}

/// The only path that moves funds out. Pays `to_merchant` to the merchant and
/// the exact remainder to the buyer, then deletes the escrow.
fun settle<T>(self: Escrow<T>, to_merchant: u64, outcome: u8, ctx: &mut TxContext) {
    let Escrow { id, buyer, merchant, arbiter: _, mut funds, amount, deadline_ms: _, disputed: _ } =
        self;
    assert!(funds.value() == amount && to_merchant <= amount, EInvalidSplit);
    let to_buyer = amount - to_merchant;

    if (to_merchant > 0) {
        transfer::public_transfer(coin::take(&mut funds, to_merchant, ctx), merchant);
    };
    if (to_buyer > 0) {
        transfer::public_transfer(coin::take(&mut funds, to_buyer, ctx), buyer);
    };
    funds.destroy_zero();

    event::emit(Settled { escrow_id: id.to_inner(), outcome, to_merchant, to_buyer });
    id.delete();
}

// === Views ===

public fun buyer<T>(self: &Escrow<T>): address { self.buyer }

public fun merchant<T>(self: &Escrow<T>): address { self.merchant }

public fun arbiter<T>(self: &Escrow<T>): address { self.arbiter }

public fun amount<T>(self: &Escrow<T>): u64 { self.amount }

public fun deadline_ms<T>(self: &Escrow<T>): u64 { self.deadline_ms }

public fun is_disputed<T>(self: &Escrow<T>): bool { self.disputed }

public fun arbitration_window_ms(): u64 { ARBITRATION_WINDOW_MS }
