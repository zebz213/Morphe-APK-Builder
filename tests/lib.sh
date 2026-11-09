#!/usr/bin/env bash
# Tiny assertion helpers for the builder's bash test suite (no dependencies).

PASSED=0
FAILED=0
CASE=''

pass() { PASSED=$((PASSED + 1)); printf '  ok   %s\n' "$CASE"; }

fail() {
	FAILED=$((FAILED + 1))
	printf '  FAIL %s\n       %s\n' "$CASE" "$1"
}

case_name() { CASE=$1; }

assert_eq() {
	if [ "$1" = "$2" ]; then pass; else fail "expected [$1], got [$2]"; fi
}

assert_empty() {
	if [ -z "$1" ]; then pass; else fail "expected empty, got [$1]"; fi
}

assert_contains() {
	case "$2" in *"$1"*) pass ;; *) fail "[$2] does not contain [$1]" ;; esac
}

assert_not_contains() {
	case "$2" in *"$1"*) fail "[$2] must not contain [$1]" ;; *) pass ;; esac
}

finish() {
	printf '\n%s passed, %s failed\n' "$PASSED" "$FAILED"
	[ "$FAILED" -eq 0 ]
}
