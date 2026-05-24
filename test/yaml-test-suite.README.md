# Vendored YAML Test Suite

Source: <https://github.com/yaml/yaml-test-suite>

Pinned tag: `data-2022-01-17`

Pinned commit: `6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f`

License: MIT, copied in `test/yaml-test-suite.LICENSE`.

This directory contains the released generated data layout. Each test directory
may include:

- `in.yaml`: YAML input
- `test.event`: expected parser event stream in yaml-test-suite notation
- `in.json`: equivalent loaded JSON, when available
- `out.yaml`: canonical emitted YAML, when available
- `error`: marker for inputs that should fail
- `===`: short test label

We will use this suite as the external compatibility target, while keeping
`src/lib/events.awk` responsible for awkyaml's own normalized event stream.
