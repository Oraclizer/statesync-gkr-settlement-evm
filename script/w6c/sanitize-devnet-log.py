#!/usr/bin/env python3
"""Redact local-only fixture credentials from a Kurtosis CDK transcript."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


HEX_KEY = re.compile(r"0x[0-9a-fA-F]{64}")
REDACTED_TOKEN = "<LOCAL_FIXTURE_REDACTED>"
KEY_FIELD = re.compile(
    r'(?i)"[^"\n]*(?:private_key|privatekey|pvtkey|prover_key)[^"\n]*"\s*:\s*"((?:0x)?[0-9a-f]{64})"'
)
MNEMONIC_FIELD = re.compile(r'(?i)"[^"\n]*mnemonic[^"\n]*"\s*:\s*"([^"]+)"')
PASSWORD_FIELD = re.compile(r'(?i)"[^"\n]*(?:password)[^"\n]*"\s*:\s*"([^"]+)"')


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--prior-manifest", type=Path)
    args = parser.parse_args()

    source = args.input.read_bytes()
    text = source.decode("utf-8", errors="replace")
    secrets = {
        match.group(1) for match in KEY_FIELD.finditer(text) if match.group(1) != REDACTED_TOKEN
    }
    secrets.update(
        match.group(1) for match in MNEMONIC_FIELD.finditer(text) if match.group(1) != REDACTED_TOKEN
    )
    secrets.update(
        match.group(1) for match in PASSWORD_FIELD.finditer(text) if match.group(1) != REDACTED_TOKEN
    )

    lines = text.splitlines(keepends=True)
    for index, line in enumerate(lines):
        if "Generating a new private key" not in line and "Deriving the private key" not in line:
            continue
        for following in lines[index + 1 : index + 5]:
            match = HEX_KEY.search(following)
            if match:
                secrets.add(match.group(0))
                break

    redacted = text
    replacements = 0
    for secret in sorted(secrets, key=len, reverse=True):
        count = redacted.count(secret)
        if count:
            redacted = redacted.replace(secret, REDACTED_TOKEN)
            replacements += count

    if KEY_FIELD.search(redacted):
        raise ValueError("private-key value remains after redaction")
    for pattern in (MNEMONIC_FIELD, PASSWORD_FIELD):
        for match in pattern.finditer(redacted):
            if match.group(1) != REDACTED_TOKEN:
                raise ValueError("credential-shaped value remains after redaction")

    output = redacted.encode("utf-8")
    args.output.write_bytes(output)
    prior = None
    if args.prior_manifest is not None:
        prior = json.loads(args.prior_manifest.read_text(encoding="utf-8"))
    args.manifest.write_text(
        json.dumps(
            {
                "schema": "w6c-local-fixture-redaction-v1",
                "input_sha256": prior["input_sha256"] if prior else sha256(source),
                **({"intermediate_sha256": prior["output_sha256"]} if prior else {}),
                "output_sha256": sha256(output),
                "distinct_values_redacted": (prior["distinct_values_redacted"] if prior else 0)
                + len(secrets),
                "replacement_count": (prior["replacement_count"] if prior else 0) + replacements,
                "unredacted_input_preserved": False,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"redacted_values={len(secrets)} replacements={replacements} cumulative={prior is not None}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
