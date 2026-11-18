// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

/// Turnstile accounting for value pools (invariant LEDGER-05).
///
/// A turnstile records every unit that enters and leaves a pool and enforces:
///   1. cumulative outflow <= cumulative inflow (nothing leaves that never came in);
///   2. outflow within one epoch <= the pool's per-epoch cap.
///
/// If a bug elsewhere ever tried to pay out more than the pool received, or to
/// drain it faster than its cap, the transaction aborts here instead.
///
/// Cap changes are asymmetric: lowering the cap takes effect immediately;
/// raising it takes effect only from the next epoch, so a stolen admin key
/// cannot raise the cap and drain the pool in the same epoch.
module seuaro_payments::turnstile;

const EOutflowExceedsInflow: u64 = 1;
const EEpochCapExceeded: u64 = 2;

public struct Turnstile has store {
    total_in: u128,
    total_out: u128,
    /// Epoch that `epoch_out` refers to.
    epoch: u64,
    /// Outflow so far in `epoch`.
    epoch_out: u64,
    /// Maximum outflow per epoch currently in force.
    epoch_cap: u64,
    /// A raised cap waiting to take effect.
    has_pending: bool,
    pending_cap: u64,
    pending_from_epoch: u64,
}

public fun new(epoch_cap: u64, ctx: &TxContext): Turnstile {
    Turnstile {
        total_in: 0,
        total_out: 0,
        epoch: ctx.epoch(),
        epoch_out: 0,
        epoch_cap,
        has_pending: false,
        pending_cap: 0,
        pending_from_epoch: 0,
    }
}

/// Record value entering the pool.
public fun record_in(self: &mut Turnstile, amount: u64) {
    self.total_in = self.total_in + (amount as u128);
}

/// Record value leaving the pool. Aborts if either limit would be exceeded.
public fun record_out(self: &mut Turnstile, amount: u64, ctx: &TxContext) {
    self.refresh(ctx.epoch());
    assert!(self.total_out + (amount as u128) <= self.total_in, EOutflowExceedsInflow);
    assert!(
        (self.epoch_out as u128) + (amount as u128) <= (self.epoch_cap as u128),
        EEpochCapExceeded,
    );
    self.total_out = self.total_out + (amount as u128);
    self.epoch_out = self.epoch_out + amount;
}

/// Change the per-epoch cap: decreases apply now, increases from the next epoch.
public fun set_epoch_cap(self: &mut Turnstile, new_cap: u64, ctx: &TxContext) {
    self.refresh(ctx.epoch());
    if (new_cap <= self.epoch_cap) {
        self.epoch_cap = new_cap;
        self.has_pending = false;
    } else {
        self.has_pending = true;
        self.pending_cap = new_cap;
        self.pending_from_epoch = ctx.epoch() + 1;
    }
}

/// Roll the epoch window forward and apply a pending cap increase if due.
fun refresh(self: &mut Turnstile, current_epoch: u64) {
    if (current_epoch != self.epoch) {
        self.epoch = current_epoch;
        self.epoch_out = 0;
    };
    if (self.has_pending && current_epoch >= self.pending_from_epoch) {
        self.epoch_cap = self.pending_cap;
        self.has_pending = false;
    };
}

public fun destroy(self: Turnstile) {
    let Turnstile {
        total_in: _,
        total_out: _,
        epoch: _,
        epoch_out: _,
        epoch_cap: _,
        has_pending: _,
        pending_cap: _,
        pending_from_epoch: _,
    } = self;
}

// === Views ===

public fun total_in(self: &Turnstile): u128 { self.total_in }

public fun total_out(self: &Turnstile): u128 { self.total_out }

/// Value still accounted for in the pool (inflow minus outflow).
public fun net(self: &Turnstile): u128 { self.total_in - self.total_out }

public fun epoch_cap(self: &Turnstile): u64 { self.epoch_cap }

public fun pending_cap(self: &Turnstile): (bool, u64, u64) {
    (self.has_pending, self.pending_cap, self.pending_from_epoch)
}

/// How much can still leave in `current_epoch` under the cap (ignores inflow limit).
public fun remaining_in_epoch(self: &Turnstile, current_epoch: u64): u64 {
    let (cap, used) = if (current_epoch != self.epoch) {
        let cap = if (self.has_pending && current_epoch >= self.pending_from_epoch) {
            self.pending_cap
        } else {
            self.epoch_cap
        };
        (cap, 0)
    } else {
        (self.epoch_cap, self.epoch_out)
    };
    if (used >= cap) 0 else cap - used
}
