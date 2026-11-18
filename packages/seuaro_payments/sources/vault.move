// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

/// A shared value pool guarded by a turnstile (LEDGER-05).
///
/// Anyone can deposit. Only the holder of the matching `VaultAdminCap` can
/// withdraw, and every withdrawal passes the turnstile: never more than was
/// deposited, never more than the per-epoch cap. Intended uses: merchant
/// settlement pools, compute-job deposit pools, fee-sponsorship budgets.
/// In production the admin cap should be held by a multisig account.
module seuaro_payments::vault;

use seuaro_payments::turnstile::{Self, Turnstile};
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;

const EWrongVault: u64 = 1;
const EZeroAmount: u64 = 2;
const EAccountingBroken: u64 = 3;

public struct Vault<phantom T> has key {
    id: UID,
    funds: Balance<T>,
    gate: Turnstile,
}

public struct VaultAdminCap has key, store {
    id: UID,
    vault_id: ID,
}

public struct VaultCreated has copy, drop { vault_id: ID, epoch_cap: u64 }

public struct Deposited has copy, drop { vault_id: ID, from: address, amount: u64 }

public struct Withdrawn has copy, drop { vault_id: ID, amount: u64, epoch: u64 }

public struct CapChangeRequested has copy, drop { vault_id: ID, new_cap: u64, epoch: u64 }

/// Create and share a vault; returns its admin capability.
public fun create<T>(epoch_cap: u64, ctx: &mut TxContext): VaultAdminCap {
    let vault = Vault<T> {
        id: object::new(ctx),
        funds: balance::zero(),
        gate: turnstile::new(epoch_cap, ctx),
    };
    let vault_id = object::id(&vault);
    event::emit(VaultCreated { vault_id, epoch_cap });
    transfer::share_object(vault);
    VaultAdminCap { id: object::new(ctx), vault_id }
}

#[allow(lint(self_transfer))]
/// CLI-friendly wrapper: creates the vault and sends the admin cap to the sender.
public fun create_for_sender<T>(epoch_cap: u64, ctx: &mut TxContext) {
    let cap = create<T>(epoch_cap, ctx);
    transfer::public_transfer(cap, ctx.sender());
}

public fun deposit<T>(self: &mut Vault<T>, payment: Coin<T>, ctx: &TxContext) {
    let amount = payment.value();
    assert!(amount > 0, EZeroAmount);
    self.gate.record_in(amount);
    self.funds.join(payment.into_balance());
    event::emit(Deposited { vault_id: object::id(self), from: ctx.sender(), amount });
    self.assert_accounting();
}

public fun withdraw<T>(
    self: &mut Vault<T>,
    cap: &VaultAdminCap,
    amount: u64,
    ctx: &mut TxContext,
): Coin<T> {
    assert!(cap.vault_id == object::id(self), EWrongVault);
    assert!(amount > 0, EZeroAmount);
    self.gate.record_out(amount, ctx);
    let out = coin::take(&mut self.funds, amount, ctx);
    event::emit(Withdrawn { vault_id: object::id(self), amount, epoch: ctx.epoch() });
    self.assert_accounting();
    out
}

public fun set_epoch_cap<T>(
    self: &mut Vault<T>,
    cap: &VaultAdminCap,
    new_cap: u64,
    ctx: &TxContext,
) {
    assert!(cap.vault_id == object::id(self), EWrongVault);
    self.gate.set_epoch_cap(new_cap, ctx);
    event::emit(CapChangeRequested { vault_id: object::id(self), new_cap, epoch: ctx.epoch() });
}

/// The pool's balance must always equal recorded inflow minus outflow.
fun assert_accounting<T>(self: &Vault<T>) {
    assert!((self.funds.value() as u128) == self.gate.net(), EAccountingBroken);
}

// === Views ===

public fun balance<T>(self: &Vault<T>): u64 { self.funds.value() }

public fun gate<T>(self: &Vault<T>): &Turnstile { &self.gate }

public fun cap_vault_id(cap: &VaultAdminCap): ID { cap.vault_id }
