#!/bin/sh
set -eu

suite_dir=test/yaml-test-suite

test -d "$suite_dir"
test -f test/yaml-test-suite.README.md
test -f test/yaml-test-suite.LICENSE

in_yaml_count=$(find "$suite_dir" -name in.yaml | wc -l)
event_count=$(find "$suite_dir" -name test.event | wc -l)

test "$in_yaml_count" -gt 0
test "$event_count" -eq "$in_yaml_count"

echo "suite metadata: $in_yaml_count in.yaml, $event_count test.event"
