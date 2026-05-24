#!/bin/sh
set -eu

awk_bin=$1
parser_bin=$2
kv_bin=$3
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/awkyaml-kv.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

passed=0
failed=0

run_kv_case() {
    name=$1
    input=$2
    expected=$3
    kv_args=${4-}

    printf '%b' "$input" > "$tmp_dir/in.yaml"
    printf '%b' "$expected" > "$tmp_dir/expected.kv"

    if "$awk_bin" -f "$parser_bin" "$tmp_dir/in.yaml" |
        "$awk_bin" $kv_args -f "$kv_bin" > "$tmp_dir/actual.kv" &&
        diff -u "$tmp_dir/expected.kv" "$tmp_dir/actual.kv"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        echo "kv failed: $name" >&2
    fi
}

run_kv_case \
    "root map scalars with prefix" \
    'title: Hello World\ndraft: false\nempty:\n' \
    "page_title='Hello World'\npage_draft='false'\npage_empty=''\n" \
    '-v prefix=page'

run_kv_case \
    "nested maps and sequence lengths" \
    'tags: [awk, yaml]\nauthor:\n  name: Gaz\n' \
    "page_tags_0='awk'\npage_tags_1='yaml'\npage_tags__len='2'\npage_author_name='Gaz'\n" \
    '-v prefix=page'

run_kv_case \
    "root sequence without prefix" \
    '- one\n- two\n' \
    "_0='one'\n_1='two'\n_len='2'\n"

run_kv_case \
    "path escaping and shell quoting" \
    "\"a/b\": \"it's ok\"\nspace key: \"x\\\\ny\"\n" \
    "page_a_b='it'\\\\''s ok'\npage_space_key='x\ny'\n" \
    '-v prefix=page'

run_kv_case \
    "scalar alias" \
    'name: &name Ada\ncopy: *name\n' \
    "page_name='Ada'\npage_copy='Ada'\n" \
    '-v prefix=page'

run_kv_case \
    "container alias" \
    'items: &items [1, 2]\ncopy: *items\n' \
    "page_items_0='1'\npage_items_1='2'\npage_items__len='2'\npage_copy_0='1'\npage_copy_1='2'\npage_copy__len='2'\n" \
    '-v prefix=page'

run_kv_case \
    "first document only" \
    '---\na: 1\n---\nb: 2\n' \
    "page_a='1'\n" \
    '-v prefix=page'

echo "kv: $passed passed, $failed failed"
test "$failed" -eq 0
