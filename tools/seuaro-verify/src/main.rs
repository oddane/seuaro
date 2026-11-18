// Copyright (c) Seuaro contributors
// SPDX-License-Identifier: Apache-2.0

//! `seuaro-verify` — a minimal light client for a Seuaro network.
//!
//! Trust root: the genesis blob only. Everything else (checkpoint files, which in
//! production would come from an untrusted RPC or archive) is verified:
//!
//! * every checkpoint summary carries a valid quorum certificate from the
//!   committee of its epoch                                     (CONS-01, API-01)
//! * checkpoint contents match the certified content digest      (API-01)
//! * sequence numbers are contiguous and each summary links to the digest of
//!   the previous one, starting from the genesis checkpoint      (CONS-01)
//! * a new epoch's committee is accepted only from the certified
//!   end-of-epoch checkpoint of the previous epoch              (CONS-05)
//! * the genesis checkpoint matches the expected chain identity  (AUTH-01)
//!
//! A transaction is reported FINAL only if it is found in a checkpoint that
//! passed all of the above.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use anyhow::{Context, Result, anyhow, bail, ensure};
use clap::{Parser, Subcommand};
use prost::Message as _;
use serde_json::json;
use sui_config::genesis::Genesis;
use sui_rpc::proto::sui::rpc::v2::Checkpoint as ProtoCheckpoint;
use sui_types::base_types::AuthorityName;
use sui_types::committee::{Committee, StakeUnit, TOTAL_VOTING_POWER};
use sui_types::digests::{ChainIdentifier, CheckpointDigest, TransactionDigest};
use sui_types::effects::TransactionEffectsAPI;
use sui_types::full_checkpoint_content::{Checkpoint, CheckpointData};

#[derive(Parser)]
#[command(name = "seuaro-verify", version, about)]
struct Cli {
    /// Path to the network's genesis.blob (the only trusted input).
    #[arg(long)]
    genesis: PathBuf,
    /// Directory of `<seq>.binpb.zst` checkpoint files (untrusted input).
    #[arg(long)]
    checkpoints: PathBuf,
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Verify every available checkpoint from genesis and print a JSON report.
    Sync {
        /// Fail unless at least this many committee hand-offs were verified.
        #[arg(long, default_value_t = 0)]
        min_handoffs: u64,
    },
    /// Verify the chain, then report whether a transaction is final.
    Tx {
        #[arg(long)]
        digest: String,
    },
    /// Run negative tests: tampered data must be rejected.
    SelfTest,
}

struct Trusted {
    chain_id: ChainIdentifier,
    genesis_digest: CheckpointDigest,
    genesis_committee: Committee,
}

#[derive(Debug)]
struct Report {
    highest_checkpoint: u64,
    highest_epoch: u64,
    handoffs: u64,
    transactions: u64,
}

fn load_trusted(path: &Path) -> Result<Trusted> {
    let genesis =
        Genesis::load(path).with_context(|| format!("loading genesis {}", path.display()))?;
    let genesis_digest = *genesis.checkpoint().digest();
    Ok(Trusted {
        chain_id: ChainIdentifier::from(genesis_digest),
        genesis_digest,
        genesis_committee: genesis.committee(),
    })
}

fn read_checkpoint_file(path: &Path) -> Result<CheckpointData> {
    let compressed = std::fs::read(path).with_context(|| format!("reading {}", path.display()))?;
    let bytes = zstd::decode_all(&compressed[..]).context("zstd decode")?;
    let proto = ProtoCheckpoint::decode(&bytes[..]).context("protobuf decode")?;
    let checkpoint: Checkpoint = (&proto)
        .try_into()
        .map_err(|e| anyhow!("proto conversion: {e:?}"))?;
    Ok(checkpoint.into())
}

/// Loads checkpoints in sequence order, stopping at the first gap.
fn load_checkpoints(dir: &Path) -> Result<Vec<CheckpointData>> {
    let mut by_seq = BTreeMap::new();
    for entry in std::fs::read_dir(dir).with_context(|| format!("listing {}", dir.display()))? {
        let path = entry?.path();
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or_default();
        if let Some(seq) = name.strip_suffix(".binpb.zst").and_then(|s| s.parse::<u64>().ok()) {
            by_seq.insert(seq, path);
        }
    }
    let mut out = Vec::new();
    let mut expected = by_seq.keys().next().copied().unwrap_or(0);
    for (seq, path) in by_seq {
        if seq != expected {
            break;
        }
        out.push(read_checkpoint_file(&path)?);
        expected += 1;
    }
    Ok(out)
}

/// Builds a committee, returning an error (instead of the upstream assertion
/// panic) if the membership is empty or the voting power is not exactly 10,000.
fn committee_from(
    epoch: u64,
    members: impl Iterator<Item = (AuthorityName, StakeUnit)>,
) -> Result<Committee> {
    let members: BTreeMap<AuthorityName, StakeUnit> = members.collect();
    ensure!(!members.is_empty(), "committee has no members");
    let total = members
        .values()
        .try_fold(0u64, |acc, s| acc.checked_add(*s))
        .ok_or_else(|| anyhow!("committee voting power overflows"))?;
    ensure!(
        total == TOTAL_VOTING_POWER,
        "committee voting power {total} != {TOTAL_VOTING_POWER}"
    );
    Ok(Committee::new(epoch, members))
}

/// Pure verification over an ordered checkpoint sequence. No I/O.
fn verify_sequence(trusted: &Trusted, checkpoints: &[CheckpointData]) -> Result<Report> {
    ensure!(!checkpoints.is_empty(), "no checkpoints to verify");

    let mut committee = trusted.genesis_committee.clone();
    let mut prev_digest: Option<CheckpointDigest> = None;
    let mut next_seq: u64 = 0;
    let mut handoffs = 0u64;
    let mut transactions = 0u64;

    let first_seq = checkpoints[0].checkpoint_summary.data().sequence_number;
    if first_seq != 0 {
        // Checkpoint 0 is the genesis checkpoint, which we already trust.
        ensure!(first_seq == 1, "checkpoint stream must start at 0 or 1, got {first_seq}");
        prev_digest = Some(trusted.genesis_digest);
        next_seq = 1;
    }

    for cp in checkpoints {
        let summary = &cp.checkpoint_summary;
        let data = summary.data();

        ensure!(
            data.sequence_number == next_seq,
            "gap or reorder: expected checkpoint {next_seq}, got {}",
            data.sequence_number
        );
        ensure!(
            data.epoch == committee.epoch,
            "checkpoint {} claims epoch {} but the verified committee is for epoch {} \
             (missing or forged committee hand-off)",
            data.sequence_number,
            data.epoch,
            committee.epoch
        );

        summary
            .verify_with_contents(&committee, Some(&cp.checkpoint_contents))
            .map_err(|e| anyhow!("checkpoint {} failed certificate check: {e}", data.sequence_number))?;

        if data.sequence_number == 0 {
            ensure!(
                *summary.digest() == trusted.genesis_digest,
                "checkpoint 0 does not match the trusted genesis (wrong chain)"
            );
        } else {
            ensure!(
                data.previous_digest == prev_digest,
                "checkpoint {} does not link to the previous verified checkpoint",
                data.sequence_number
            );
        }

        // Every transaction in the file must be exactly what the certified contents commit to.
        ensure!(
            cp.transactions.len() == cp.checkpoint_contents.size(),
            "checkpoint {}: {} transactions but contents list {}",
            data.sequence_number,
            cp.transactions.len(),
            cp.checkpoint_contents.size()
        );
        for (tx, digests) in cp.transactions.iter().zip(cp.checkpoint_contents.iter()) {
            ensure!(
                tx.effects.execution_digests() == *digests,
                "checkpoint {}: effects do not match certified contents",
                data.sequence_number
            );
            let events_digest = tx.events.as_ref().map(|ev| ev.digest());
            ensure!(
                events_digest.as_ref() == tx.effects.events_digest(),
                "checkpoint {}: events do not match effects",
                data.sequence_number
            );
            transactions += 1;
        }

        if let Some(next) = data.next_epoch_committee() {
            let next_epoch = data
                .epoch
                .checked_add(1)
                .ok_or_else(|| anyhow!("epoch overflow"))?;
            committee = committee_from(next_epoch, next.iter().cloned())
                .with_context(|| format!("hand-off at checkpoint {}", data.sequence_number))?;
            handoffs += 1;
        }

        prev_digest = Some(*summary.digest());
        next_seq += 1;
    }

    let last = checkpoints.last().expect("non-empty").checkpoint_summary.data();
    Ok(Report {
        highest_checkpoint: last.sequence_number,
        highest_epoch: last.epoch,
        handoffs,
        transactions,
    })
}

fn find_final_tx(checkpoints: &[CheckpointData], digest: TransactionDigest) -> Option<(u64, bool, String)> {
    for cp in checkpoints {
        for tx in &cp.transactions {
            if *tx.effects.transaction_digest() == digest {
                let status = tx.effects.status();
                return Some((
                    cp.checkpoint_summary.data().sequence_number,
                    status.is_ok(),
                    format!("{status:?}"),
                ));
            }
        }
    }
    None
}

/// Each case mutates verified data in one way an attacker or a faulty RPC
/// could, and requires verification to fail.
fn self_test(trusted: &Trusted, checkpoints: &[CheckpointData]) -> Result<Vec<(&'static str, String)>> {
    verify_sequence(trusted, checkpoints).context("baseline must verify before tampering")?;
    ensure!(checkpoints.len() >= 3, "self-test needs at least 3 checkpoints");

    let mut results = Vec::new();
    fn expect_reject(
        results: &mut Vec<(&'static str, String)>,
        trusted: &Trusted,
        name: &'static str,
        cps: &[CheckpointData],
    ) -> Result<()> {
        match verify_sequence(trusted, cps) {
            Ok(_) => bail!("TAMPER NOT DETECTED: {name}"),
            Err(e) => {
                results.push((name, format!("{e:#}")));
                Ok(())
            }
        }
    }

    // 1. Altered summary field (signature no longer matches).
    let mut cps = checkpoints.to_vec();
    cps[1].checkpoint_summary.data_mut_for_testing().timestamp_ms += 1;
    expect_reject(&mut results, trusted, "altered-summary", &cps)?;

    // 2. Contents from another checkpoint (content digest mismatch).
    let mut cps = checkpoints.to_vec();
    let other = cps
        .iter()
        .skip(2)
        .find(|c| c.checkpoint_contents.digest() != cps[1].checkpoint_contents.digest())
        .map(|c| c.checkpoint_contents.clone());
    if let Some(contents) = other {
        cps[1].checkpoint_contents = contents;
        expect_reject(&mut results, trusted, "swapped-contents", &cps)?;
    }

    // 3. Withheld checkpoint (gap in the chain).
    let mut cps = checkpoints.to_vec();
    cps.remove(1);
    expect_reject(&mut results, trusted, "withheld-checkpoint", &cps)?;

    // 4. Wrong committee: a single validator holding all voting power cannot
    //    validate certificates produced by the real committee.
    let (lone, _) = trusted.genesis_committee.voting_rights[0];
    let wrong = Trusted {
        chain_id: trusted.chain_id,
        genesis_digest: trusted.genesis_digest,
        genesis_committee: committee_from(
            trusted.genesis_committee.epoch,
            std::iter::once((lone, TOTAL_VOTING_POWER)),
        )?,
    };
    expect_reject(&mut results, &wrong, "wrong-committee", checkpoints)?;

    // 5. Forged committee hand-off (only if an end-of-epoch checkpoint exists).
    if let Some(idx) = checkpoints
        .iter()
        .position(|c| c.checkpoint_summary.data().end_of_epoch_data.is_some())
    {
        let mut cps = checkpoints.to_vec();
        if let Some(eoe) = cps[idx].checkpoint_summary.data_mut_for_testing().end_of_epoch_data.as_mut() {
            eoe.next_epoch_committee.truncate(1);
        }
        expect_reject(&mut results, trusted, "forged-handoff", &cps)?;
    }

    Ok(results)
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let trusted = load_trusted(&cli.genesis)?;
    let checkpoints = load_checkpoints(&cli.checkpoints)?;

    match cli.cmd {
        Cmd::Sync { min_handoffs } => {
            let r = verify_sequence(&trusted, &checkpoints)?;
            println!(
                "{}",
                json!({
                    "result": "VERIFIED",
                    "chain_id": trusted.chain_id.to_string(),
                    "highest_checkpoint": r.highest_checkpoint,
                    "highest_epoch": r.highest_epoch,
                    "committee_handoffs": r.handoffs,
                    "transactions": r.transactions,
                })
            );
            ensure!(
                r.handoffs >= min_handoffs,
                "only {} committee hand-offs verified, need {min_handoffs}",
                r.handoffs
            );
        }
        Cmd::Tx { digest } => {
            let digest = TransactionDigest::from_str(&digest)
                .map_err(|e| anyhow!("invalid transaction digest: {e}"))?;
            verify_sequence(&trusted, &checkpoints)?;
            match find_final_tx(&checkpoints, digest) {
                Some((seq, ok, status)) => println!(
                    "{}",
                    json!({
                        "result": "FINAL",
                        "digest": digest.to_string(),
                        "checkpoint": seq,
                        "success": ok,
                        "execution_status": status,
                    })
                ),
                None => {
                    println!("{}", json!({"result": "NOT_FINAL", "digest": digest.to_string()}));
                    std::process::exit(2);
                }
            }
        }
        Cmd::SelfTest => {
            let results = self_test(&trusted, &checkpoints)?;
            let cases: Vec<_> = results
                .iter()
                .map(|(n, e)| json!({"case": n, "rejected_with": e}))
                .collect();
            println!("{}", json!({"result": "ALL_TAMPERING_REJECTED", "cases": cases}));
        }
    }
    Ok(())
}
