#!/bin/bash
set -e

# Usage: ./run_all.sh [POLICY]
# POLICY defaults to 0 (FCFS)

POLICY="${1:-0}"

IN_DIR="sample_input"
OUT_DIR="output"
COMBINED="$OUT_DIR/all_policy_${POLICY}.txt"

# Build
make -C libscheduler
make

# Ensure output dir exists
mkdir -p "$OUT_DIR"

# Truncate combined file
: > "$COMBINED"

echo "Running all inputs with policy $POLICY..."

for i in $(seq 0 11); do
  in="$IN_DIR/input_${i}"

  if [ ! -f "$in" ]; then
    echo ">> Skipping missing $in"
    {
      echo "===== BEGIN input_${i} (policy $POLICY) ====="
      echo "<missing: $in>"
      echo "===== END input_${i} (policy $POLICY) ====="
      echo
    } >> "$COMBINED"
    continue
  fi

  echo ">> Running $in"
  ./tester "$POLICY" "$in" >/dev/null

  gantt="$OUT_DIR/gantt-$POLICY-$(basename "$in")"

  {
    echo "===== BEGIN input_${i} (policy $POLICY) ====="
    if [ -f "$gantt" ]; then
      cat "$gantt"
    else
      echo "<missing gantt: $gantt>"
    fi
    echo "===== END input_${i} (policy $POLICY) ====="
    echo
  } >> "$COMBINED"
done

echo "Done. Combined Gantt: $COMBINED"
