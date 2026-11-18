// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

/// Merchant invoices and memo payments: reconciliation data on-chain.
///
/// Payment chains such as Tempo add memos to transfers at the token-standard
/// level so businesses can match payments to invoices. Seuaro does the same
/// with an ordinary Move package, without changing the protocol:
///
///   * `pay_with_memo` - a transfer that carries a reference (invoice number,
///     customer ID, ISO 20022 end-to-end ID) in an event.
///   * `Invoice` - a merchant requests an exact amount with a reference and an
///     expiry. It can be paid once, by anyone, for exactly that amount. The
///     payer gets a `Receipt`. The merchant can refund, never more in total
///     than was paid, and only to the original payer.
module seuaro_payments::invoice;

use sui::clock::Clock;
use sui::coin::Coin;
use sui::event;

const ENotMerchant: u64 = 1;
const EWrongAmount: u64 = 2;
const EAlreadyPaid: u64 = 3;
const ENotPaid: u64 = 4;
const EExpired: u64 = 5;
const EOverRefund: u64 = 6;
const EBadReference: u64 = 7;
const EBadExpiry: u64 = 8;

/// References up to 64 bytes (an ISO 20022 end-to-end ID is at most 35).
const MAX_REFERENCE_BYTES: u64 = 64;
const MAX_EXPIRY_MS: u64 = 365 * 24 * 60 * 60 * 1000;

public struct Invoice<phantom T> has key {
    id: UID,
    merchant: address,
    amount: u64,
    reference: vector<u8>,
    expires_ms: u64,
    paid: bool,
    payer: address,
    refunded: u64,
}

/// Proof of payment held by the payer.
public struct Receipt has key, store {
    id: UID,
    invoice_id: ID,
    merchant: address,
    amount: u64,
    reference: vector<u8>,
    paid_at_ms: u64,
}

public struct MemoPayment<phantom T> has copy, drop {
    from: address,
    to: address,
    amount: u64,
    memo: vector<u8>,
}

public struct InvoiceCreated<phantom T> has copy, drop {
    invoice_id: ID,
    merchant: address,
    amount: u64,
    reference: vector<u8>,
    expires_ms: u64,
}

public struct InvoicePaid<phantom T> has copy, drop {
    invoice_id: ID,
    payer: address,
    amount: u64,
    reference: vector<u8>,
}

public struct InvoiceRefunded<phantom T> has copy, drop {
    invoice_id: ID,
    amount: u64,
    total_refunded: u64,
}

/// Transfer `payment` to `to`, recording `memo` for reconciliation.
public fun pay_with_memo<T>(payment: Coin<T>, to: address, memo: vector<u8>, ctx: &TxContext) {
    assert!(memo.length() <= MAX_REFERENCE_BYTES, EBadReference);
    event::emit(MemoPayment<T> { from: ctx.sender(), to, amount: payment.value(), memo });
    transfer::public_transfer(payment, to);
}

/// Merchant requests `amount` with a reference; returns the shared invoice's ID.
public fun create<T>(
    amount: u64,
    reference: vector<u8>,
    valid_for_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): ID {
    assert!(amount > 0, EWrongAmount);
    assert!(reference.length() > 0 && reference.length() <= MAX_REFERENCE_BYTES, EBadReference);
    assert!(valid_for_ms > 0 && valid_for_ms <= MAX_EXPIRY_MS, EBadExpiry);
    let invoice = Invoice<T> {
        id: object::new(ctx),
        merchant: ctx.sender(),
        amount,
        reference,
        expires_ms: clock.timestamp_ms() + valid_for_ms,
        paid: false,
        payer: @0x0,
        refunded: 0,
    };
    let invoice_id = object::id(&invoice);
    event::emit(InvoiceCreated<T> {
        invoice_id,
        merchant: invoice.merchant,
        amount,
        reference: invoice.reference,
        expires_ms: invoice.expires_ms,
    });
    transfer::share_object(invoice);
    invoice_id
}

/// Pay an invoice in full. The coin goes straight to the merchant.
public fun pay<T>(
    self: &mut Invoice<T>,
    payment: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
): Receipt {
    assert!(!self.paid, EAlreadyPaid);
    let now = clock.timestamp_ms();
    assert!(now <= self.expires_ms, EExpired);
    assert!(payment.value() == self.amount, EWrongAmount);
    self.paid = true;
    self.payer = ctx.sender();
    transfer::public_transfer(payment, self.merchant);
    event::emit(InvoicePaid<T> {
        invoice_id: object::id(self),
        payer: self.payer,
        amount: self.amount,
        reference: self.reference,
    });
    Receipt {
        id: object::new(ctx),
        invoice_id: object::id(self),
        merchant: self.merchant,
        amount: self.amount,
        reference: self.reference,
        paid_at_ms: now,
    }
}

#[allow(lint(self_transfer))]
/// CLI-friendly wrapper: pay and keep the receipt.
public fun pay_and_keep_receipt<T>(
    self: &mut Invoice<T>,
    payment: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let receipt = pay(self, payment, clock, ctx);
    transfer::public_transfer(receipt, ctx.sender());
}

/// Merchant refunds part or all of a paid invoice to the original payer.
public fun refund<T>(self: &mut Invoice<T>, money_back: Coin<T>, ctx: &TxContext) {
    assert!(ctx.sender() == self.merchant, ENotMerchant);
    assert!(self.paid, ENotPaid);
    let value = money_back.value();
    assert!(value > 0 && self.refunded + value <= self.amount, EOverRefund);
    self.refunded = self.refunded + value;
    transfer::public_transfer(money_back, self.payer);
    event::emit(InvoiceRefunded<T> {
        invoice_id: object::id(self),
        amount: value,
        total_refunded: self.refunded,
    });
}

/// Merchant withdraws an unpaid invoice.
public fun cancel<T>(self: Invoice<T>, ctx: &TxContext) {
    assert!(ctx.sender() == self.merchant, ENotMerchant);
    assert!(!self.paid, EAlreadyPaid);
    let Invoice {
        id,
        merchant: _,
        amount: _,
        reference: _,
        expires_ms: _,
        paid: _,
        payer: _,
        refunded: _,
    } = self;
    id.delete();
}

// === Views ===

public fun is_paid<T>(self: &Invoice<T>): bool { self.paid }

public fun amount<T>(self: &Invoice<T>): u64 { self.amount }

public fun refunded<T>(self: &Invoice<T>): u64 { self.refunded }

public fun payer<T>(self: &Invoice<T>): address { self.payer }

public fun receipt_amount(r: &Receipt): u64 { r.amount }

public fun receipt_invoice(r: &Receipt): ID { r.invoice_id }
