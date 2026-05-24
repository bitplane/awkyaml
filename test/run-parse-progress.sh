#!/bin/sh
set -eu

awk_bin=$1
parser_bin=$2
suite_dir=test/yaml-test-suite
tmp_expected=$(mktemp "${TMPDIR:-/tmp}/awkyaml-progress-expected.XXXXXX")
tmp_actual=$(mktemp "${TMPDIR:-/tmp}/awkyaml-progress-actual.XXXXXX")
tmp_list=$(mktemp "${TMPDIR:-/tmp}/awkyaml-progress-list.XXXXXX")
trap 'rm -f "$tmp_expected" "$tmp_actual" "$tmp_list"' EXIT HUP INT TERM

total=0
convertible=0
normalizer_failed=0
passed=0
failed=0

find "$suite_dir" -name in.yaml | sort > "$tmp_list"

while IFS= read -r in_yaml; do
    test_dir=${in_yaml%/in.yaml}
    test -f "$test_dir/test.event" || continue

    total=$((total + 1))
    if "$awk_bin" -f src/lib/events.awk -f src/yaml_suite_events.awk \
        "$test_dir/test.event" > "$tmp_expected" 2>/dev/null; then
        convertible=$((convertible + 1))
    else
        normalizer_failed=$((normalizer_failed + 1))
        continue
    fi

    "$awk_bin" -f "$parser_bin" "$in_yaml" > "$tmp_actual" 2>/dev/null || true

    if cmp -s "$tmp_expected" "$tmp_actual"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
done < "$tmp_list"

if test "$convertible" -gt 0; then
    percent=$((passed * 100 / convertible))
else
    percent=0
fi

echo "parse progress: $passed/$convertible convertible passed (${percent}%), $failed failed, $normalizer_failed not normalized, $total total"
