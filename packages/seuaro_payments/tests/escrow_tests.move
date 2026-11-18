// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module seuaro_payments::escrow_tests;

use seuaro_payments::escrow::{Self, Escrow};
use std::unit_test::assert_eq;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};

const BUYER: address = @0xB0;
const MERCHANT: address = @0xA0;
const ARBITER: address = @0xC0;
const STRANGER: address = @0xD0;

const PRICE: u64 = 1_000_000;
const WINDOW_MS: u64 = 7 * 24 * 60 * 60 * 1000;

/// Buyer opens an escrow at t=0. Returns the scenario and a clock.
fun setup(): (Scenario, Clock) {
    let mut sc = ts::begin(BUYER);
    let clock = clock::create_for_testing(sc.ctx());
    let pay = coin::mint_for_testing<SUI>(PRICE, sc.ctx());
    escrow::create(pay, MERCHANT, ARBITER, WINDOW_MS, &clock, sc.ctx());
    (sc, clock)
}

fun received(sc: &Scenario, who: address): u64 {
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
fun release_pays_merchant_in_full() {
    let (mut sc, clock) = setup();
    sc.next_tx(BUYER);
    let e = sc.take_shared<Escrow<SUI>>();
    e.release(sc.ctx());
    sc.next_tx(BUYER);
    assert_eq!(received(&sc, MERCHANT), PRICE);
    assert_eq!(received(&sc, BUYER), 0);
    finish(sc, clock);
}

#[test]
fun refund_returns_everything_to_buyer() {
    let (mut sc, clock) = setup();
    sc.next_tx(MERCHANT);
    let e = sc.take_shared<Escrow<SUI>>();
    e.refund(sc.ctx());
    sc.next_tx(MERCHANT);
    assert_eq!(received(&sc, BUYER), PRICE);
    assert_eq!(received(&sc, MERCHANT), 0);
    finish(sc, clock);
}

#[test]
fun merchant_claims_after_window() {
    let (mut sc, mut clock) = setup();
    clock.increment_for_testing(WINDOW_MS + 1);
    sc.next_tx(MERCHANT);
    let e = sc.take_shared<Escrow<SUI>>();
    e.claim(&clock, sc.ctx());
    sc.next_tx(MERCHANT);
    assert_eq!(received(&sc, MERCHANT), PRICE);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::EWindowOpen)]
fun claim_at_deadline_is_too_early() {
    let (mut sc, mut clock) = setup();
    clock.increment_for_testing(WINDOW_MS); // exactly the deadline: still the buyer's window
    sc.next_tx(MERCHANT);
    let e = sc.take_shared<Escrow<SUI>>();
    e.claim(&clock, sc.ctx());
    finish(sc, clock);
}

#[test]
fun dispute_at_deadline_is_allowed() {
    let (mut sc, mut clock) = setup();
    clock.increment_for_testing(WINDOW_MS);
    sc.next_tx(BUYER);
    let mut e = sc.take_shared<Escrow<SUI>>();
    e.dispute(&clock, sc.ctx());
    assert!(e.is_disputed());
    ts::return_shared(e);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::EWindowClosed)]
fun dispute_after_window_rejected() {
    let (mut sc, mut clock) = setup();
    clock.increment_for_testing(WINDOW_MS + 1);
    sc.next_tx(BUYER);
    let mut e = sc.take_shared<Escrow<SUI>>();
    e.dispute(&clock, sc.ctx());
    ts::return_shared(e);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::EDisputed)]
fun claim_blocked_by_dispute() {
    let (mut sc, mut clock) = setup();
    sc.next_tx(BUYER);
    let mut e = sc.take_shared<Escrow<SUI>>();
    e.dispute(&clock, sc.ctx());
    ts::return_shared(e);
    clock.increment_for_testing(WINDOW_MS + 1);
    sc.next_tx(MERCHANT);
    let e = sc.take_shared<Escrow<SUI>>();
    e.claim(&clock, sc.ctx());
    finish(sc, clock);
}

#[test]
fun arbiter_split_sums_to_deposit() {
    let (mut sc, clock) = setup();
    sc.next_tx(BUYER);
    let mut e = sc.take_shared<Escrow<SUI>>();
    e.dispute(&clock, sc.ctx());
    ts::return_shared(e);
    sc.next_tx(ARBITER);
    let e = sc.take_shared<Escrow<SUI>>();
    e.resolve(700_000, sc.ctx());
    sc.next_tx(ARBITER);
    let m = received(&sc, MERCHANT);
    let b = received(&sc, BUYER);
    assert_eq!(m, 700_000);
    assert_eq!(b, 300_000);
    assert_eq!(m + b, PRICE);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::EInvalidSplit)]
fun arbiter_cannot_pay_more_than_deposit() {
    let (mut sc, clock) = setup();
    sc.next_tx(BUYER);
    let mut e = sc.take_shared<Escrow<SUI>>();
    e.dispute(&clock, sc.ctx());
    ts::return_shared(e);
    sc.next_tx(ARBITER);
    let e = sc.take_shared<Escrow<SUI>>();
    e.resolve(PRICE + 1, sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::ENotDisputed)]
fun arbiter_cannot_act_without_dispute() {
    let (mut sc, clock) = setup();
    sc.next_tx(ARBITER);
    let e = sc.take_shared<Escrow<SUI>>();
    e.resolve(PRICE, sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::ENotBuyer)]
fun stranger_cannot_release() {
    let (mut sc, clock) = setup();
    sc.next_tx(STRANGER);
    let e = sc.take_shared<Escrow<SUI>>();
    e.release(sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::ENotMerchant)]
fun buyer_cannot_claim() {
    let (mut sc, mut clock) = setup();
    clock.increment_for_testing(WINDOW_MS + 1);
    sc.next_tx(BUYER);
    let e = sc.take_shared<Escrow<SUI>>();
    e.claim(&clock, sc.ctx());
    finish(sc, clock);
}

#[test]
fun buyer_reclaims_when_arbiter_is_silent() {
    let (mut sc, mut clock) = setup();
    sc.next_tx(BUYER);
    let mut e = sc.take_shared<Escrow<SUI>>();
    e.dispute(&clock, sc.ctx());
    ts::return_shared(e);
    clock.increment_for_testing(WINDOW_MS + escrow::arbitration_window_ms() + 1);
    sc.next_tx(BUYER);
    let e = sc.take_shared<Escrow<SUI>>();
    e.reclaim(&clock, sc.ctx());
    sc.next_tx(BUYER);
    assert_eq!(received(&sc, BUYER), PRICE);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::EArbitrationOpen)]
fun buyer_cannot_reclaim_while_arbiter_has_time() {
    let (mut sc, mut clock) = setup();
    sc.next_tx(BUYER);
    let mut e = sc.take_shared<Escrow<SUI>>();
    e.dispute(&clock, sc.ctx());
    ts::return_shared(e);
    clock.increment_for_testing(WINDOW_MS + escrow::arbitration_window_ms());
    sc.next_tx(BUYER);
    let e = sc.take_shared<Escrow<SUI>>();
    e.reclaim(&clock, sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::EPartiesNotDistinct)]
fun buyer_cannot_be_arbiter() {
    let mut sc = ts::begin(BUYER);
    let clock = clock::create_for_testing(sc.ctx());
    let pay = coin::mint_for_testing<SUI>(PRICE, sc.ctx());
    escrow::create(pay, MERCHANT, BUYER, WINDOW_MS, &clock, sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::EZeroAmount)]
fun zero_payment_rejected() {
    let mut sc = ts::begin(BUYER);
    let clock = clock::create_for_testing(sc.ctx());
    let pay = coin::mint_for_testing<SUI>(0, sc.ctx());
    escrow::create(pay, MERCHANT, ARBITER, WINDOW_MS, &clock, sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = escrow::EBadWindow)]
fun overlong_window_rejected() {
    let mut sc = ts::begin(BUYER);
    let clock = clock::create_for_testing(sc.ctx());
    let pay = coin::mint_for_testing<SUI>(PRICE, sc.ctx());
    escrow::create(pay, MERCHANT, ARBITER, 91 * 24 * 60 * 60 * 1000, &clock, sc.ctx());
    finish(sc, clock);
}
