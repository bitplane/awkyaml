AWK ?= awk

.PHONY: test
test: events-test suite-metadata-test

.PHONY: events-test
events-test:
	test/run-events.sh "$(AWK)"

.PHONY: suite-metadata-test
suite-metadata-test:
	test/run-suite-metadata.sh

.PHONY: clean
clean:
	rm -rf build
