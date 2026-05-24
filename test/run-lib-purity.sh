#!/bin/sh
set -eu

awk '
function bad(message) {
    print FILENAME ":" FNR ": " message > "/dev/stderr"
    failed = 1
}

{
    line = $0
    stripped = line
    sub(/^[ \t]+/, "", stripped)

    if (depth == 0 && stripped ~ /^function[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/) {
        in_function = 1
    } else if (depth == 0 && stripped ~ /^(BEGIN|END)([ \t]*[{]|[ \t]*$)/) {
        bad("top-level " stripped " in library")
    } else if (depth == 0 && stripped ~ /^[{]/) {
        bad("top-level action block in library")
    } else if (depth == 0 && stripped ~ /^\/.*\/[ \t]*[{]/) {
        bad("top-level pattern action in library")
    }

    opens = gsub(/{/, "{", line)
    closes = gsub(/}/, "}", line)
    depth += opens - closes
    if (depth < 0) {
        depth = 0
    }
    if (depth == 0) {
        in_function = 0
    }
}

END {
    exit failed ? 1 : 0
}
' src/lib/*.awk

echo "lib purity: passed"
