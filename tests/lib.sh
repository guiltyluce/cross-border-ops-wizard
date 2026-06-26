#!/usr/bin/env bash
# Minimal zero-dependency assert harness.
TESTS_RUN=0; TESTS_FAILED=0
_fail(){ TESTS_FAILED=$((TESTS_FAILED+1)); printf 'FAIL: %s\n' "$1" >&2; }
assert_eq(){ TESTS_RUN=$((TESTS_RUN+1)); [ "$2" = "$3" ] || _fail "$1: expected [$3] got [$2]"; }
assert_contains(){ TESTS_RUN=$((TESTS_RUN+1)); case "$2" in *"$3"*) ;; *) _fail "$1: [$2] does not contain [$3]";; esac; }
assert_not_contains(){ TESTS_RUN=$((TESTS_RUN+1)); case "$2" in *"$3"*) _fail "$1: [$2] unexpectedly contains [$3]";; esac; }
assert_status(){ TESTS_RUN=$((TESTS_RUN+1)); [ "$2" = "$3" ] || _fail "$1: expected exit [$3] got [$2]"; }
finish(){ printf '%s run, %s failed\n' "$TESTS_RUN" "$TESTS_FAILED"; [ "$TESTS_FAILED" -eq 0 ]; }
