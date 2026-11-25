#!/bin/bash
# WS-F prevention for the disk-full fault: cap application log files on the root disk.
#
#   install   create /etc/logrotate.d/filmatch and a systemd timer that runs every minute:
#               1. any *.log under /opt/filmatch/logs larger than 200 MiB is truncated
#                  (logs are already shipped to CloudWatch, so nothing is lost)
#               2. logrotate keeps at most 3 compressed 50 MiB generations
#   status    show the timer and its last runs (evidence it works unattended)
#   remove    undo
set -euo pipefail

case "${1:-}" in
install)
  cat >/etc/logrotate.d/filmatch <<'EOF'
/opt/filmatch/logs/*.log {
    size 50M
    rotate 3
    compress
    missingok
    notifempty
    copytruncate
}
EOF
  cat >/usr/local/bin/filmatch-log-guard <<'EOF'
#!/bin/bash
# Truncate first (copytruncate on a huge file would itself need free disk), then rotate.
find /opt/filmatch/logs -type f -name '*.log' -size +200M -print -exec truncate -s 0 {} + |
  sed "s/^/$(date -u +%FT%TZ) truncated oversized log: /"
/usr/sbin/logrotate /etc/logrotate.d/filmatch
echo "$(date -u +%FT%TZ) log-guard ok, root disk $(df --output=pcent / | tail -1 | tr -d ' ') used"
EOF
  chmod 755 /usr/local/bin/filmatch-log-guard
  cat >/etc/systemd/system/filmatch-log-guard.service <<'EOF'
[Unit]
Description=Filmatch log guard (WS-F disk-full prevention)
[Service]
Type=oneshot
ExecStart=/usr/local/bin/filmatch-log-guard
EOF
  cat >/etc/systemd/system/filmatch-log-guard.timer <<'EOF'
[Unit]
Description=Run Filmatch log guard every minute
[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
AccuracySec=10s
[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now filmatch-log-guard.timer
  echo "log guard installed"
  ;;
status)
  systemctl list-timers filmatch-log-guard.timer --no-pager
  journalctl -u filmatch-log-guard.service --no-pager -n 20
  ;;
remove)
  systemctl disable --now filmatch-log-guard.timer || true
  rm -f /etc/systemd/system/filmatch-log-guard.{service,timer} /usr/local/bin/filmatch-log-guard /etc/logrotate.d/filmatch
  systemctl daemon-reload
  echo "log guard removed"
  ;;
*)
  echo "usage: $0 install|status|remove" >&2
  exit 2
  ;;
esac
