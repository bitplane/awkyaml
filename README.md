# awkyaml

A POSIX awk YAML parser project.

The first milestone is not YAML syntax parsing. It is a stable, testable event
stream format that later parser, resolver, JSON emitter, and shell-variable
emitter components can share.

## Event Format

Events are tab-separated records. Text fields use backslash escapes so records
remain one physical line:

- `\\` backslash
- `\t` tab
- `\n` newline
- `\r` carriage return
- `\/` slash inside a path segment

Paths are slash-separated. The root path is the empty string. Sequence indexes
are decimal path segments.

```text
DOC_START<TAB>doc_id
DOC_END<TAB>doc_id
MAP_START<TAB>doc_id<TAB>path<TAB>tag<TAB>anchor
MAP_END<TAB>doc_id<TAB>path
SEQ_START<TAB>doc_id<TAB>path<TAB>tag<TAB>anchor
SEQ_END<TAB>doc_id<TAB>path
SCALAR<TAB>doc_id<TAB>path<TAB>tag<TAB>anchor<TAB>style<TAB>value
ALIAS<TAB>doc_id<TAB>path<TAB>anchor_name
```

Example:

```text
DOC_START	0
MAP_START	0		!!map	
SCALAR	0	title	!!str		plain	Hello
SEQ_START	0	tags	!!seq	
SCALAR	0	tags/0	!!str		plain	awk
SCALAR	0	tags/1	!!str		plain	yaml
SEQ_END	0	tags
MAP_END	0	
DOC_END	0
```

## Scope

The parser should eventually target YAML as a real data language, including
flow collections, anchors, aliases, tags, block scalars, and multi-document
streams. Shell assignments are an output emitter, not the internal model.

## Tests

`make test` currently runs three layers:

- event round-trip tests for awkyaml's TSV event format
- metadata checks for the vendored `yaml/yaml-test-suite` data snapshot
- parser comparisons for the IDs listed in `test/parse-core.txt`

The parser comparison converts upstream `test.event` files into awkyaml TSV
events with `src/yaml_suite_events.awk`, parses the matching `in.yaml` with
`src/yaml_parse.awk`, then diffs the two normalized streams.

Add new upstream suite IDs to `test/parse-core.txt` as parser coverage expands.
