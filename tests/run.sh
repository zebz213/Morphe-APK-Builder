#!/usr/bin/env bash
# Unit tests for the builder's pure logic: no network, no JDK, no Lavalink.
# Everything that needs the patcher or a real APK is covered by the build
# workflow instead. Run with: bash tests/run.sh
#
# SC2034: several values below are consumed by sourced utils.sh helpers and by
# nameref arguments, which shellcheck cannot follow.
# shellcheck disable=SC2034
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

# utils.sh sources the signing env when the file exists; tests must not need it.
export KS_ENV_FILE=/dev/null

# shellcheck source=../utils.sh
source utils.sh
# shellcheck source=lib.sh
source tests/lib.sh

FIX="$ROOT/tests/fixtures"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

set_prebuilts
# config_update_case runs inside a temp dir, so the toml helper must be absolute
TOML="$ROOT/$TOML"
# consumed by config_update/toml_get inside utils.sh
export DEF_PATCHES_VER=latest
export DEF_CLI_VER=latest
export DEF_PATCHES_SRC=MorpheApp/morphe-patches
export DEF_CLI_SRC=MorpheApp/morphe-cli

# Serve a canned GitHub API release instead of calling out.
gh_req() { cat "$GH_RESPONSE"; }

# Run config_update in an isolated dir holding the build log (and optional
# retry marker), so the repo's own files are never read.
config_update_case() {
	local cfg=$1 build=$2 failed=${3-} dir
	dir=$(mktemp -d -p "$WORK")
	cp "$build" "$dir/build.md"
	if [ -n "$failed" ]; then printf '%s\n' "$failed" >"$dir/failed_prev"; fi
	(
		cd "$dir" || exit 1
		mkdir -p "$TEMP_DIR"
		toml_prep "$cfg" || exit 1
		config_update
	)
}

echo "config_update"

case_name 'matching patches and no failures leaves nothing to build'
GH_RESPONSE="$FIX/patches-2.0.0.json"
out=$(config_update_case "$FIX/config-two-apps.toml" "$FIX/build-2.0.0.md")
assert_empty "$out"

case_name 'a new patches release queues the first app on that source'
GH_RESPONSE="$FIX/patches-2.1.0.json"
out=$(config_update_case "$FIX/config-two-apps.toml" "$FIX/build-2.0.0.md")
assert_contains 'App1' "$out"

case_name 'a new patches release queues every app on that source'
assert_contains 'App2' "$out"

case_name 'a disabled app is never queued'
out=$(config_update_case "$FIX/config-disabled.toml" "$FIX/build-2.0.0.md")
assert_contains 'App1' "$out"

case_name 'the disabled app is not in that same build'
assert_not_contains 'App2' "$out"

case_name 'an app in failed_prev is rebuilt while its sibling is skipped'
GH_RESPONSE="$FIX/patches-2.0.0.json"
out=$(config_update_case "$FIX/config-two-apps.toml" "$FIX/build-2.0.0.md" 'App1 (arm-v7a)')
assert_contains 'App1' "$out"

case_name 'the sibling of a retried app stays skipped'
assert_not_contains 'App2' "$out"

echo "version selection"

case_name 'get_highest_ver picks the numerically highest version'
versions=$(printf '1.2.3\n1.10.0\n1.9.9\n')
out=$(get_highest_ver <<<"$versions")
assert_eq '1.10.0' "$out"

echo "argument parsing"

case_name 'split_args keeps a quoted name with spaces in one word'
out=$(split_args "-e 'Some Patch' -Ofoo=bar" | paste -sd '|')
assert_eq '-e|Some Patch|-Ofoo=bar' "$out"

case_name 'split_args unescapes quoted option values'
out=$(split_args '-OcurrentTag=\"3\"' | tr -d '\n')
assert_eq '-OcurrentTag="3"' "$out"

case_name 'split_args handles plain flags'
out=$(split_args '--exclusive -d Cover' | paste -sd '|')
assert_eq '--exclusive|-d|Cover' "$out"

case_name 'add_patch_args emits one flag/name pair per patch'
declare -a collected=()
add_patch_args collected -d "'A' 'B C'"
assert_eq '-d|A|-d|B C' "$(printf '%s|' "${collected[@]}" | sed 's/|$//')"

echo "secret masking"

case_name 'show_argv masks the keystore password'
KS_STORE_PASS='s3cr3t-value' KS_KEY_PASS='k3y-value'
declare -a secret_cmd=(java -jar cli.jar --keystore-password=s3cr3t-value -o out.apk)
out=$(show_argv secret_cmd)
assert_not_contains 's3cr3t-value' "$out"

case_name 'show_argv keeps the rest of the command readable'
assert_contains 'out.apk' "$out"

finish
