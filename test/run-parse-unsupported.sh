#!/bin/sh
set -eu

awk_bin=$1
suite_dir=test/yaml-test-suite
unsupported_file=test/parse-unsupported.txt
tmp_actual=$(mktemp "${TMPDIR:-/tmp}/awkyaml-unsupported-actual.XXXXXX")
tmp_expected=$(mktemp "${TMPDIR:-/tmp}/awkyaml-unsupported-expected.XXXXXX")
tmp_out=$(mktemp "${TMPDIR:-/tmp}/awkyaml-unsupported-out.XXXXXX")
trap 'rm -f "$tmp_actual" "$tmp_expected" "$tmp_out"' EXIT HUP INT TERM

find "$suite_dir" -name in.yaml | sort | while IFS= read -r in_yaml; do
    test_dir=${in_yaml%/in.yaml}
    test_id=${test_dir#"$suite_dir"/}
    test -f "$test_dir/test.event" || continue

    if ! "$awk_bin" -f src/lib/events.awk -f src/yaml_suite_events.awk \
        "$test_dir/test.event" > "$tmp_out" 2>/dev/null; then
        printf '%s\n' "$test_id"
    fi
done | sort > "$tmp_actual"

sort "$unsupported_file" > "$tmp_expected"

if diff -u "$tmp_expected" "$tmp_actual"; then
    count=$(wc -l < "$tmp_actual" | tr -d ' ')
    echo "parse unsupported: $count expected not normalized"
else
    echo "parse unsupported list changed" >&2
    exit 1
fi
