# Claude Ship Command

A powerful `/ship` skill for [Claude Code](https://claude.ai/claude-code) that automates your git commit, push, build, and deploy workflow in a single command.

**Works with any cloud provider** - Firebase, Vercel, Netlify, AWS, Azure, Cloudflare, Kubernetes, and more.

## Features

- **One command deployment**: Commit, push, build, and deploy with `/ship`
- **Auto-generated commit messages**: Analyzes your diff and creates conventional commits
- **Custom commit messages**: `/ship "feat: add new feature"`
- **Multi-environment support**: `/ship --env=staging` or `/ship --env=production`
- **Dry run mode**: `/ship --dry-run` to preview changes without executing
- **Branch protection**: Warns before deploying from protected branches
- **Pre/post hooks**: Run custom scripts at each stage
- **Verification with retries**: Confirms deployment is live
- **Cross-platform**: Mac, Windows, and Linux support
- **Safe**: Stops immediately on errors, never deploys broken builds

## Supported Cloud Destinations

| Provider | Example Config |
|----------|----------------|
| Firebase | [`examples/firebase.json`](examples/firebase.json) |
| Vercel | [`examples/vercel.json`](examples/vercel.json) |
| Netlify | [`examples/netlify.json`](examples/netlify.json) |
| AWS Amplify | [`examples/aws-amplify.json`](examples/aws-amplify.json) |
| AWS S3 + CloudFront | [`examples/aws-s3-cloudfront.json`](examples/aws-s3-cloudfront.json) |
| Cloudflare Pages | [`examples/cloudflare-pages.json`](examples/cloudflare-pages.json) |
| Azure Static Web Apps | [`examples/azure-static-web-apps.json`](examples/azure-static-web-apps.json) |
| Docker + Kubernetes | [`examples/docker-kubernetes.json`](examples/docker-kubernetes.json) |
| GitHub Pages | [`examples/github-pages.json`](examples/github-pages.json) |
| Heroku | [`examples/heroku.json`](examples/heroku.json) |
| Fly.io | [`examples/fly-io.json`](examples/fly-io.json) |
| Railway | [`examples/railway.json`](examples/railway.json) |
| Render | [`examples/render.json`](examples/render.json) |
| Git only (no deploy) | [`examples/git-only.json`](examples/git-only.json) |

## Quick Start

### Installation

**Mac / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/Sterling-Sky/claude-ship-command/main/install.sh | bash
```

**Windows (PowerShell as Administrator):**
```powershell
irm https://raw.githubusercontent.com/Sterling-Sky/claude-ship-command/main/install.ps1 | iex
```

**Manual Installation:**
```bash
# Create the skills directory if it doesn't exist
mkdir -p ~/.claude/skills

# Copy the skill file
curl -o ~/.claude/skills/ship.md https://raw.githubusercontent.com/Sterling-Sky/claude-ship-command/main/ship.md

# Copy and customize the config (pick one from examples/ or use the default)
curl -o ~/.claude/ship.config.json https://raw.githubusercontent.com/Sterling-Sky/claude-ship-command/main/examples/firebase.json
```

### Configuration

Create `~/.claude/ship.config.json` (global) or `.claude/ship.config.json` (project-level):

```json
{
  "build": {
    "command": "npm run build",
    "enabled": true
  },
  "deploy": {
    "command": "firebase deploy --only functions,hosting",
    "enabled": true
  },
  "verify": {
    "url": "https://your-app.web.app/",
    "enabled": true
  }
}
```

### Usage

```bash
# Auto-generate commit message, push, build, and deploy
/ship

# Use a custom commit message
/ship "feat: add user authentication"

# Deploy to staging environment
/ship --env=staging "feat: new dashboard"

# Preview what would happen (dry run)
/ship --dry-run

# Commit and push only (skip build and deploy)
/ship --no-deploy "fix: typo in readme"

# Skip build step
/ship --no-build

# Override branch protection
/ship --force
```

## Full Configuration Reference

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
    "preBuild": "npm run lint",
    "postBuild": "npm run test",
    "preDeploy": "echo 'Deploying...'",
    "postDeploy": "slack-notify 'Deployed!'"
  },
  "environments": {
    "production": {
      "deploy": { "command": "firebase deploy --only functions,hosting" },
      "verify": { "url": "https://your-app.web.app/" },
      "protectedBranches": ["main", "master"]
    },
    "staging": {
      "deploy": { "command": "firebase deploy --project staging" },
      "verify": { "url": "https://staging.your-app.web.app/" }
    }
  },
  "defaultEnvironment": "production"
}
```

### Configuration Options

| Option | Type | Description | Default |
|--------|------|-------------|---------|
| `build.command` | string | Build command to run | `npm run build` |
| `build.enabled` | boolean | Whether to run build step | `true` |
| `deploy.command` | string | Deploy command to run | `null` |
| `deploy.enabled` | boolean | Whether to run deploy step | `false` |
| `verify.url` | string | URL to check after deploy | `null` |
| `verify.enabled` | boolean | Whether to verify deployment | `true` |
| `verify.retries` | number | Retry attempts for verification | `3` |
| `verify.retryDelay` | number | Seconds between retries | `5` |
| `git.addAll` | boolean | Use `git add -A` (vs staged only) | `true` |
| `git.pushUpstream` | boolean | Auto-set upstream on push | `true` |
| `hooks.preBuild` | string | Command to run before build | `null` |
| `hooks.postBuild` | string | Command to run after build | `null` |
| `hooks.preDeploy` | string | Command to run before deploy | `null` |
| `hooks.postDeploy` | string | Command to run after deploy | `null` |
| `environments` | object | Environment-specific overrides | `{}` |
| `defaultEnvironment` | string | Default environment name | `production` |

## How It Works

```
/ship "feat: add user dashboard"

Step 1/6: Pre-flight ✅
  Changes: 5 files, +120 -30 lines
  Branch: main (protected)

Step 2/6: Commit ✅ (feat: add user dashboard)

Step 3/6: Push ✅ (main → origin/main)

Step 4/6: Build ✅

Step 5/6: Deploy ✅

Step 6/6: Verify ✅ (HTTP 200, attempt 1/3)

🚀 Shipped to production!
   URL: https://your-app.web.app
```

## Project-Level Configuration

Create a `.claude/ship.config.json` file in your project root. Project-level config takes precedence over the global `~/.claude/ship.config.json`.

This allows each project to have its own deployment configuration without modifying global settings.

## Environment Support

Define multiple environments with different deployment targets:

```json
{
  "environments": {
    "production": {
      "deploy": { "command": "firebase deploy" },
      "verify": { "url": "https://prod.example.com/" },
      "protectedBranches": ["main"]
    },
    "staging": {
      "deploy": { "command": "firebase deploy --project staging" },
      "verify": { "url": "https://staging.example.com/" }
    },
    "dev": {
      "deploy": { "command": "firebase deploy --project dev" },
      "verify": { "url": "https://dev.example.com/" }
    }
  },
  "defaultEnvironment": "production"
}
```

Usage:
```bash
/ship --env=staging "feat: new feature"
/ship --env=production --force "hotfix: critical bug"
```

## Pre/Post Hooks

Run custom commands at each stage of the deployment:

```json
{
  "hooks": {
    "preBuild": "npm run lint && npm run typecheck",
    "postBuild": "npm run test",
    "preDeploy": "npm run backup-db",
    "postDeploy": "curl -X POST $SLACK_WEBHOOK -d '{\"text\":\"Deployed!\"}'"
  }
}
```

## Security

- **No hardcoded credentials**: Uses your existing CLI authentication (firebase, vercel, aws, etc.)
- **No data collection**: Everything runs locally
- **Open source**: Full visibility into what the command does
- **Branch protection**: Warns before deploying from main/master

## Requirements

- [Claude Code CLI](https://claude.ai/claude-code)
- Git
- Your deployment CLI (firebase, vercel, netlify, aws, etc.) if using deploy features

## Troubleshooting

### "git push" fails
Your local branch is behind the remote. Run:
```bash
git pull --rebase
```

### "npm run build" fails
Check your build errors. The ship command intentionally stops here to prevent deploying broken code.

### Deploy command fails
Ensure you're logged in to your deployment provider:
```bash
# Firebase
firebase login

# Vercel
vercel login

# Netlify
netlify login

# AWS
aws configure
```

### Config not found
Check that your config file exists at:
- `~/.claude/ship.config.json` (global)
- `.claude/ship.config.json` (project-level)

### Protected branch warning
Use `--force` to override, or switch to a feature branch before shipping.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE)

## Credits

Created for use with [Claude Code](https://claude.ai/claude-code) by Anthropic.
