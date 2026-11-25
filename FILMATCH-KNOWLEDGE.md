# Filmatch knowledge deployment

`filmatch-document/` in the repository is the deployment-ready copy of the five fictional cafe documents. Edit this copy rather than the old sibling directory. The printed menu supplied by the team is transcribed into the menu reference; its prices and restrictions match the detailed documents. These documents contain no credentials or real personal data.

## Local refresh

From the repository root after dependencies are built:

```powershell
node scripts/filmatch-refresh-knowledge.cjs
```

Use `CONFIG_PATH=./librechat.filmatch.yaml` in your local and cloud environment. Restart the backend after refreshing. Start a new chat to verify the updated menu. The config embeds a snapshot, preserving the assistant instructions and theme. The script validates the config and refuses to replace it if a required document is missing or empty.

## AWS migration

1. Commit the bundled documents, script, logo assets, and configuration to the project repository. Do not commit the actual `.env` or API keys.
2. Create a private S3 bucket with public access blocked, versioning enabled, and a `knowledge/` prefix. From a properly authenticated AWS CLI session upload the documents:

   ```sh
   aws s3 sync ./filmatch-document/ s3://YOUR-BUCKET/knowledge/ --exclude '*' --include '*.md'
   ```

3. Deploy the repo to EC2 and install/build dependencies as usual. Grant the EC2 instance role `s3:GetObject` for this prefix and `s3:ListBucket` scoped to it. No access keys in the repo. Retrieve the Gemini key and app secrets using AWS Parameter Store at runtime, separately from this knowledge flow.
4. Before starting or restarting the application, pull the documents and refresh from that folder. Example from the repo root on Ubuntu:

   ```sh
   set -e
   stage=$(mktemp -d)
   trap 'rm -rf -- "$stage"' EXIT
   aws s3 sync s3://YOUR-BUCKET/knowledge/ "$stage/" --exclude '*' --include '*.md'
   node scripts/filmatch-refresh-knowledge.cjs "$stage"
   ```

   Use the real bucket name. Only after a successful refresh start `npm run backend`, or restart the service if one is already configured. Use this workflow as a startup/maintenance step; it is not live per-request S3 retrieval. If S3 sync or validation fails, do not silently deploy stale content. Keep the previous config available for rollback and alert the operator.
5. Demonstrate AWS integration: change a fictional item price in S3, refresh/restart, and ask the assistant in a new chat; then restore the prior S3 version and repeat. Record actual evidence. Keep the document content and application logs private.

For the assessment, add the above workflow to your EC2 service/deploy process, use the role and Parameter Store secret retrieval, and verify from EC2. The repository copy is useful for repeatable local work and recovery, while S3 becomes the deployed content source when that workflow is configured.

## Showing the printed menu image in chat

Save the original cafe menu as `client/public/assets/filmatch-menu.png` (a real PNG). The public menu image is intentionally served as a static public asset; do not put internal documents or secrets there. Run the knowledge refresh script, rebuild the frontend, and restart LibreChat. The refresh script enables an explicit inline Markdown image instruction only when the asset exists. Start a new Ask Filmatch chat and ask "Show me the menu" or "May larawan ba kayo ng menu?". The image is bundled with the frontend when deploying to EC2; S3 remains the text knowledge source. Update the printed image whenever the menu text changes so prices agree.