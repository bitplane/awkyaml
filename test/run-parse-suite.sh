#!/bin/sh
set -eu

awk_bin=$1
parser_bin=$2
suite_dir=test/yaml-test-suite
tier_file=test/parse-core.txt
tmp_expected=$(mktemp "${TMPDIR:-/tmp}/awkyaml-expected.XXXXXX")
tmp_actual=$(mktemp "${TMPDIR:-/tmp}/awkyaml-actual.XXXXXX")
trap 'rm -f "$tmp_expected" "$tmp_actual"' EXIT HUP INT TERM
passed=0
failed=0

while IFS= read -r test_id; do
    case $test_id in
        ''|'#'*) continue ;;
    esac

    "$awk_bin" -f src/lib/events.awk -f src/yaml_suite_events.awk \
        "$suite_dir/$test_id/test.event" > "$tmp_expected"
    "$parser_bin" "$suite_dir/$test_id/in.yaml" > "$tmp_actual"

    if diff -u "$tmp_expected" "$tmp_actual"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        echo "parse suite failed: $test_id" >&2
    fi
done < "$tier_file"

echo "parse suite: $passed passed, $failed failed"
test "$failed" -eq 0
