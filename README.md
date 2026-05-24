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

The current event format intentionally addresses values by path. That keeps
downstream emitters simple, but it cannot honestly represent YAML mappings whose
keys are sequences or mappings. Those upstream fixtures are tracked separately
in `test/parse-unsupported.txt` until the event model grows a non-path
representation for complex keys.

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

awkyaml targets a JSON-compatible YAML profile for configuration and static-site
data. YAML features that map cleanly to JSON-like data are in scope:

- scalar string mapping keys
- block and flow mappings/sequences
- quoted, plain, and block scalar values
- anchors and aliases for values
- tags in the event stream, even if downstream emitters ignore them
- multi-document streams

Complex mapping keys are out of scope for the current event model. YAML permits
sequences and mappings as keys, but JSON, shell variables, and Liquid-style data
models do not. awkyaml therefore treats those upstream suite cases as explicitly
unsupported instead of adding a structural event model that downstream emitters
cannot use.

Shell assignments, JSON output, and Liquid-style data loading are output
emitters layered on top of the event stream; this repository is currently the
parser and event-stream core.

## Tests

`make test` currently runs four layers:

- event round-trip tests for awkyaml's TSV event format
- metadata checks for the vendored `yaml/yaml-test-suite` data snapshot
- an unsupported-fixture manifest check for upstream event streams that cannot
  be represented by the current path-based event model
- parser comparisons for the IDs listed in `test/parse-core.txt`

The parser comparison converts upstream `test.event` files into awkyaml TSV
events with `src/yaml_suite_events.awk`, parses the matching `in.yaml` with
`src/yaml_parse.awk`, then diffs the two normalized streams.

Add new upstream suite IDs to `test/parse-core.txt` as parser coverage expands.
If an upstream event stream is not representable yet, list it in
`test/parse-unsupported.txt`; the harness verifies that this skipped set is
explicit and does not change silently.
