#!/bin/sh
set -eu

awk_bin=$1
suite_dir=test/yaml-test-suite
tier_file=test/suite-core.txt
passed=0
failed=0

while IFS= read -r test_id; do
    case $test_id in
        ''|'#'*) continue ;;
    esac

    event_file=$suite_dir/$test_id/test.event
    if test -f "$event_file" &&
        "$awk_bin" -f src/lib/events.awk -f src/yaml_suite_events.awk "$event_file" >/dev/null; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        echo "suite event conversion failed: $test_id" >&2
    fi
done < "$tier_file"

echo "suite events: $passed passed, $failed failed"
test "$failed" -eq 0
