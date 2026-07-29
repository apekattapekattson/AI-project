#!/usr/bin/env bash
# Runs every spec. Usage: ./tests/run_all.sh   (from repo root)
set -u
cd "$(dirname "$0")/.."
fail=0
for spec in tests/*.spec.lua; do
  echo "── $spec"
  if ! lua5.4 "$spec"; then fail=1; fi
  echo
done
if [ "$fail" -eq 0 ]; then echo "ALL SUITES PASSED"; else echo "SUITE FAILURES"; fi
exit $fail
