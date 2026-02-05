---
description: Git add, commit, push, build, and deploy in one command
argument-hint: [commit-message] [--env=ENV] [--dry-run] [--no-deploy] [--no-build] [--force]
allowed-tools: Bash(git:*), Bash(npm:*), Bash(yarn:*), Bash(pnpm:*), Bash(firebase:*), Bash(vercel:*), Bash(netlify:*), Bash(amplify:*), Bash(docker:*), Bash(kubectl:*), Bash(echo:*), Bash(curl:*), Bash(cat:*), Bash(sh:*), Bash(bash:*), Read
---

Ship your project: commit all changes, push to origin, build, and deploy.

## Usage

```
/ship                              # Auto-generate commit, push, build, deploy
/ship "feat: add feature"          # Custom commit message
/ship --env=staging                # Deploy to staging environment
/ship --dry-run                    # Preview what would happen
/ship --no-deploy                  # Commit and push only
/ship --no-build                   # Skip build step
/ship --force                      # Override branch protection
```

Arguments: $ARGUMENTS

## Configuration

Look for config in this order (first found wins):
1. `.claude/ship.config.json` (project-level)
2. `~/.claude/ship.config.json` (global)
3. Use defaults if no config found

### Full Configuration Schema

```json
{
  "build": {
    "command": "npm run build",
    "enabled": true
  },
  "deploy": {
    "command": "firebase deploy",
    "enabled": true
  },
  "verify": {
    "url": "https://your-app.web.app/",
    "enabled": true,
    "retries": 3,
    "retryDelay": 5
  },
  "git": {
    "addAll": true,
    "pushUpstream": true
  },
  "hooks": {
    "preBuild": null,
    "postBuild": null,
    "preDeploy": null,
    "postDeploy": null
  },
  "environments": {
    "production": {
      "deploy": { "command": "firebase deploy --only functions,hosting" },
      "verify": { "url": "https://your-app.web.app/" },
      "protectedBranches": ["main", "master"]
    },
    "staging": {
      "deploy": { "command": "firebase deploy --only functions,hosting --project staging" },
      "verify": { "url": "https://staging-your-app.web.app/" }
    }
  },
  "defaultEnvironment": "production"
}
```

### Multi-Destination Configuration

Deploy to multiple targets (e.g., Firebase + Cloud Run) with a single `/ship`:

```json
{
  "deploy": {
    "targets": [
      {
        "name": "Firebase",
        "command": "firebase deploy --only functions,hosting",
        "verify": "https://your-app.web.app/"
      },
      {
        "name": "Cloud Run",
        "command": "gcloud run deploy your-app --image $REGION-docker.pkg.dev/$PROJECT_ID/$REPO/app:$(git rev-parse --short HEAD) --platform managed --region $REGION",
        "verify": "https://your-app-xxxxx-uc.a.run.app/"
      }
    ],
    "parallel": false,
    "stopOnFailure": true,
    "enabled": true
  }
}
```

Multi-destination options:
- `targets[]` - Array of deployment targets with name, command, and verify URL
- `parallel` - Run targets simultaneously (default: false for sequential)
- `stopOnFailure` - Stop remaining targets if one fails (default: true)

## Workflow

Execute each step sequentially. **Stop immediately if any step fails** (unless in dry-run mode).

### Step 0: Parse Arguments & Load Configuration

1. Parse `$ARGUMENTS` for flags:
   - `--env=ENV` → Set target environment (default: from config or "production")
   - `--dry-run` → Preview mode, don't execute commands
   - `--no-deploy` → Skip build and deploy steps
   - `--no-build` → Skip build step only
   - `--force` → Override branch protection warnings
   - Remaining text → Commit message

2. Load configuration:
   - Check `.claude/ship.config.json` first
   - Fall back to `~/.claude/ship.config.json`
   - Apply environment-specific overrides if `--env` specified

3. If `--dry-run`, prefix all output with `[DRY RUN]` and don't execute commands

### Step 1: Pre-flight Checks

1. Run `git status` to check for changes:
   - If clean working tree AND not forcing, skip to Step 4 (build + deploy only)
   - If clean AND forcing, continue with build/deploy

2. Run `git diff --stat` to summarize changes

3. Check branch protection:
   ```bash
   current_branch=$(git branch --show-current)
   ```
   - If current branch is in `protectedBranches` for the environment:
     - If `--force` flag is NOT set, warn and ask for confirmation
     - Show: "⚠️  Deploying from protected branch '{branch}'. Use --force to override."
     - STOP unless --force is provided

4. Run `git log --oneline -3` to see recent commit style

**Output:**
```
Step 1/6: Pre-flight ✅
  Changes: 3 files, +45 -12 lines
  Branch: main (protected)
```

### Step 2: Commit

1. If config `git.addAll` is true (default), stage all changes:
   ```bash
   git add -A
   ```

2. Determine commit message:
   - If message provided in arguments → Use it
   - Otherwise, analyze `git diff --cached` and generate conventional commit:
     - `feat:` for new features (new files, new functions)
     - `fix:` for bug fixes
     - `refactor:` for restructuring without behavior change
     - `docs:` for documentation changes (*.md, comments)
     - `test:` for test additions/changes
     - `style:` for formatting (whitespace, semicolons)
     - `perf:` for performance improvements
     - `chore:` for maintenance (deps, configs)

3. Create the commit:
   ```bash
   git commit -m "<message>"
   ```

**Output:**
```
Step 2/6: Commit ✅ (feat: add user dashboard)
```

### Step 3: Push

1. Check if upstream is set:
   ```bash
   git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null
   ```

2. Push appropriately:
   - If upstream exists: `git push`
   - If no upstream and `git.pushUpstream` is true:
     ```bash
     git push -u origin $(git branch --show-current)
     ```

3. If push fails with "behind remote":
   - Report error: "Your branch is behind. Run: `git pull --rebase`"
   - STOP

**Output:**
```
Step 3/6: Push ✅ (main → origin/main)
```

### Step 4: Build (if enabled)

Skip if:
- `--no-build` or `--no-deploy` flag is set
- `build.enabled` is false

1. Run pre-build hook if configured:
   ```bash
   {config.hooks.preBuild}
   ```

2. Run the build command:
   ```bash
   {config.build.command}
   ```

3. Run post-build hook if configured:
   ```bash
   {config.hooks.postBuild}
   ```

4. If build fails → STOP (never deploy broken code)

**Output:**
```
Step 4/6: Build ✅
```

### Step 5: Deploy (if enabled)

Skip if:
- `--no-deploy` flag is set
- `deploy.enabled` is false
- `deploy.command` is null AND `deploy.targets` is empty

1. Run pre-deploy hook if configured:
   ```bash
   {config.hooks.preDeploy}
   ```

2. **Single-destination deploy:**
   If `deploy.command` is set (not using targets array):
   ```bash
   {environments[env].deploy.command || config.deploy.command}
   ```

3. **Multi-destination deploy:**
   If `deploy.targets` array is configured:
   - Loop through each target in the array
   - For each target, run its command:
     ```bash
     {target.command}
     ```
   - Report success/failure for each target by name
   - If `stopOnFailure` is true (default), stop on first failure
   - If `parallel` is true, run all targets simultaneously

4. Run post-deploy hook if configured:
   ```bash
   {config.hooks.postDeploy}
   ```

**Output:**
```
Step 5/6: Deploy ✅
  URL: https://your-app.web.app
```

### Step 6: Verify (if enabled)

Skip if:
- `verify.enabled` is false
- `verify.url` is null
- Deploy was skipped

1. Get verification URL (check environment-specific config first):
   ```
   {environments[env].verify.url || config.verify.url}
   ```

2. Retry logic with configurable attempts:
   ```bash
   for attempt in 1..{config.verify.retries || 3}; do
     status=$(curl -s -o /dev/null -w "%{http_code}" {url})
     if [ "$status" = "200" ]; then
       break
     fi
     sleep {config.verify.retryDelay || 5}
   done
   ```

3. Report result:
   - HTTP 200 → Success
   - Other codes → Warning (deployment may still be propagating)

**Output:**
```
Step 6/6: Verify ✅ (HTTP 200, attempt 1/3)
```

## Error Handling

| Error | Message | Suggested Fix |
|-------|---------|---------------|
| Push fails (behind) | "Branch behind remote" | `git pull --rebase` |
| Push fails (no upstream) | "No upstream branch" | Add `--force` or set upstream |
| Build fails | "Build failed" | Fix build errors, don't deploy |
| Deploy fails | "Deploy failed" | Check CLI auth: `firebase login` |
| Verify fails | "HTTP {code}" | Check deploy logs, may be propagating |
| Protected branch | "Protected branch" | Use `--force` or switch branches |

## Output Formats

### Standard Success
```
Step 1/6: Pre-flight ✅
Step 2/6: Commit ✅ (feat: add user dashboard)
Step 3/6: Push ✅ (main → origin/main)
Step 4/6: Build ✅
Step 5/6: Deploy ✅
Step 6/6: Verify ✅ (HTTP 200)

🚀 Shipped to production!
   URL: https://your-app.web.app
```

### With Skipped Steps
```
Step 1/6: Pre-flight ✅
Step 2/6: Commit ✅ (fix: typo)
Step 3/6: Push ✅ (main → origin/main)
Step 4/6: Build ⏭️ (skipped: --no-deploy)
Step 5/6: Deploy ⏭️ (skipped: --no-deploy)
Step 6/6: Verify ⏭️ (skipped)

✅ Pushed to origin/main
```

### Dry Run
```
[DRY RUN] Step 1/6: Pre-flight
  Would stage: 3 files changed
  Branch: feature/auth (not protected)

[DRY RUN] Step 2/6: Commit
  Would commit: "feat: add user authentication"

[DRY RUN] Step 3/6: Push
  Would push: feature/auth → origin/feature/auth

[DRY RUN] Step 4/6: Build
  Would run: npm run build

[DRY RUN] Step 5/6: Deploy
  Would run: firebase deploy --only functions,hosting

[DRY RUN] Step 6/6: Verify
  Would check: https://your-app.web.app/

No changes made (dry run mode)
```

### On Error
```
Step 1/6: Pre-flight ✅
Step 2/6: Commit ✅ (feat: add dashboard)
Step 3/6: Push ❌

Error: Your branch is behind 'origin/main' by 2 commits.
Fix: Run `git pull --rebase` then `/ship` again
```

### Clean Working Tree
```
Step 1/6: Pre-flight ✅ (no changes to commit)
Step 2/6: Commit ⏭️ (nothing to commit)
Step 3/6: Push ⏭️ (already up to date)
Step 4/6: Build ✅
Step 5/6: Deploy ✅
Step 6/6: Verify ✅ (HTTP 200)

🚀 Deployed (no new commits)
```
