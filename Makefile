AWK ?= awk

.PHONY: test
test: events-test suite-metadata-test suite-events-test parse-suite-test

.PHONY: events-test
events-test:
	test/run-events.sh "$(AWK)"

.PHONY: suite-metadata-test
suite-metadata-test:
	test/run-suite-metadata.sh

.PHONY: suite-events-test
suite-events-test:
	test/run-suite-events.sh "$(AWK)"

.PHONY: parse-suite-test
parse-suite-test:
	test/run-parse-suite.sh "$(AWK)"

.PHONY: clean
clean:
	rm -rf build
