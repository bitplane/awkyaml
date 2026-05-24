#!/bin/sh
set -eu

awk_bin=$1

tmp=$(mktemp "${TMPDIR:-/tmp}/awkyaml-events.XXXXXX")
trap 'rm -f "$tmp"' EXIT HUP INT TERM

"$awk_bin" -f src/lib/events.awk -f test/roundtrip-events.awk \
    test/events/basic.events > "$tmp"

if cmp -s test/events/basic.events "$tmp"; then
    echo "events: 1 passed, 0 failed"
else
    echo "events: 0 passed, 1 failed" >&2
    exit 1
fi
