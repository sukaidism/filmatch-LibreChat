# RUNBOOK: Restore the Filmatch database from backup

Owner: Filmatch ops   Last tested: _<date>_   Takes: ~10–20 min   Ask: _<name>_

## 1. What this is for
Proving the backups work (restore test), or recovering the live database after data loss or corruption.

## 2. How you know you need it
- **Test:** on a schedule, and before the marker asks "show me the restore".
- **Real:** users or chats are missing, MongoDB will not start, or data was deleted by mistake.
- Show the available backups:
  ```bash
  aws s3 ls s3://filmatch-backups-<account>-ap-southeast-2/mongodb/ | tail
  ```

## 3. What it affects
A restore test affects nobody; it uses separate containers. A live restore takes the app down for a few minutes and **loses every chat since the dump** (the RPO).

## 4. How to do it

### A. Restore test (safe)
1. From the laptop: `bash deploy/aws/bin/remote.sh restore-test`
   → a table of live vs. restored counts for `users`, `conversations` and `messages`, then `result=PASS`.
2. To log in to the restored copy, open a shell on the instance and run:
   `bash /opt/filmatch/deploy/scripts/restore-test.sh latest --with-app`
   → `restored app is healthy at 127.0.0.1:8081 after Ns total`
3. On the laptop:
   `aws ssm start-session --target <InstanceId> --document-name AWS-StartPortForwardingSession --parameters portNumber=8081,localPortNumber=8081`
4. Open http://localhost:8081 and log in with a test account. Old conversations are visible. Screenshot it.
5. Clean up: `bash /opt/filmatch/deploy/scripts/restore-test.sh --cleanup`

### B. Live restore (data loss)
1. Pick the dump: `aws s3 ls s3://…-backups-…/mongodb/`
2. On the instance: `bash /opt/filmatch/deploy/scripts/restore-live.sh mongodb/<ts>.archive.gz --yes`
   → `LIVE RESTORE COMPLETE in Ns`. The broken state is dumped to `/opt/filmatch/backup/pre-restore-*.archive.gz` first.
3. **Whole instance lost:** redeploy the stack (`deploy-stack.sh app`, or restore the AWS Backup EBS snapshot), run `remote.sh deploy`, then step 2.

## 5. How to check it worked
- [ ] Log in with a test account and see the expected conversations
- [ ] Ask "What are your opening hours?" in a new chat and get the documented hours
- [ ] No new alarms for 10 minutes

## 6. How to undo it
Restore the `pre-restore-*.archive.gz` with `docker exec -i filmatch-mongodb mongorestore --archive --gzip --drop < file`.

## 7. Gotchas
- The restore needs the **same** `CREDS_KEY`/`CREDS_IV` from Parameter Store, or stored encrypted credentials cannot be read. User passwords are bcrypt hashes and survive regardless.
- The restored app on :8081 is for testing only; registration is disabled there.
- `aws s3 ls` sorts by name, and our names are UTC timestamps, so the last one is the newest.

## 8. Change history
- _<date>_: first restore test. Measured restore time _<s>_, counts matched _<yes/no>_. _(fill in)_

## RPO / RTO (fill in from your measured test)
- **RPO:** up to 24 h of chats, because the dump runs nightly at 02:00 Manila. Measured age of the dump used: _<…>_.
- **RTO:** _<measured seconds from restore-test.sh>_ for the database, plus about 5 min to log in and verify. A whole-instance rebuild is about 15 min of stack creation plus deploy.
