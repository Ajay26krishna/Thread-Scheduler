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

# ---- detect whether debug symbols expose our globals ----
set $HAVE_SYMS = 0
python
import gdb
try:
    # Try to look up one of your globals
    gdb.lookup_global_symbol("t_time").value()
    gdb.execute("set $HAVE_SYMS = 1")
except Exception:
    gdb.execute("set $HAVE_SYMS = 0")
end

# ---- pretty printer for scheduler state ----
define pr
  if $HAVE_SYMS
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
  else
    echo
    echo "(no debug symbols visible; skipping state dump)"
  end
end

# Breakpoints (ok to be pending when no symbols)
break init.c:init_scheduler
commands
  silent
  echo
  echo "== init_scheduler() =="
  pr
  continue
end

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
