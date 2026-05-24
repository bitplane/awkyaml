#!/bin/sh
set -eu

out=$1
shift

{
    printf '%s\n' '#!/usr/bin/awk -f'
    cat "$@"
} > "$out.tmp"
chmod +x "$out.tmp"
mv "$out.tmp" "$out"
