AWK ?= awk

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN { FS = ":.*## " } /^[A-Za-z0-9_.-]+:.*## / { printf "%-24s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: test
test: build lib-purity-test events-test regressions-test json-test json-suite-test suite-metadata-test suite-events-test parse-unsupported-test parse-progress parse-suite-test ## Run the full test suite.

.PHONY: events-test
events-test: ## Round-trip the TSV event format.
	test/run-events.sh "$(AWK)"

.PHONY: lib-purity-test
lib-purity-test: ## Verify src/lib contains functions only.
	sh test/run-lib-purity.sh

.PHONY: regressions-test
regressions-test: ## Run the regression fixtures.
	sh test/run-regressions.sh "$(AWK)" build/awkyaml

.PHONY: json-test
json-test: ## Check the events-to-JSON emitter.
	sh test/run-json.sh "$(AWK)" build/awkyaml build/awkyaml-json

.PHONY: json-suite-test
json-suite-test: ## Compare JSON output against upstream in.json fixtures.
	sh test/run-json-suite.sh "$(AWK)" build/awkyaml build/awkyaml-json

.PHONY: suite-metadata-test
suite-metadata-test: ## Sanity-check the vendored yaml-test-suite snapshot.
	test/run-suite-metadata.sh

.PHONY: suite-events-test
suite-events-test: ## Convert upstream test.event streams to TSV events.
	test/run-suite-events.sh "$(AWK)"

.PHONY: parse-suite-test
parse-suite-test: ## Diff parser output against the suite (parse-core.txt).
	test/run-parse-suite.sh "$(AWK)" build/awkyaml

.PHONY: parse-unsupported-test
parse-unsupported-test: ## Verify the unsupported-fixture manifest is stable.
	test/run-parse-unsupported.sh "$(AWK)"

.PHONY: parse-progress
parse-progress: ## Report parser pass rate across convertible fixtures.
	test/run-parse-progress.sh "$(AWK)" build/awkyaml

.PHONY: clean
clean: ## Remove generated build artifacts.
	rm -rf build

EVENTS = src/lib/events.awk
PARSER_LIBS = src/lib/parse-core.awk src/lib/parse-scalar.awk src/lib/parse-block-scalar.awk src/lib/parse-flow.awk src/lib/parse-line.awk
AWKYAML_SRCS = $(EVENTS) $(PARSER_LIBS) src/main/awkyaml.awk
AWKYAML_JSON_SRCS = $(EVENTS) src/lib/json.awk src/main/awkyaml-json.awk

.PHONY: build
build: build/awkyaml build/awkyaml-json ## Build single-file awk tools into build/.

build/awkyaml: $(AWKYAML_SRCS) scripts/bundle.sh
	@mkdir -p build
	@scripts/bundle.sh $@ $(AWKYAML_SRCS)

build/awkyaml-json: $(AWKYAML_JSON_SRCS) scripts/bundle.sh
	@mkdir -p build
	@scripts/bundle.sh $@ $(AWKYAML_JSON_SRCS)
