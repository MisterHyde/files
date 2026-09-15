#!/bin/bash
set -uo pipefail

for z in *.zip; do
    [[ -e "$z" ]] || continue
    dn="${z%.zip}"

    echo "=========================================================="
    echo "$z"

    if [[ -e "$dn" ]]; then
        echo "SKIP: '$dn' already exists"
        continue
    fi

    # Does every entry live under one common top-level directory?
    roots=$(unzip -Z1 "$z" | cut -d/ -f1 | sort -u)
    has_slash=$(unzip -Z1 "$z" | grep -c '/' || true)

	# Zip file contains a folder so removeing it and keep it flat
    if [[ $(wc -l <<<"$roots") -eq 1 && $has_slash -gt 0 ]]; then
        echo "  archive is already wrapped in '$roots' — extracting flat"
        if unzip -q "$z" && [[ -d "$roots" ]]; then
            [[ "$roots" != "$dn" ]] && mv "$roots" "$dn"
            rm "$z"
        else
            echo "  ERROR extracting '$z'"
        fi
	# No folder in zip plain unzip works here
    else
        echo "  extracting into '$dn'"
        if unzip -q "$z" -d "$dn" && [[ -d "$dn" ]]; then
            rm "$z"
        else
            echo "  ERROR extracting '$z'"
        fi
    fi
done
