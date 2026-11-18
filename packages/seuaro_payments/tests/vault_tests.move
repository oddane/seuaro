// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module seuaro_payments::vault_tests;

use seuaro_payments::turnstile;
use seuaro_payments::vault::{Self, Vault, VaultAdminCap};
use std::unit_test::{assert_eq, destroy};
use sui::coin;
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};

const ADMIN: address = @0xA1;
const PAYER: address = @0xB1;

const CAP: u64 = 500;

/// ADMIN creates a vault with a per-epoch cap; PAYER deposits `deposit`.
fun setup(deposit: u64): Scenario {
    let mut sc = ts::begin(ADMIN);
    let cap = vault::create<SUI>(CAP, sc.ctx());
    transfer::public_transfer(cap, ADMIN);
    sc.next_tx(PAYER);
    let mut v = sc.take_shared<Vault<SUI>>();
    v.deposit(coin::mint_for_testing<SUI>(deposit, sc.ctx()), sc.ctx());
    ts::return_shared(v);
    sc.next_tx(ADMIN);
    sc
}

fun withdraw(sc: &mut Scenario, amount: u64): u64 {
    let mut v = sc.take_shared<Vault<SUI>>();
    let cap = sc.take_from_sender<VaultAdminCap>();
    let c = v.withdraw(&cap, amount, sc.ctx());
    let got = c.value();
    destroy(c);
    sc.return_to_sender(cap);
    ts::return_shared(v);
    got
}

// === Turnstile ===

#[test]
fun turnstile_tracks_net_value() {
    let ctx = tx_context::dummy();
    let mut t = turnstile::new(1_000, &ctx);
    t.record_in(700);
    t.record_out(200, &ctx);
    assert_eq!(t.total_in(), 700);
    assert_eq!(t.total_out(), 200);
    assert_eq!(t.net(), 500);
    t.destroy();
}

#[test, expected_failure(abort_code = turnstile::EOutflowExceedsInflow)]
fun turnstile_blocks_outflow_beyond_inflow() {
    let ctx = tx_context::dummy();
    let mut t = turnstile::new(1_000, &ctx);
    t.record_in(100);
    t.record_out(101, &ctx);
    t.destroy();
}

#[test, expected_failure(abort_code = turnstile::EEpochCapExceeded)]
fun turnstile_enforces_epoch_cap() {
    let ctx = tx_context::dummy();
    let mut t = turnstile::new(100, &ctx);
    t.record_in(1_000);
    t.record_out(60, &ctx);
    t.record_out(41, &ctx);
    t.destroy();
}

#[test]
fun turnstile_cap_decrease_is_immediate() {
    let ctx = tx_context::dummy();
    let mut t = turnstile::new(100, &ctx);
    t.set_epoch_cap(10, &ctx);
    assert_eq!(t.epoch_cap(), 10);
    t.destroy();
}

#[test]
fun turnstile_cap_increase_waits_one_epoch() {
    let ctx = tx_context::dummy();
    let mut t = turnstile::new(100, &ctx);
    t.set_epoch_cap(1_000, &ctx);
    assert_eq!(t.epoch_cap(), 100);
    let (pending, cap, from) = t.pending_cap();
    assert!(pending);
    assert_eq!(cap, 1_000);
    assert_eq!(from, ctx.epoch() + 1);
    assert_eq!(t.remaining_in_epoch(ctx.epoch() + 1), 1_000);
    t.destroy();
}

// === Vault ===

#[test]
fun vault_deposit_and_withdraw_keep_accounting() {
    let mut sc = setup(1_000);
    assert_eq!(withdraw(&mut sc, 300), 300);
    let v = sc.take_shared<Vault<SUI>>();
    assert_eq!(v.balance(), 700);
    assert_eq!(v.gate().net(), 700);
    ts::return_shared(v);
    sc.end();
}

#[test, expected_failure(abort_code = turnstile::EEpochCapExceeded)]
fun vault_withdrawals_capped_per_epoch() {
    let mut sc = setup(1_000);
    withdraw(&mut sc, 400);
    withdraw(&mut sc, 101); // 501 > CAP in one epoch
    sc.end();
}

#[test]
fun vault_cap_resets_next_epoch() {
    let mut sc = setup(1_000);
    withdraw(&mut sc, CAP);
    sc.next_epoch(ADMIN);
    assert_eq!(withdraw(&mut sc, CAP), CAP);
    sc.end();
}

#[test, expected_failure(abort_code = turnstile::EEpochCapExceeded)]
fun vault_cap_raise_does_not_help_same_epoch() {
    let mut sc = setup(10_000);
    let mut v = sc.take_shared<Vault<SUI>>();
    let cap = sc.take_from_sender<VaultAdminCap>();
    v.set_epoch_cap(&cap, 10_000, sc.ctx());
    sc.return_to_sender(cap);
    ts::return_shared(v);
    sc.next_tx(ADMIN);
    withdraw(&mut sc, CAP + 1); // stolen-key scenario: raise then drain in one epoch
    sc.end();
}

#[test, expected_failure(abort_code = turnstile::EOutflowExceedsInflow)]
fun vault_cannot_pay_out_more_than_deposited() {
    let mut sc = setup(100);
    withdraw(&mut sc, 101);
    sc.end();
}

#[test, expected_failure(abort_code = vault::EWrongVault)]
fun admin_cap_only_works_on_its_own_vault() {
    let mut sc = setup(1_000);
    // A second vault with its own cap.
    let other_cap = vault::create<SUI>(CAP, sc.ctx());
    sc.next_tx(ADMIN);
    let mut v = sc.take_shared<Vault<SUI>>(); // most recent shared vault = the second one
    let original_cap = sc.take_from_sender<VaultAdminCap>();
    assert!(original_cap.cap_vault_id() != object::id(&v));
    let c = v.withdraw(&original_cap, 1, sc.ctx());
    destroy(c);
    destroy(other_cap);
    sc.return_to_sender(original_cap);
    ts::return_shared(v);
    sc.end();
}
