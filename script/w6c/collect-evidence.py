#!/usr/bin/env python3
"""Collect deterministic W6-COMPONENT local CDK L2 execution evidence."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def cast_json(*args: str) -> dict[str, Any]:
    return json.loads(run("cast", *args))


def keccak(value: str) -> str:
    return run("cast", "keccak", value).lower()


def words(data: str) -> list[str]:
    payload = data.removeprefix("0x")
    if len(payload) % 64 != 0:
        raise ValueError("event data is not word aligned")
    return ["0x" + payload[index : index + 64].lower() for index in range(0, len(payload), 64)]


def first_log(receipt: dict[str, Any], topic0: str) -> dict[str, Any]:
    matches = [log for log in receipt["logs"] if log["topics"][0].lower() == topic0]
    if len(matches) != 1:
        raise ValueError(f"expected one log for {topic0}, got {len(matches)}")
    return matches[0]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--broadcast-json", required=True, type=Path)
    parser.add_argument("--sequencer-rpc", required=True)
    parser.add_argument("--replica-rpc", required=True)
    parser.add_argument("--product-vector", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    broadcast = json.loads(args.broadcast_json.read_text(encoding="utf-8"))
    product = json.loads(args.product_vector.read_text(encoding="utf-8"))
    transactions = broadcast["transactions"]
    creates = [transaction for transaction in transactions if transaction["transactionType"] == "CREATE"]
    if len(creates) != 5:
        raise ValueError(f"expected five contract creations, got {len(creates)}")

    contract_rows: list[dict[str, Any]] = []
    for transaction in creates:
        tx_hash = transaction["hash"].lower()
        address = transaction["contractAddress"].lower()
        tx = cast_json("tx", "--json", "--rpc-url", args.sequencer_rpc, tx_hash)
        receipt = cast_json("receipt", "--json", "--rpc-url", args.sequencer_rpc, tx_hash)
        replica_receipt = cast_json("receipt", "--json", "--rpc-url", args.replica_rpc, tx_hash)
        if receipt != replica_receipt or receipt["status"] != "0x1":
            raise ValueError(f"creation receipt mismatch for {transaction['contractName']}")
        runtime = run("cast", "code", "--rpc-url", args.sequencer_rpc, address).lower()
        replica_runtime = run("cast", "code", "--rpc-url", args.replica_rpc, address).lower()
        if runtime == "0x" or runtime != replica_runtime:
            raise ValueError(f"runtime mismatch for {transaction['contractName']}")
        creation = tx["input"].lower()
        contract_rows.append(
            {
                "contract": transaction["contractName"],
                "address": address,
                "transaction_hash": tx_hash,
                "block_number": int(receipt["blockNumber"], 16),
                "block_hash": receipt["blockHash"].lower(),
                "creation_bytes": (len(creation) - 2) // 2,
                "creation_keccak256": keccak(creation),
                "runtime_bytes": (len(runtime) - 2) // 2,
                "runtime_keccak256": keccak(runtime),
                "sequencer_replica_byte_equality": True,
            }
        )

    execute = transactions[-1]
    if execute["function"].split("(", 1)[0] != "executeSmoke":
        raise ValueError("last transaction is not executeSmoke")
    execute_hash = execute["hash"].lower()
    receipt = cast_json("receipt", "--json", "--rpc-url", args.sequencer_rpc, execute_hash)
    replica_receipt = cast_json("receipt", "--json", "--rpc-url", args.replica_rpc, execute_hash)
    if receipt != replica_receipt or receipt["status"] != "0x1":
        raise ValueError("executeSmoke receipt mismatch")
    block_number = int(receipt["blockNumber"], 16)
    block = cast_json("block", "--json", "--rpc-url", args.sequencer_rpc, str(block_number))
    replica_block = cast_json("block", "--json", "--rpc-url", args.replica_rpc, str(block_number))
    if block["hash"].lower() != replica_block["hash"].lower() or block["hash"].lower() != receipt["blockHash"].lower():
        raise ValueError("executeSmoke block mismatch")

    settlement_topic = keccak(
        "SettlementConsumedV2(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint64)"
    )
    negative_topic = keccak(
        "NegativeProbeResult(bytes32,bytes4,bytes32,bytes32,bytes32,bytes32)"
    )
    product_topic = keccak(
        "ProductReferenceMatched(bytes32,bytes32,bytes32,bytes32,uint64)"
    )
    complete_topic = keccak("SmokeExecutionComplete(address,address,address,address)")

    settlement_log = first_log(receipt, settlement_topic)
    settlement_words = words(settlement_log["data"])
    if len(settlement_words) != 4:
        raise ValueError("unexpected SettlementConsumedV2 data")
    settlement_event = {
        "route_id": settlement_log["topics"][1].lower(),
        "claim_id": settlement_log["topics"][2].lower(),
        "settlement_key": settlement_log["topics"][3].lower(),
        "primary_finality_record_id": settlement_words[0],
        "primary_finality_authorization_digest": settlement_words[1],
        "accepted_root": settlement_words[2],
        "lifecycle_revision": int(settlement_words[3], 16),
    }

    negative_logs = [log for log in receipt["logs"] if log["topics"][0].lower() == negative_topic]
    if len(negative_logs) != 3:
        raise ValueError(f"expected three negative logs, got {len(negative_logs)}")
    negative_events: list[dict[str, Any]] = []
    for log in negative_logs:
        event_words = words(log["data"])
        if len(event_words) != 4 or event_words[0] != event_words[1] or event_words[2] != event_words[3]:
            raise ValueError("negative probe changed state")
        negative_events.append(
            {
                "probe_id": log["topics"][1].lower(),
                "observed_selector_topic": log["topics"][2].lower(),
                "settlement_before": event_words[0],
                "settlement_after": event_words[1],
                "pfr_before": event_words[2],
                "pfr_after": event_words[3],
                "state_unchanged": True,
            }
        )

    product_log = first_log(receipt, product_topic)
    product_words = words(product_log["data"])
    if len(product_words) != 3:
        raise ValueError("unexpected ProductReferenceMatched data")
    product_event = {
        "raw_statement_sha256": product_log["topics"][1].lower(),
        "accepted_root": product_log["topics"][2].lower(),
        "claim_id": product_words[0],
        "settlement_key": product_words[1],
        "transition_count": int(product_words[2], 16),
    }
    first_log(receipt, complete_topic)

    expected = product["transition"]
    product_match = {
        "route_id": settlement_event["route_id"] == "0x" + expected["route_id"].lower(),
        "raw_statement_sha256": product_event["raw_statement_sha256"]
        == "0x" + expected["raw192_sha256"].lower(),
        "next_application_state": settlement_event["accepted_root"]
        == "0x" + expected["next_application_state"].lower(),
        "transition_count": product_event["transition_count"] == 1,
    }
    if not all(product_match.values()):
        raise ValueError(f"Product/EVM mismatch: {product_match}")

    settlement_address = next(
        row["address"] for row in contract_rows if row["contract"] == "StateSyncGKRSettlementV2"
    )
    transition_count = int(
        run(
            "cast",
            "call",
            "--rpc-url",
            args.replica_rpc,
            settlement_address,
            "transitionCount()(uint64)",
        )
    )
    event_count = int(
        run(
            "cast",
            "call",
            "--rpc-url",
            args.replica_rpc,
            settlement_address,
            "eventCount()(uint64)",
        )
    )
    if transition_count != 1 or event_count != 1:
        raise ValueError("unexpected final transition/event count")

    output = {
        "schema": "statesync-gkr-w6c-cdk-l2-execution-evidence-v1",
        "scope": "ephemeral-local-stock-cdk-l2-evm-compatibility-only",
        "chain_id": int(run("cast", "chain-id", "--rpc-url", args.replica_rpc)),
        "contracts": contract_rows,
        "execute_smoke": {
            "transaction_hash": execute_hash,
            "block_number": block_number,
            "block_hash": receipt["blockHash"].lower(),
            "status": 1,
            "log_count": len(receipt["logs"]),
            "sequencer_replica_receipt_equality": True,
            "sequencer_replica_block_hash_equality": True,
        },
        "settlement_event": settlement_event,
        "negative_events": negative_events,
        "product_reference_event": product_event,
        "product_evm_match": product_match,
        "final_state": {"transition_count": transition_count, "event_count": event_count},
        "nonclaims": [
            "No native CDK execution proof was generated.",
            "No Base confirmation or SECONDARY_FINALIZED fact was produced.",
            "No public testnet or production transaction was sent.",
        ],
    }
    args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": "PASS", "output": str(args.output)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
