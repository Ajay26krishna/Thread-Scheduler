#!/usr/bin/env bash
set -euo pipefail

EXE=./tester
IN_DIR=sample_input
OUT_DIR=gdb_logs
mkdir -p "$OUT_DIR"

# policies: 0=FCFS, 1=SRTF, 2=MLFQ
policies=(0 1 2)
inputs=(input_0 input_1 input_2 input_3 input_4 input_5 input_6 input_7 input_8 input_9 input_10 input_11)

# Optional restrict: ./run_all_gdb.sh 0  (all inputs for policy 0)
# Or:                ./run_all_gdb.sh 0 input_8
if [[ $# -ge 1 ]]; then
  policies=("$1")
fi
if [[ $# -ge 2 ]]; then
  inputs=("$2")
fi

# aggregate log
ALL_LOG="$OUT_DIR/gdb_all.log"
: > "$ALL_LOG"   # truncate

run_one () {
  local policy="$1"
  local in="$2"
  local in_path="$IN_DIR/$in"
  local log="$OUT_DIR/gdb_policy${policy}_${in}.log"
  local cmd="/tmp/gdb_cmd_${policy}_${in}_$$.gdb"

  # we overwrite the per-case file; we append to ALL_LOG
  : > "$log"

  # create the gdb command file
  cat > "$cmd" <<'GDB'
set pagination off
set print pretty on
set confirm off
set breakpoint pending on
set verbose off

# Load program & pass args
file __EXE__
set args __POLICY__ __INPUT__

# Logging to the per-case log file
set logging file __LOG__
set logging redirect on
set logging overwrite on
set logging on

# Header (values substituted by sed as string literals)
echo
echo "================== RUN START =================="
echo "policy=__POLICY_S__"
echo "input=__INPUT_S__"
echo "datetime="
shell date -u +"%Y-%m-%dT%H:%M:%SZ"
echo "==============================================="

# ---- pretty printer for scheduler state ----
define pr
  echo
  echo "=== SCHED STATE ==="
  printf "t_time=%d inst_tick=%d inst_pending=%d cpu_owner=%d policy=%d\n", t_time, inst_tick, inst_pending, cpu_owner, policy
  printf "ready.size=%d io.size=%d io_busy_until=%d\n", queue.size, io_q.size, io_busy_until
  set $i=0
  while $i < thread_count
    printf " tid=%d state=%d rem=%d atick=%d akey=%f lvl=%d q=%d wake=%d\n", \
      tcb[$i].tid, tcb[$i].state, tcb[$i].rem, \
      tcb[$i].arrival_tick, tcb[$i].arrival_key, \
      tcb[$i].mlfq_level, tcb[$i].q_budget, tcb[$i].wake
    set $i=$i+1
  end
  echo "====================="
end

# Breakpoints (file:func or file:line so they're unambiguous)
break init.c:init_scheduler
commands
  silent
  echo
  echo "== init_scheduler() =="
  pr
  continue
end

# This may or may not exist; harmless with 'pending on'
break interface.c:try_schedule_if_idle_locked
commands
  silent
  echo
  echo "== try_schedule_if_idle_locked() =="
  pr
  continue
end

break interface.c:schedule_if_idle_locked_blocking
commands
  silent
  echo
  echo "== schedule_if_idle_locked_blocking() =="
  pr
  continue
end

break interface.c:cpu_me
commands
  silent
  echo
  echo ">> cpu_me() enter <<"
  pr
  continue
end

break interface.c:io_me
commands
  silent
  echo
  echo ">> io_me() enter <<"
  pr
  continue
end

break interface.c:P
commands
  silent
  echo
  echo ">> P() enter <<"
  pr
  continue
end

break interface.c:V
commands
  silent
  echo
  echo ">> V() enter <<"
  pr
  continue
end

break init.c:finish_scheduler
commands
  silent
  echo
  echo "== finish_scheduler() =="
  pr
  continue
end

# Run it
run

echo
echo "== program exited =="
pr
echo "=================== RUN END ==================="

set logging off
quit
GDB

  # Substitute placeholders.
  # NOTE: __INPUT_S__ is a quoted string version to avoid GDB interpreting 'input'
  sed -i \
    -e "s|__LOG__|$log|g" \
    -e "s|__EXE__|$EXE|g" \
    -e "s|__POLICY__|$policy|g" \
    -e "s|__INPUT__|$in_path|g" \
    -e "s|__POLICY_S__|$policy|g" \
    -e "s|__INPUT_S__|$in_path|g" \
    "$cmd"

  echo "== Running policy $policy, $in (log: $log) =="

  # Batch run. We do NOT pass --args; the .gdb file already set them.
  if ! gdb -q -batch -x "$cmd" ; then
    echo "[WARN] gdb reported non-zero exit for policy $policy, $in" | tee -a "$ALL_LOG"
  fi

  # Append into the aggregate log in a clearly delimited way
  {
    echo
    echo "########## BEGIN policy=$policy input=$in ##########"
    cat "$log"
    echo "########### END policy=$policy input=$in ###########"
    echo
  } >> "$ALL_LOG"

  rm -f "$cmd"
}

for p in "${policies[@]}"; do
  for in in "${inputs[@]}"; do
    run_one "$p" "$in"
  done
done

echo "All done. Logs in $OUT_DIR/"
echo "Aggregate log at: $ALL_LOG"
