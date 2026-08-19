#!/usr/bin/env python3
"""Build the content-addressed W6-COMPONENT local CDK L2 manifest."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    repository = Path(__file__).resolve().parents[2]
    evidence = repository / "evidence" / "w6c-cdk-l2-smoke"
    manifest_path = evidence / "manifest.json"
    sidecar_path = evidence / "manifest.sha256"
    implementation_paths = [
        ".github/workflows/ci.yml",
        "script/W6CCdkL2Smoke.s.sol",
        "script/w6c/sovereign-ecdsa-multisig-v0.5.21.yml",
        "script/w6c/run-smoke.sh",
        "script/w6c/collect-evidence.py",
        "script/w6c/sanitize-devnet-log.py",
        "script/w6c/build-manifest.py",
        "script/w6c/verify-manifest.py",
    ]
    excluded = {manifest_path.resolve(), sidecar_path.resolve()}
    files = []
    for path in sorted(item for item in evidence.rglob("*") if item.is_file()):
        if path.resolve() in excluded:
            continue
        files.append(
            {
                "path": path.relative_to(evidence).as_posix(),
                "bytes": path.stat().st_size,
                "sha256": digest(path),
            }
        )

    execution_path = evidence / "raw" / "execution-evidence.json"
    execution = json.loads(execution_path.read_text(encoding="utf-8"))
    manifest = {
        "schema": "statesync-gkr-w6c-cdk-l2-smoke-manifest-v1",
        "status": "writer-candidate-pass",
        "scope": "ephemeral-local-stock-cdk-l2-evm-compatibility-only",
        "inputs": {
            "evm": {
                "commit": "de13557322237865632a748d1ae6848b9a1d1d15",
                "tree": "a92dc39e0ef5ce4f3aad7ccc3eeae5ca62c3b521",
                "production_source_changed": False,
            },
            "product": {
                "commit": "85ca530b971b5056aea74f73033ae8d2919a56a3",
                "tree": "02e25ddb3337dd998338f60d715634af3e0f192b",
                "reference_stdout_bytes": 2034,
                "reference_stdout_sha256": "dc81b33f029446338c101faae0ffb841e854b4ce4f508087a1001175fc56c725",
            },
        },
        "carrier": {
            "repository": "https://github.com/0xPolygon/kurtosis-cdk",
            "release": "v0.5.21",
            "commit": "54e715eafb727bfcc953ee07befd5115964e6115",
            "tree": "1df9b8c9bb1ceda7b4b229053898ffb4936449a0",
            "config_path": ".github/tests/op-reth/sovereign-ecdsa-multisig.yml",
            "config_blob": "ba9f23e650095ec64fe6cac17fce9823bf4b4dc1",
            "config_sha256": "3b4ae959184fb50a2f1caebccf24eb5f638af0bce37013c47040070eeec13d12",
            "kurtosis_cli": "1.20.0",
            "l1_chain_id": 271828,
            "l2_chain_id": 2151908,
            "op_succinct_deployed": False,
        },
        "execution": {
            "evidence_path": "raw/execution-evidence.json",
            "evidence_sha256": digest(execution_path),
            "transaction_hash": execution["execute_smoke"]["transaction_hash"],
            "block_number": execution["execute_smoke"]["block_number"],
            "block_hash": execution["execute_smoke"]["block_hash"],
            "status": execution["execute_smoke"]["status"],
            "contract_count": len(execution["contracts"]),
            "negative_count": len(execution["negative_events"]),
            "product_evm_match": execution["product_evm_match"],
        },
        "routine_repairs": [
            "WSL automatic shutdown stopped Docker after the completed package run; a temporary keepalive and exact existing service restart restored block progression.",
            "The first thirteen-transaction harness exhausted the unchanged 20-block root validity window; its transition count remained zero and the repaired coordinator carrier completed in six transactions.",
            "Exact runner found one bare-form public local fixture prover key in the sanitized transcript. The sanitizer and independent verifier now cover prefixed and bare credential-shaped key fields; the rebuilt transcript contains zero credential-shaped values and preserves 21 distinct redactions across 49 occurrences.",
            "Independent audit found that the smoke script embeds deployment initcode and therefore exceeds EIP-170 when the repository build requests deployment sizes. CI now compiles every source first, then applies the unchanged deployment-size gate with Foundry's script-only exclusion; the executed harness and production contracts are unchanged.",
        ],
        "cleanup": {
            "enclave": "w6-component-smoke-20260819",
            "enclave_containers": 0,
            "enclave_volumes": 0,
            "enclave_networks": 0,
            "unredacted_transcript_preserved": False,
            "sensitive_foundry_cache_preserved": False,
            "image_cache_retained": True,
        },
        "implementation_files": [
            {
                "path": relative,
                "bytes": (repository / relative).stat().st_size,
                "sha256": digest(repository / relative),
            }
            for relative in implementation_paths
        ],
        "files": files,
        "nonclaims": [
            "No actual Polygon CDK L3 deployment was performed.",
            "No native CDK execution proof was generated or verified.",
            "No Base-parent stock support or Base confirmation was demonstrated.",
            "No SECONDARY_FINALIZED or production completion fact was produced.",
            "No public testnet, external RPC mutation, public transaction, or public visibility action occurred.",
        ],
    }
    with manifest_path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    with sidecar_path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(f"{digest(manifest_path)}  manifest.json\n")
    print(f"manifest_sha256={digest(manifest_path)} files={len(files)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
