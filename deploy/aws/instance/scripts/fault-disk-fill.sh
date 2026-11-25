#!/bin/bash
# WS-F fault injection: a runaway application log fills the root disk.
#
# Simulates LibreChat file logging (bind-mounted to /opt/filmatch/logs on the root volume)
# growing without a size cap. It appends 256 MiB every 10 s (~1.5 GiB/min), so CloudWatch sees the
# disk climb and the disk-used-high alarm (>85%) fires before the disk hits 100%.
#
#   start    begin the runaway log (runs in the background, stops itself at 100%)
#   status   show disk usage and what is using it (the commands you would use to investigate)
#   cleanup  stop the writer and delete the runaway log
#
# Record the time printed by each command for the website: fault started / alarm / fixed.

set -euo pipefail
LOG_DIR=/opt/filmatch/logs
RUNAWAY=$LOG_DIR/debug-runaway.log
PIDFILE=/run/filmatch-fault.pid
CHUNK_MB=${CHUNK_MB:-256}
INTERVAL=${INTERVAL:-10}
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

case "${1:-}" in
start)
  echo "$(now) FAULT START - writing ${CHUNK_MB} MiB every ${INTERVAL}s to $RUNAWAY"
  df -h /
  nohup bash -c "
    while true; do
      dd if=/dev/urandom of='$RUNAWAY' bs=1M count=$CHUNK_MB oflag=append conv=notrunc status=none 2>/dev/null || break
      avail=\$(df --output=avail / | tail -1)
      [ \"\$avail\" -lt 1024 ] && break
      sleep $INTERVAL
    done
    echo \"\$(date -u +%FT%TZ) runaway writer stopped (disk full or error)\" >> /var/log/filmatch-fault.log
  " >/dev/null 2>&1 &
  echo $! >"$PIDFILE"
  echo "$(now) writer pid $(cat "$PIDFILE")" | tee -a /var/log/filmatch-fault.log
  ;;
status)
  echo "== $(now)"
  df -h /
  echo "== largest directories"
  du -xsh /opt/filmatch/* /var/lib/docker 2>/dev/null | sort -h | tail -8
  echo "== largest files under /opt/filmatch/logs"
  find "$LOG_DIR" -type f -printf '%s %p\n' 2>/dev/null | sort -n | tail -5 | awk '{printf "%8.1f MiB  %s\n", $1/1048576, $2}'
  echo "== deleted-but-open files"
  lsof +L1 2>/dev/null | head -5 || true
  echo "== containers"
  docker ps -a --format 'table {{.Names}}\t{{.Status}}'
  ;;
cleanup)
  if [ -f "$PIDFILE" ]; then kill "$(cat "$PIDFILE")" 2>/dev/null || true; rm -f "$PIDFILE"; fi
  pkill -f "of=$RUNAWAY" 2>/dev/null || true
  rm -f "$RUNAWAY"
  echo "$(now) FAULT CLEANED UP"
  df -h /
  docker ps -a --format 'table {{.Names}}\t{{.Status}}'
  ;;
*)
  echo "usage: $0 start|status|cleanup" >&2
  exit 2
  ;;
esac
