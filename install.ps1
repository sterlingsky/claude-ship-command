# Claude Ship Command - Interactive Installer for Windows
# Run in PowerShell (Administrator recommended for system-wide install)

$ErrorActionPreference = "Stop"

# Config
$ClaudeDir = "$env:USERPROFILE\.claude"
$SkillsDir = "$ClaudeDir\skills"
$ConfigFile = "$ClaudeDir\ship.config.json"
$RepoUrl = "https://raw.githubusercontent.com/Sterling-Sky/claude-ship-command/main"

function Write-Header {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "        Claude Ship Command - Interactive Setup                 " -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "--- $Text ---" -ForegroundColor Cyan
    Write-Host ""
}

function Select-Option {
    param(
        [string]$Prompt,
        [string[]]$Options
    )

    Write-Host $Prompt -ForegroundColor Yellow
    Write-Host ""

    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "  $($i + 1)) $($Options[$i])"
    }

    Write-Host ""
    do {
        $choice = Read-Host "Enter number (1-$($Options.Count))"
        $num = 0
        if ([int]::TryParse($choice, [ref]$num) -and $num -ge 1 -and $num -le $Options.Count) {
            return $Options[$num - 1]
        }
        Write-Host "Invalid choice. Please enter a number between 1 and $($Options.Count)." -ForegroundColor Red
    } while ($true)
}

function Get-Confirmation {
    param(
        [string]$Prompt,
        [bool]$Default = $true
    )

    if ($Default) {
        $suffix = "[Y/n]"
    } else {
        $suffix = "[y/N]"
    }

    $response = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }
    return $response -match '^[Yy]'
}

function Get-Input {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    if ($Default) {
        $response = Read-Host "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $Default
        }
        return $response
    } else {
        return Read-Host $Prompt
    }
}

function New-Config {
    param(
        [string]$Platform,
        [string]$AppUrl,
        [string]$StagingUrl,
        [string]$BuildCmd,
        [string]$DeployCmd,
        [string]$StagingDeployCmd
    )

    $config = @{
        build = @{
            command = $BuildCmd
            enabled = $true
        }
        deploy = @{
            command = $DeployCmd
            enabled = $true
        }
        verify = @{
            url = $AppUrl
            enabled = $true
            retries = 3
            retryDelay = 5
        }
        git = @{
            addAll = $true
            pushUpstream = $true
        }
        hooks = @{
            preBuild = $null
            postBuild = $null
            preDeploy = $null
            postDeploy = $null
        }
    }

    if ($StagingUrl -and $StagingUrl -ne "none") {
        $config.environments = @{
            production = @{
                deploy = @{ command = $DeployCmd }
                verify = @{ url = $AppUrl }
                protectedBranches = @("main", "master")
            }
            staging = @{
                deploy = @{ command = $StagingDeployCmd }
                verify = @{ url = $StagingUrl }
            }
        }
        $config.defaultEnvironment = "production"
    }

    return $config | ConvertTo-Json -Depth 10
}

# Main installation
Write-Header

# Create directories
if (-not (Test-Path $SkillsDir)) {
    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
}

# Download skill file
Write-Step "Step 1/4: Downloading ship.md"
$ProgressPreference = 'SilentlyContinue'
try {
    Invoke-WebRequest -Uri "$RepoUrl/ship.md" -OutFile "$SkillsDir\ship.md" -UseBasicParsing
    Write-Host "  Downloaded ship.md" -ForegroundColor Green
} catch {
    Write-Host "  Error downloading ship.md: $_" -ForegroundColor Red
    exit 1
}

# Check for existing config
if (Test-Path $ConfigFile) {
    Write-Step "Existing Configuration Found"
    Write-Host "Found existing config at: $ConfigFile"
    Write-Host ""
    if (-not (Get-Confirmation "Do you want to replace it with a new configuration?")) {
        Write-Host ""
        Write-Host "  Keeping existing configuration." -ForegroundColor Green
        Write-Host ""
        Write-Host "Installation complete!" -ForegroundColor Green
        Write-Host "Type /ship in Claude Code to use the command."
        exit 0
    }
}

# Platform selection
Write-Step "Step 2/4: Select Your Platform"

$platforms = @(
    "Firebase (Hosting + Functions)",
    "Vercel",
    "Netlify",
    "Cloudflare Pages",
    "AWS Amplify",
    "AWS S3 + CloudFront",
    "Azure Static Web Apps",
    "GitHub Pages",
    "Docker + Kubernetes",
    "Heroku",
    "Fly.io",
    "Railway",
    "Render",
    "Git only (no deploy)",
    "Custom (I'll configure manually)"
)

$platform = Select-Option "Which platform do you deploy to?" $platforms
Write-Host ""
Write-Host "  Selected: $platform" -ForegroundColor Green

# Set defaults based on platform
switch -Wildcard ($platform) {
    "Firebase*" {
        $buildCmd = "npm run build"
        $deployCmd = "firebase deploy --only functions,hosting"
        $stagingDeployCmd = "firebase deploy --only functions,hosting --project staging"
        $urlExample = "https://your-app.web.app"
        $stagingExample = "https://your-app-staging.web.app"
    }
    "Vercel" {
        $buildCmd = "npm run build"
        $deployCmd = "vercel --prod"
        $stagingDeployCmd = "vercel"
        $urlExample = "https://your-app.vercel.app"
        $stagingExample = ""
    }
    "Netlify" {
        $buildCmd = "npm run build"
        $deployCmd = "netlify deploy --prod --dir=dist"
        $stagingDeployCmd = "netlify deploy --dir=dist"
        $urlExample = "https://your-app.netlify.app"
        $stagingExample = ""
    }
    "Cloudflare*" {
        $buildCmd = "npm run build"
        $deployCmd = "wrangler pages deploy dist --project-name=your-app"
        $stagingDeployCmd = "wrangler pages deploy dist --project-name=your-app-staging"
        $urlExample = "https://your-app.pages.dev"
        $stagingExample = ""
    }
    "AWS Amplify" {
        $buildCmd = "npm run build"
        $deployCmd = "amplify publish --yes"
        $stagingDeployCmd = "amplify publish --yes --envName dev"
        $urlExample = "https://main.your-app-id.amplifyapp.com"
        $stagingExample = "https://dev.your-app-id.amplifyapp.com"
    }
    "AWS S3*" {
        $buildCmd = "npm run build"
        $deployCmd = "aws s3 sync dist/ s3://your-bucket --delete"
        $stagingDeployCmd = "aws s3 sync dist/ s3://your-bucket-staging --delete"
        $urlExample = "https://your-cloudfront-domain.cloudfront.net"
        $stagingExample = ""
    }
    "Azure*" {
        $buildCmd = "npm run build"
        $deployCmd = "swa deploy ./dist"
        $stagingDeployCmd = "swa deploy ./dist --env preview"
        $urlExample = "https://your-app.azurestaticapps.net"
        $stagingExample = ""
    }
    "GitHub*" {
        $buildCmd = "npm run build"
        $deployCmd = "npx gh-pages -d dist"
        $stagingDeployCmd = ""
        $urlExample = "https://your-username.github.io/your-repo"
        $stagingExample = ""
    }
    "Docker*" {
        $buildCmd = "docker build -t your-app:latest ."
        $deployCmd = "kubectl apply -f k8s/"
        $stagingDeployCmd = "kubectl apply -f k8s/ --context staging"
        $urlExample = "https://your-app.your-cluster.com"
        $stagingExample = "https://staging.your-app.your-cluster.com"
    }
    "Heroku" {
        $buildCmd = ""
        $deployCmd = "git push heroku HEAD:main"
        $stagingDeployCmd = "git push heroku-staging HEAD:main"
        $urlExample = "https://your-app.herokuapp.com"
        $stagingExample = "https://your-app-staging.herokuapp.com"
    }
    "Fly.io" {
        $buildCmd = ""
        $deployCmd = "fly deploy"
        $stagingDeployCmd = "fly deploy --app your-app-staging"
        $urlExample = "https://your-app.fly.dev"
        $stagingExample = "https://your-app-staging.fly.dev"
    }
    "Railway" {
        $buildCmd = ""
        $deployCmd = "railway up"
        $stagingDeployCmd = "railway up --environment staging"
        $urlExample = "https://your-app.railway.app"
        $stagingExample = "https://your-app-staging.railway.app"
    }
    "Render" {
        $buildCmd = "npm run build"
        $deployCmd = "# Render auto-deploys from git"
        $stagingDeployCmd = ""
        $urlExample = "https://your-app.onrender.com"
        $stagingExample = ""
    }
    "Git only*" {
        $buildCmd = ""
        $deployCmd = ""
        $stagingDeployCmd = ""
        $urlExample = ""
        $stagingExample = ""
    }
    "Custom*" {
        $buildCmd = "npm run build"
        $deployCmd = ""
        $stagingDeployCmd = ""
        $urlExample = ""
        $stagingExample = ""
    }
}

# Git-only mode
if ($platform -like "Git only*") {
    Write-Step "Step 3/4: Configuration"
    Write-Host "Git-only mode selected. No deploy or verify configuration needed."
    $appUrl = ""
    $stagingUrl = "none"
} else {
    Write-Step "Step 3/4: Configure Your URLs"

    # Production URL
    if ($urlExample) {
        Write-Host "What is your production URL?" -ForegroundColor Yellow
        Write-Host "Example: $urlExample"
    }
    $appUrl = Get-Input "Production URL" $urlExample

    # Staging
    Write-Host ""
    if (Get-Confirmation "Do you have a staging environment?" $false) {
        if ($stagingExample) {
            Write-Host ""
            Write-Host "Example: $stagingExample"
        }
        $stagingUrl = Get-Input "Staging URL" $stagingExample
    } else {
        $stagingUrl = "none"
    }
}

# Build command
if ($platform -notlike "Git only*") {
    Write-Host ""
    if ($buildCmd) {
        Write-Host "Build command: $buildCmd" -ForegroundColor Yellow
        if (Get-Confirmation "Would you like to customize it?" $false) {
            $buildCmd = Get-Input "Build command" $buildCmd
        }
    } else {
        if (Get-Confirmation "Do you need a build step?" $false) {
            $buildCmd = Get-Input "Build command" "npm run build"
        }
    }

    # Deploy command
    Write-Host ""
    if ($deployCmd) {
        Write-Host "Deploy command: $deployCmd" -ForegroundColor Yellow
        if (Get-Confirmation "Would you like to customize it?" $false) {
            $deployCmd = Get-Input "Deploy command" $deployCmd
        }
    }
}

# Save config
Write-Step "Step 4/4: Saving Configuration"

$config = New-Config -Platform $platform -AppUrl $appUrl -StagingUrl $stagingUrl -BuildCmd $buildCmd -DeployCmd $deployCmd -StagingDeployCmd $stagingDeployCmd
Set-Content -Path $ConfigFile -Value $config -Encoding UTF8

Write-Host "  Configuration saved to: $ConfigFile" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "               Installation Complete!                           " -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Files installed:" -ForegroundColor White
Write-Host "  Skill:  $SkillsDir\ship.md"
Write-Host "  Config: $ConfigFile"
Write-Host ""
Write-Host "Your configuration:" -ForegroundColor White
Write-Host "  Platform: $platform"
if ($appUrl) {
    Write-Host "  URL: $appUrl"
}
if ($stagingUrl -and $stagingUrl -ne "none") {
    Write-Host "  Staging: $stagingUrl"
}
Write-Host ""
Write-Host "Usage:" -ForegroundColor White
Write-Host '  /ship                    # Auto commit, push, build, deploy'
Write-Host '  /ship "feat: feature"    # Custom commit message'
if ($stagingUrl -and $stagingUrl -ne "none") {
    Write-Host '  /ship --env=staging      # Deploy to staging'
}
Write-Host '  /ship --dry-run          # Preview without executing'
Write-Host '  /ship --no-deploy        # Commit and push only'
Write-Host ""
Write-Host "Open Claude Code and type /ship to get started!" -ForegroundColor Cyan
Write-Host ""
