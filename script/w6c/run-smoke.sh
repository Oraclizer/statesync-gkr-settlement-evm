#!/usr/bin/env bash
set -euo pipefail

mode="${1:?usage: run-smoke.sh <simulate|broadcast> <rpc-url> <raw-evidence-dir>}"
rpc_url="${2:?missing RPC URL}"
raw_dir="${3:?missing raw evidence directory}"
worktree="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
devnet_log="$raw_dir/devnet-run.log"

case "$mode" in
  simulate | broadcast) ;;
  *)
    echo "unsupported mode: $mode" >&2
    exit 64
    ;;
esac

fixture_key="${W6C_DEPLOYER_PRIVATE_KEY:-}"
if [[ -z "$fixture_key" && -f "$devnet_log" ]]; then
  fixture_key="$({
    sed -n 's/.*"l2_admin_private_key": "\(0x[0-9a-f]\{64\}\)".*/\1/p' "$devnet_log"
    sed -n 's/.*"zkevm_l2_admin_private_key": "\(0x[0-9a-f]\{64\}\)".*/\1/p' "$devnet_log"
  } | sort -u | head -n 1)"
fi

if [[ ! "$fixture_key" =~ ^0x[0-9a-f]{64}$ ]]; then
  echo "local fixture key not found" >&2
  exit 65
fi

deployer_address="$(cast wallet address --private-key "$fixture_key")"
printf 'deployer_address=%s\n' "$deployer_address" > "$raw_dir/smoke-deployer-address.txt"
cast balance --rpc-url "$rpc_url" "$deployer_address" > "$raw_dir/smoke-deployer-balance-before.txt"

export W6C_DEPLOYER_PRIVATE_KEY="$fixture_key"
command=(
  forge script
  script/W6CCdkL2Smoke.s.sol:W6CCdkL2SmokeScript
  --rpc-url "$rpc_url"
  --offline
  --use /usr/local/bin/solc
  -vvv
)

if [[ "$mode" == "broadcast" ]]; then
  command+=(--broadcast --slow)
fi

cd "$worktree"
"${command[@]}"
unset W6C_DEPLOYER_PRIVATE_KEY fixture_key
