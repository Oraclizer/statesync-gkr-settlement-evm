#!/usr/bin/env python3
"""Strict verifier for the Local CDK L2 evidence package."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


def strict_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=strict_pairs)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    manifest_path = args.manifest.resolve()
    evidence = manifest_path.parent
    repository = evidence.parents[1]
    manifest = load(manifest_path)

    require(manifest["schema"] == "statesync-gkr-cdk-l2-smoke-manifest-v1", "schema")
    require(manifest["status"] == "writer-candidate-pass", "status")
    require(manifest["scope"] == "ephemeral-local-stock-cdk-l2-evm-compatibility-only", "scope")

    listed = {row["path"] for row in manifest["files"]}
    actual = {
        path.relative_to(evidence).as_posix()
        for path in evidence.rglob("*")
        if path.is_file() and path.name not in {"manifest.json", "manifest.sha256"}
    }
    require(listed == actual, f"evidence file set mismatch: listed={len(listed)} actual={len(actual)}")
    for row in manifest["files"]:
        path = evidence / row["path"]
        require(path.stat().st_size == row["bytes"], f"size mismatch: {row['path']}")
        require(digest(path) == row["sha256"], f"hash mismatch: {row['path']}")

    for row in manifest["implementation_files"]:
        path = repository / row["path"]
        require(path.stat().st_size == row["bytes"], f"implementation size: {row['path']}")
        require(digest(path) == row["sha256"], f"implementation hash: {row['path']}")

    sidecar = evidence / "manifest.sha256"
    require(sidecar.read_text(encoding="utf-8") == f"{digest(manifest_path)}  manifest.json\n", "sidecar")

    execution = load(evidence / manifest["execution"]["evidence_path"])
    require(digest(evidence / manifest["execution"]["evidence_path"]) == manifest["execution"]["evidence_sha256"], "execution evidence hash")
    require(execution["schema"] == "statesync-gkr-cdk-l2-execution-evidence-v1", "execution schema")
    require(execution["chain_id"] == 2151908, "chain ID")
    require(execution["execute_smoke"]["status"] == 1, "execute status")
    require(execution["execute_smoke"]["sequencer_replica_receipt_equality"], "receipt equality")
    require(execution["execute_smoke"]["sequencer_replica_block_hash_equality"], "block equality")
    require(len(execution["contracts"]) == 5, "contract count")
    require(all(row["sequencer_replica_byte_equality"] for row in execution["contracts"]), "runtime equality")
    require(len(execution["negative_events"]) == 3, "negative count")
    require(all(row["state_unchanged"] for row in execution["negative_events"]), "negative state")
    observed_selectors = {row["observed_selector_topic"][:10] for row in execution["negative_events"]}
    require(observed_selectors == {"0x1701ddf4", "0xcc094867", "0x4899bc72"}, "negative selectors")
    require(all(execution["product_evm_match"].values()), "Product/EVM match")
    require(execution["final_state"] == {"event_count": 1, "transition_count": 1}, "final state")

    rust_output = evidence / "raw" / "product-reference-rust-stdout-lf.txt"
    python_output = evidence / "raw" / "product-reference-python.txt"
    require(rust_output.read_bytes() == python_output.read_bytes(), "Product reference byte equality")
    require(rust_output.stat().st_size == 2034, "Product reference length")
    require(digest(rust_output) == "dc81b33f029446338c101faae0ffb841e854b4ce4f508087a1001175fc56c725", "Product reference hash")

    config = repository / "script" / "cdk-l2-smoke" / "sovereign-ecdsa-multisig-v0.5.21.yml"
    upstream_config = evidence / "raw" / "baseline" / "carrier-config-upstream.yml"
    require(config.read_bytes() == upstream_config.read_bytes(), "carrier config byte equality")
    require(digest(config) == manifest["carrier"]["config_sha256"], "carrier config hash")

    redaction = load(evidence / "raw" / "devnet-run-redaction-manifest.json")
    sanitized = evidence / "raw" / "devnet-run.sanitized.log"
    require(not redaction["unredacted_input_preserved"], "unredacted disposition")
    require(digest(sanitized) == redaction["output_sha256"], "sanitized transcript hash")
    require(not (evidence / "raw" / "devnet-run.log").exists(), "unredacted transcript exists")
    require(b"<LOCAL_FIXTURE_REDACTED>" in sanitized.read_bytes(), "redaction token absent")
    sanitized_text = sanitized.read_text(encoding="utf-8", errors="replace")
    key_field = re.compile(
        r'(?i)"[^"\n]*(?:private_key|privatekey|pvtkey|prover_key)[^"\n]*"\s*:\s*"(?:0x)?[0-9a-f]{64}"'
    )
    require(key_field.search(sanitized_text) is None, "credential-shaped key field remains")
    require(redaction["distinct_values_redacted"] == 21, "redacted value count")
    require(redaction["replacement_count"] == 49, "redaction replacement count")

    failed = (evidence / "raw" / "failed-attempt-final-state.txt").read_text(encoding="utf-8")
    require("transition_count=0" in failed and "event_count=0" in failed and "pfr_next_nonce=1" in failed, "failed attempt state")
    require("0x9ba67430" in (evidence / "raw" / "failed-broadcast-replay-call.txt").read_text(encoding="utf-8"), "RootExpired selector")

    cleanup = load(evidence / "raw" / "docker-baseline-restoration.json")
    require(cleanup["container_id_name_equality"], "container cleanup")
    require(cleanup["volume_name_equality"], "volume cleanup")
    require(cleanup["network_name_driver_scope_equality"], "network cleanup")
    require(cleanup["enclave_container_count"] == 0, "enclave containers")
    require(cleanup["enclave_volume_count"] == 0, "enclave volumes")
    require(cleanup["enclave_network_count"] == 0, "enclave networks")

    image_inventory = (evidence / "raw" / "enclave-container-images-before-teardown.tsv").read_text(encoding="utf-8")
    required_images = {
        "ghcr.io/paradigmxyz/reth:v2.4.1": "0d16db7cfaa9e2aa8dc87664f94fd87d9a34f1a79d7eeded1c4867f91f9c13d4",
        "sigp/lighthouse:v8.2.1": "9538f53d8e11766e3cb5de1889b292074f8e518e0dabe6df13d9054d504d1d62",
        "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-reth:v2.4.0": "4bc077fc2068b537ec0bffb86fca027b30cac9a0b02dbfdece2363f1c1bbc861",
        "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.19.3": "2254e2a715cff6a937dbbfe1b44b8dc23c464f8b0cac60e4013b30a202fcb72e",
        "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:v1.16.11": "af95492b091d0d7759074d8866a0c0daa5227cfdcc1520efc5e3d3ec9934af48",
    }
    for image, image_digest in required_images.items():
        require(image in image_inventory and image_digest in image_inventory, f"image digest: {image}")

    source_diff = evidence / "raw" / "baseline" / "evm-production-source-diff-windows.patch"
    require(source_diff.stat().st_size == 0, "production source diff")
    require(not (repository / "cache" / "CdkL2Smoke.s.sol").exists(), "sensitive Foundry cache")
    require(not (repository / "broadcast" / "CdkL2Smoke.s.sol").exists(), "duplicate broadcast directory")

    report = (evidence / "README.md").read_text(encoding="utf-8")
    require("—" not in report, "em dash")
    for forbidden in (
        "native CDK execution proof PASS",
        "Base confirmation PASS",
        "SECONDARY_FINALIZED PASS",
        "production readiness PASS",
    ):
        require(forbidden not in report, f"claim ceiling: {forbidden}")

    print(
        json.dumps(
            {
                "status": "PASS",
                "manifest_sha256": digest(manifest_path),
                "files": len(manifest["files"]),
                "contracts": len(execution["contracts"]),
                "negative_discrepancies": 0,
                "product_evm_discrepancies": 0,
                "cleanup_discrepancies": 0,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
