AWK ?= awk

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN { FS = ":.*## " } /^[A-Za-z0-9_.-]+:.*## / { printf "%-24s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: test
test: events-test regressions-test json-test suite-metadata-test suite-events-test parse-unsupported-test parse-progress parse-suite-test ## Run the full test suite.

.PHONY: events-test
events-test: ## Round-trip the TSV event format.
	test/run-events.sh "$(AWK)"

.PHONY: regressions-test
regressions-test: ## Run the regression fixtures.
	sh test/run-regressions.sh "$(AWK)"

.PHONY: json-test
json-test: ## Check the events-to-JSON emitter.
	sh test/run-json.sh "$(AWK)"

.PHONY: suite-metadata-test
suite-metadata-test: ## Sanity-check the vendored yaml-test-suite snapshot.
	test/run-suite-metadata.sh

.PHONY: suite-events-test
suite-events-test: ## Convert upstream test.event streams to TSV events.
	test/run-suite-events.sh "$(AWK)"

.PHONY: parse-suite-test
parse-suite-test: ## Diff parser output against the suite (parse-core.txt).
	test/run-parse-suite.sh "$(AWK)"

.PHONY: parse-unsupported-test
parse-unsupported-test: ## Verify the unsupported-fixture manifest is stable.
	test/run-parse-unsupported.sh "$(AWK)"

.PHONY: parse-progress
parse-progress: ## Report parser pass rate across convertible fixtures.
	test/run-parse-progress.sh "$(AWK)"

.PHONY: clean
clean: ## Remove generated build artifacts.
	rm -rf build
