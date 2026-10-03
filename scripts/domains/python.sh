#!/usr/bin/env bash
# `domains` detector for Python (SPEC scripts:T27, I.cmd `domains`).
#
# uv.lock or any requirements*.txt means PyPI: its index (pypi.org) and
# its download host (files.pythonhosted.org). Every other URL in those
# files is an index, a mirror or a direct dependency, so its host counts.
#
# Usage: python.sh PROJECT_DIR   -> `host<TAB>file` lines

set -euo pipefail

dir="${1:?usage: python.sh PROJECT_DIR}"
hosts="$(dirname "${BASH_SOURCE[0]}")/hosts.sh"

files=()
for path in "$dir/uv.lock" "$dir"/requirements*.txt; do
    [ -f "$path" ] && files+=("${path#"$dir"/}")
done
[ "${#files[@]}" -gt 0 ] || exit 0

printf '%s\t%s\n' pypi.org "${files[0]}" files.pythonhosted.org "${files[0]}"
for file in "${files[@]}"; do
    bash "$hosts" "$file" <"$dir/$file"
done
