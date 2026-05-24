#!/bin/sh
set -eu

awk_bin=$1
parser_bin=$2
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/awkyaml-regressions.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

passed=0
failed=0

run_case() {
    name=$1
    input=$2
    expected=$3

    printf '%b' "$input" > "$tmp_dir/in.yaml"
    printf '%b' "$expected" > "$tmp_dir/expected.events"

    if "$awk_bin" -f "$parser_bin" "$tmp_dir/in.yaml" > "$tmp_dir/actual.events" &&
        diff -u "$tmp_dir/expected.events" "$tmp_dir/actual.events"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        echo "regression failed: $name" >&2
    fi
}

run_case \
    "invalid plain scalar mapping continuation" \
    'this\n is\n  invalid: x\n' \
    'DOC_START\t0\n'

run_case \
    "tab before detected block scalar indent errors before dedent" \
    'foo: |\n\t\nbar: 1\n' \
    'DOC_START\t0\nMAP_START\t0\t\ttag:yaml.org,2002:map\t\n'

run_case \
    "document marker closes pending block scalar" \
    'foo: |\n---\nbar: 1\n' \
    'DOC_START\t0\nMAP_START\t0\t\ttag:yaml.org,2002:map\t\nSCALAR\t0\tfoo\ttag:yaml.org,2002:str\t\tliteral\t\nMAP_END\t0\t\nDOC_END\t0\nDOC_START\t1\nMAP_START\t1\t\ttag:yaml.org,2002:map\t\nSCALAR\t1\tbar\ttag:yaml.org,2002:str\t\tplain\t1\nMAP_END\t1\t\nDOC_END\t1\n'

run_case \
    "yaml directive before document start" \
    '%YAML 1.2\n---\nkey: value\n' \
    'DOC_START\t0\nMAP_START\t0\t\ttag:yaml.org,2002:map\t\nSCALAR\t0\tkey\ttag:yaml.org,2002:str\t\tplain\tvalue\nMAP_END\t0\t\nDOC_END\t0\n'

run_case \
    "document start with root scalar" \
    '--- scalar\n' \
    'DOC_START\t0\nSCALAR\t0\t\ttag:yaml.org,2002:str\t\tplain\tscalar\nDOC_END\t0\n'

run_case \
    "pending map key followed by block scalar" \
    'key:\n  |\n    value\n' \
    'DOC_START\t0\nMAP_START\t0\t\ttag:yaml.org,2002:map\t\nSCALAR\t0\tkey\ttag:yaml.org,2002:str\t\tliteral\tvalue\\n\nMAP_END\t0\t\nDOC_END\t0\n'

run_case \
    "pending sequence item followed by quoted scalar" \
    '-\n  "quoted\n  value"\n' \
    'DOC_START\t0\nSEQ_START\t0\t\ttag:yaml.org,2002:seq\t\nSCALAR\t0\t0\ttag:yaml.org,2002:str\t\tdouble\tquoted value\nSEQ_END\t0\t\nDOC_END\t0\n'

run_case \
    "anchors before scalar collection and block values" \
    'plain: &a text\nseq: &s [1, 2]\nblock: &b |\n  text\n' \
    'DOC_START\t0\nMAP_START\t0\t\ttag:yaml.org,2002:map\t\nSCALAR\t0\tplain\ttag:yaml.org,2002:str\ta\tplain\ttext\nSEQ_START\t0\tseq\ttag:yaml.org,2002:seq\ts\nSCALAR\t0\tseq/0\ttag:yaml.org,2002:str\t\tplain\t1\nSCALAR\t0\tseq/1\ttag:yaml.org,2002:str\t\tplain\t2\nSEQ_END\t0\tseq\nSCALAR\t0\tblock\ttag:yaml.org,2002:str\tb\tliteral\ttext\\n\nMAP_END\t0\t\nDOC_END\t0\n'

run_case \
    "unsupported compact complex key reports through one path" \
    '? -\n: value\n' \
    'DOC_START\t0\nSEQ_START\t0\t\ttag:yaml.org,2002:seq\t\nSEQ_START\t0\t0\ttag:yaml.org,2002:seq\t\n'

echo "regressions: $passed passed, $failed failed"
test "$failed" -eq 0
