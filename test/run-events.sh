#!/bin/sh
set -eu

awk_bin=$1

tmp=${TMPDIR:-/tmp}/awkyaml-events.$$
trap 'rm -f "$tmp"' EXIT HUP INT TERM

"$awk_bin" -f src/yaml_events.awk -f test/roundtrip-events.awk \
    test/events/basic.events > "$tmp"

cmp -s test/events/basic.events "$tmp"
