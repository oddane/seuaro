// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module seuaro_payments::invoice_tests;

use seuaro_payments::invoice::{Self, Invoice, Receipt};
use std::unit_test::assert_eq;
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};

const MERCHANT: address = @0xA2;
const PAYER: address = @0xB2;
const OTHER: address = @0xD2;

const PRICE: u64 = 25_000;
const VALID_MS: u64 = 15 * 60 * 1000;

fun created(): (Scenario, Clock) {
    let mut sc = ts::begin(MERCHANT);
    let clock = clock::create_for_testing(sc.ctx());
    invoice::create<SUI>(PRICE, b"INV-2026-0042", VALID_MS, &clock, sc.ctx());
    (sc, clock)
}

fun pay_as(sc: &mut Scenario, clock: &Clock, who: address, amount: u64) {
    sc.next_tx(who);
    let mut inv = sc.take_shared<Invoice<SUI>>();
    let c = coin::mint_for_testing<SUI>(amount, sc.ctx());
    inv.pay_and_keep_receipt(c, clock, sc.ctx());
    ts::return_shared(inv);
}

fun refund_as(sc: &mut Scenario, who: address, amount: u64) {
    sc.next_tx(who);
    let mut inv = sc.take_shared<Invoice<SUI>>();
    let c = coin::mint_for_testing<SUI>(amount, sc.ctx());
    inv.refund(c, sc.ctx());
    ts::return_shared(inv);
}

fun total_coins(sc: &mut Scenario, who: address): u64 {
    sc.next_tx(who);
    let ids = ts::ids_for_address<Coin<SUI>>(who);
    let mut total = 0;
    let mut i = 0;
    while (i < ids.length()) {
        let c = ts::take_from_address_by_id<Coin<SUI>>(sc, who, ids[i]);
        total = total + c.value();
        ts::return_to_address(who, c);
        i = i + 1;
    };
    total
}

fun finish(sc: Scenario, clock: Clock) {
    clock.destroy_for_testing();
    sc.end();
}

#[test]
fun paying_sends_exact_amount_to_merchant_and_gives_receipt() {
    let (mut sc, clock) = created();
    pay_as(&mut sc, &clock, PAYER, PRICE);
    assert_eq!(total_coins(&mut sc, MERCHANT), PRICE);
    sc.next_tx(PAYER);
    let r = sc.take_from_sender<Receipt>();
    assert_eq!(r.receipt_amount(), PRICE);
    sc.return_to_sender(r);
    let inv = sc.take_shared<Invoice<SUI>>();
    assert!(inv.is_paid());
    assert_eq!(inv.payer(), PAYER);
    ts::return_shared(inv);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::EWrongAmount)]
fun underpayment_rejected() {
    let (mut sc, clock) = created();
    pay_as(&mut sc, &clock, PAYER, PRICE - 1);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::EWrongAmount)]
fun overpayment_rejected() {
    let (mut sc, clock) = created();
    pay_as(&mut sc, &clock, PAYER, PRICE + 1);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::EAlreadyPaid)]
fun invoice_cannot_be_paid_twice() {
    let (mut sc, clock) = created();
    pay_as(&mut sc, &clock, PAYER, PRICE);
    pay_as(&mut sc, &clock, OTHER, PRICE);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::EExpired)]
fun expired_invoice_rejected() {
    let (mut sc, mut clock) = created();
    clock.increment_for_testing(VALID_MS + 1);
    pay_as(&mut sc, &clock, PAYER, PRICE);
    finish(sc, clock);
}

#[test]
fun partial_refunds_go_to_payer_up_to_paid_amount() {
    let (mut sc, clock) = created();
    pay_as(&mut sc, &clock, PAYER, PRICE);
    refund_as(&mut sc, MERCHANT, 10_000);
    refund_as(&mut sc, MERCHANT, 15_000);
    assert_eq!(total_coins(&mut sc, PAYER), PRICE);
    sc.next_tx(MERCHANT);
    let inv = sc.take_shared<Invoice<SUI>>();
    assert_eq!(inv.refunded(), PRICE);
    ts::return_shared(inv);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::EOverRefund)]
fun refunds_cannot_exceed_paid_amount() {
    let (mut sc, clock) = created();
    pay_as(&mut sc, &clock, PAYER, PRICE);
    refund_as(&mut sc, MERCHANT, 20_000);
    refund_as(&mut sc, MERCHANT, 5_001);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::ENotMerchant)]
fun only_merchant_can_refund() {
    let (mut sc, clock) = created();
    pay_as(&mut sc, &clock, PAYER, PRICE);
    refund_as(&mut sc, OTHER, 1);
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::ENotPaid)]
fun cannot_refund_unpaid_invoice() {
    let (mut sc, clock) = created();
    refund_as(&mut sc, MERCHANT, 1);
    finish(sc, clock);
}

#[test]
fun merchant_cancels_unpaid_invoice() {
    let (mut sc, clock) = created();
    sc.next_tx(MERCHANT);
    let inv = sc.take_shared<Invoice<SUI>>();
    inv.cancel(sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::EAlreadyPaid)]
fun paid_invoice_cannot_be_cancelled() {
    let (mut sc, clock) = created();
    pay_as(&mut sc, &clock, PAYER, PRICE);
    sc.next_tx(MERCHANT);
    let inv = sc.take_shared<Invoice<SUI>>();
    inv.cancel(sc.ctx());
    finish(sc, clock);
}

#[test, expected_failure(abort_code = invoice::EBadReference)]
fun reference_length_is_bounded() {
    let mut sc = ts::begin(MERCHANT);
    let clock = clock::create_for_testing(sc.ctx());
    let mut long = vector[];
    let mut i = 0;
    while (i < 65) {
        long.push_back(65u8);
        i = i + 1;
    };
    invoice::create<SUI>(PRICE, long, VALID_MS, &clock, sc.ctx());
    finish(sc, clock);
}

#[test]
fun memo_payment_delivers_coin() {
    let mut sc = ts::begin(PAYER);
    let c = coin::mint_for_testing<SUI>(777, sc.ctx());
    invoice::pay_with_memo(c, MERCHANT, b"order 991 / customer 17", sc.ctx());
    assert_eq!(total_coins(&mut sc, MERCHANT), 777);
    sc.end();
}
