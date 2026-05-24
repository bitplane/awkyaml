#!/bin/sh
set -eu

parser_bin=$1
json_bin=$2
suite_dir=test/yaml-test-suite
tier_file=test/parse-core.txt
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/awkyaml-json-suite.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

if ! command -v jq >/dev/null 2>&1; then
    echo "json suite requires jq" >&2
    exit 1
fi

passed=0
failed=0
skipped=0
total=0

while IFS= read -r test_id; do
    case $test_id in
        ''|'#'*) continue ;;
    esac
    test_dir=$suite_dir/$test_id
    test -f "$test_dir/in.json" || continue
    if ! grep '^-DOC' "$test_dir/test.event" >/dev/null 2>&1; then
        skipped=$((skipped + 1))
        continue
    fi

    total=$((total + 1))
    if jq -cS . "$test_dir/in.json" > "$tmp_dir/expected.json" &&
        "$parser_bin" "$test_dir/in.yaml" |
        "$json_bin" |
        jq -cS . > "$tmp_dir/actual.json" &&
        diff -u "$tmp_dir/expected.json" "$tmp_dir/actual.json"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        echo "json suite failed: $test_id" >&2
    fi
done < "$tier_file"

echo "json suite: $passed passed, $failed failed, $skipped skipped, $total total"
test "$failed" -eq 0
