#!/bin/bash
SCRIPT_DIR="$HOME/.local/bin/TED3+/"

for dir in /tmp/.ted3_instance.*/; do
    [ -d "$dir" ] || continue
    OLPID=$(cat "${dir}pid" 2>/dev/null)
    [ -z "$OLPID" ] && continue
    if kill -0 "$OLPID" 2>/dev/null; then
        for f in "$@"; do
            if [ -f "$f" ]; then
                echo "$f" > "${dir}open_$(date +%s%N).tmp"
            fi
        done
        exit 0
    fi
done

cd "$SCRIPT_DIR"
exec wish "./main-core-3_6_0.tcl" "$@"
