#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for figure in 1 2 3 4; do
    julia --project=. "manuscript/figure${figure}.jl"
done

printf 'Publication PDFs and PNGs written to manuscript/figures/\n'
