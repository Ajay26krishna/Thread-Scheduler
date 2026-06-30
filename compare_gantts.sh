#!/usr/bin/env bash
set -euo pipefail

# Directories
SAMPLE_DIR="sample_output"
RUN_DIR="output"
REPORT="comparison_report.txt"

# Range
POLICIES=(0 1 2)
INPUTS=$(seq 0 11)

# Make a temp workspace
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

normalize_and_sort() {
  # Usage: normalize_and_sort <infile> <outfile>
  # - drop BEGIN/END banners
  # - trim leading spaces and squeeze internal spaces
  # - drop blank lines
  # - sort so printing order doesn't matter
  local in="$1" out="$2"
  sed -e '/^===== BEGIN/d' -e '/^===== END/d' "$in" \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+/ /g' \
  | grep -v '^[[:space:]]*$' \
  | LC_ALL=C sort > "$out"
}

echo "# Gantt Comparison Report" > "$REPORT"
echo "# sample: $SAMPLE_DIR  vs  run: $RUN_DIR" >> "$REPORT"
echo "# Order-insensitive (lines normalized & sorted), side-by-side diffs shown when different." >> "$REPORT"
echo >> "$REPORT"

matched=0
total=0
missing_any=0

for p in "${POLICIES[@]}"; do
  for i in $INPUTS; do
    total=$((total+1))
    base="gantt-$p-input_$i"
    sample_file="$SAMPLE_DIR/$base"
    run_file="$RUN_DIR/$base"

    if [[ ! -f "$sample_file" || ! -f "$run_file" ]]; then
      echo "## policy $p, input $i : MISSING FILE(S)" >> "$REPORT"
      [[ ! -f "$sample_file" ]] && echo " - missing: $sample_file" >> "$REPORT"
      [[ ! -f "$run_file"    ]] && echo " - missing: $run_file" >> "$REPORT"
      echo >> "$REPORT"
      missing_any=$((missing_any+1))
      continue
    fi

    s_norm="$TMPDIR/sample-p${p}-i${i}.txt"
    r_norm="$TMPDIR/run-p${p}-i${i}.txt"
    normalize_and_sort "$sample_file" "$s_norm"
    normalize_and_sort "$run_file"    "$r_norm"

    if cmp -s "$s_norm" "$r_norm"; then
      echo "## policy $p, input $i : MATCH" >> "$REPORT"
      matched=$((matched+1))
    else
      echo "## policy $p, input $i : DIFF" >> "$REPORT"
      echo "SAMPLE: $sample_file    |    RUN: $run_file" >> "$REPORT"
      # side-by-side view of normalized lines; show all lines for clear context
      diff -y --width=180 "$s_norm" "$r_norm" >> "$REPORT" || true
    fi
    echo >> "$REPORT"
  done
done

echo "==== SUMMARY ====" >> "$REPORT"
echo "Matched: $matched / $total" >> "$REPORT"
echo "Missing file pairs: $missing_any" >> "$REPORT"
echo >> "$REPORT"
echo "Report written to: $REPORT"
