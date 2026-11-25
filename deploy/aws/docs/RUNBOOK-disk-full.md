# RUNBOOK: Root disk full on the Filmatch instance

Owner: Filmatch ops   Last tested: _<date of your drill>_   Takes: ~15 min   Ask: _<name>_

## 1. What this is for
Getting Filmatch answering again when the EC2 root disk is full, and stopping it happening again.

## 2. How you know you need it
- Alarm **filmatch-disk-used-high** (> 85 %) e-mail. If it was missed: **filmatch-answers-failed-rate**, **filmatch-app-errors** or **filmatch-healthcheck-failed**.
- Users see errors, or chats stop being saved.
- Command that shows the problem (laptop):
  ```bash
  bash deploy/aws/bin/remote.sh 'df -h /; du -xsh /opt/filmatch/* /var/lib/docker | sort -h'
  ```

## 3. What it affects
At 100 % MongoDB cannot write, so new messages and logins fail, and the API may crash-loop. Every user is affected, and nothing is saved until the disk is fixed. Data already written is safe.

## 4. How to do it
1. Open a shell: `aws ssm start-session --target <InstanceId>`, then `sudo -i`
   → you should see a root prompt.
2. Find what is big: `bash /opt/filmatch/deploy/scripts/fault-disk-fill.sh status`
   → disk near 100 %, and one huge file under `/opt/filmatch/logs`.
3. If a writer is still running, stop it: `pgrep -af 'debug-runaway|dd if='`, then `kill <pid>`.
4. Free space. **Truncate** the log rather than deleting it while it is open; logs are already in CloudWatch:
   `truncate -s 0 /opt/filmatch/logs/<big-file>.log`
   (drill: `bash /opt/filmatch/deploy/scripts/fault-disk-fill.sh cleanup`)
   → `df -h /` shows free space.
5. If `lsof +L1` lists deleted-but-open files, restart that container: `docker restart filmatch-api`
6. Check the containers: `docker ps`. If MongoDB or the API exited, run `bash /opt/filmatch/deploy/scripts/deploy.sh`
   → `health OK after Ns`.
7. **Prevent it:** `bash /opt/filmatch/deploy/scripts/log-guard.sh install`
   → `log guard installed`. Then uncomment the `log-guard.sh install` line in `deploy/aws/instance/scripts/deploy.sh` and commit, so a rebuilt instance gets it too.
8. If the cause was old Docker images: `docker image prune -af`. If it is genuine growth, resize the EBS volume (`RootVolumeGiB`) and run `growpart /dev/nvme0n1 1 && xfs_growfs /`.

## 5. How to check it worked
- [ ] `df -h /` is below 85 %, and the alarm e-mails OK
- [ ] Ask the system-card test question ("What are your opening hours?") in a new chat and get a sensible answer
- [ ] No new alarms for 10 minutes
- [ ] `log-guard.sh status` shows the timer running every minute

## 6. How to undo it
Truncating logs cannot be undone, and the content is in CloudWatch `/filmatch/app`. To remove the guard: `log-guard.sh remove`.

## 7. Gotchas
- Deleting (`rm`) a file a process still has open frees nothing. Truncate it, or restart the process.
- The CloudWatch agent sends disk metrics every 60 s and the alarm evaluates 5-minute periods, so expect up to ~6 minutes between crossing 85 % and the e-mail.
- `copytruncate` needs free space equal to the file size. That is why the guard truncates files over 200 MiB *before* it runs logrotate.

## 8. Change history
- _<date>_: drill run, root cause recorded, log guard installed. _(fill in)_

---

## Incident timeline (fill in with REAL times from the drill; put this on the website)

| Event | Time (UTC+8) | Source |
| --- | --- | --- |
| Fault started | | output of `fault-disk-fill.sh start` |
| Disk crossed 85 % | | dashboard "Disk used %" |
| Alarm e-mail received (**detected**) | | e-mail timestamp |
| Investigation started | | |
| Fixed (disk < 85 %, health OK) | | `cleanup` output + OK e-mail |
| Prevention installed | | `log-guard.sh install` |
| **Time to detect** = alarm − start | | |
| **Time to fix** = fixed − alarm | | |

**Root cause (template; edit it to match what you observe):** LibreChat writes log files to
`/opt/filmatch/logs`, which is a bind mount on the 30 GiB root volume. There was no size cap or rotation
on those files. A runaway debug log (simulated by `fault-disk-fill.sh`) filled the root disk. MongoDB
could then not write, so chat turns failed.

**Prevention and evidence:** after `log-guard.sh install`, re-run `fault-disk-fill.sh start` for 5 minutes.
The dashboard disk line should stay flat, and `journalctl -u filmatch-log-guard` should show "truncated oversized log".
Then run `cleanup`.
