#!/bin/sh
set -eu

parser_bin=$1
json_bin=$2
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/awkyaml-json.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

passed=0
failed=0

run_json_case() {
    name=$1
    input=$2
    expected=$3

    printf '%b' "$input" > "$tmp_dir/in.yaml"
    printf '%s\n' "$expected" > "$tmp_dir/expected.json"

    if "$parser_bin" "$tmp_dir/in.yaml" |
        "$json_bin" > "$tmp_dir/actual.json" &&
        diff -u "$tmp_dir/expected.json" "$tmp_dir/actual.json"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        echo "json failed: $name" >&2
    fi
}

run_json_case \
    "root map scalars" \
    'title: Hello\ncount: 2\nenabled: true\nempty:\n' \
    '{"title":"Hello","count":2,"enabled":true,"empty":null}'

run_json_case \
    "nested sequence and maps" \
    '- name: Mark\n  hr: 65\n- name: Sammy\n  hr: 63\n' \
    '[{"name":"Mark","hr":65},{"name":"Sammy","hr":63}]'

run_json_case \
    "flow collections" \
    'items: [1, two, {three: 4}]\n' \
    '{"items":[1,"two",{"three":4}]}'

run_json_case \
    "block and quoted strings" \
    'literal: |\n  a\n  b\nquoted: "a\\nb"\n' \
    '{"literal":"a\nb\n","quoted":"a\nb"}'

run_json_case \
    "scalar alias" \
    'name: &name Ada\ncopy: *name\n' \
    '{"name":"Ada","copy":"Ada"}'

run_json_case \
    "container alias" \
    'items: &items [1, 2]\ncopy: *items\n' \
    '{"items":[1,2],"copy":[1,2]}'

echo "json: $passed passed, $failed failed"
test "$failed" -eq 0
