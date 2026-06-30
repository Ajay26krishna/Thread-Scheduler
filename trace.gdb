set pagination off
set print thread-events off
set breakpoint pending on
set confirm off
set demangle-style gnu-v3
set logging file trace.log
set logging overwrite on
set logging on

# Try to catch your “settle” phase (events processed at time t)
rbreak .*settle.*|.*handle.*tick.*|.*process.*events.*|.*advance.*time.*
commands
silent
# try common names for current time variable — tweak as needed
if $_exists("t")
  printf "TICK %d: settle_start\n", t
else
  if $_exists("now") 
    printf "TICK %d: settle_start\n", now
  else
    printf "TICK ?: settle_start\n"
  end
end
continue
end

# Enqueue to READY
rbreak .*enqueue.*ready.*|.*rq.*push.*|.*ready.*push.*
commands
silent
# Adapt these field names to yours once you see one hit:
printf "ENQ_READY T%d (metric=%d, rq_seq=%lld, level=%d, rem=%d)\n", \
       tid, metric, rq_seq, level, rem
continue
end

# Pick decision
rbreak .*pick.*owner.*|.*choose.*next.*|.*schedule.*pick.*
commands
silent
# If your code has a reason string/enum, print it; else print owner only
printf "PICK owner=T%d\n", $return
continue
end

# Per-slice execution
rbreak .*run.*slice.*|.*execute.*tick.*|.*cpu.*step.*
commands
silent
# Guess t variable; adjust once you see a hit
if $_exists("t") && $_exists("owner")
  printf "SLICE T%d ran [%d, %d)\n", owner, t, t+1
else
  printf "SLICE (owner=?, t=?)\n"
end
continue
end

# CPU burst finished ? I/O scheduling
rbreak .*cpu.*done.*|.*finish.*cpu.*burst.*|.*start.*io.*
commands
silent
# Best-effort; adjust once you see locals
printf "CPU_DONE T? -> IO start=?, finish=?\n"
continue
end

# I/O device actually starts
rbreak .*io.*start.*|.*IO_START.*
commands
silent
printf "IO_START T? at ? from head=(?, ?, ?)\n"
continue
end
