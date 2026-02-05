# Claude Ship Command - Interactive Installer for Windows
# Run in PowerShell (Administrator recommended for system-wide install)

$ErrorActionPreference = "Stop"

# Config
$ClaudeDir = "$env:USERPROFILE\.claude"
$SkillsDir = "$ClaudeDir\skills"
$ConfigFile = "$ClaudeDir\ship.config.json"
$RepoUrl = "https://raw.githubusercontent.com/sterlingsky/claude-ship-command/main"

# Arrays for multi-destination support
$script:SelectedPlatforms = @()
$script:DeployCommands = @()
$script:VerifyUrls = @()

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

function Select-OptionIndex {
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
            return $num - 1
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

function Get-PlatformDefaults {
    param([string]$Platform)

    $defaults = @{
        Build = ""
        Deploy = ""
        StagingDeploy = ""
        Url = ""
        StagingUrl = ""
    }

    switch -Wildcard ($Platform) {
        "Firebase (Hosting + Functions)" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "firebase deploy --only functions,hosting"
            $defaults.StagingDeploy = "firebase deploy --only functions,hosting --project staging"
            $defaults.Url = "https://your-app.web.app"
            $defaults.StagingUrl = "https://your-app-staging.web.app"
        }
        "Google Cloud Run" {
            $defaults.Build = "gcloud builds submit --tag `$REGION-docker.pkg.dev/`$PROJECT_ID/`$REPO_NAME/your-app:`$(git rev-parse --short HEAD)"
            $defaults.Deploy = "gcloud run deploy your-app --image `$REGION-docker.pkg.dev/`$PROJECT_ID/`$REPO_NAME/your-app:`$(git rev-parse --short HEAD) --platform managed --region `$REGION --allow-unauthenticated"
            $defaults.StagingDeploy = "gcloud run deploy your-app-staging --image `$REGION-docker.pkg.dev/`$PROJECT_ID/`$REPO_NAME/your-app:`$(git rev-parse --short HEAD) --platform managed --region `$REGION --allow-unauthenticated"
            $defaults.Url = "https://your-app-xxxxx-uc.a.run.app"
            $defaults.StagingUrl = "https://your-app-staging-xxxxx-uc.a.run.app"
        }
        "Vercel" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "vercel --prod"
            $defaults.StagingDeploy = "vercel"
            $defaults.Url = "https://your-app.vercel.app"
            $defaults.StagingUrl = ""
        }
        "Netlify" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "netlify deploy --prod --dir=dist"
            $defaults.StagingDeploy = "netlify deploy --dir=dist"
            $defaults.Url = "https://your-app.netlify.app"
            $defaults.StagingUrl = ""
        }
        "Cloudflare Pages" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "wrangler pages deploy dist --project-name=your-app"
            $defaults.StagingDeploy = "wrangler pages deploy dist --project-name=your-app-staging"
            $defaults.Url = "https://your-app.pages.dev"
            $defaults.StagingUrl = ""
        }
        "AWS Amplify" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "amplify publish --yes"
            $defaults.StagingDeploy = "amplify publish --yes --envName dev"
            $defaults.Url = "https://main.your-app-id.amplifyapp.com"
            $defaults.StagingUrl = "https://dev.your-app-id.amplifyapp.com"
        }
        "AWS S3 + CloudFront" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "aws s3 sync dist/ s3://your-bucket --delete"
            $defaults.StagingDeploy = "aws s3 sync dist/ s3://your-bucket-staging --delete"
            $defaults.Url = "https://your-cloudfront-domain.cloudfront.net"
            $defaults.StagingUrl = ""
        }
        "Azure Static Web Apps" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "swa deploy ./dist"
            $defaults.StagingDeploy = "swa deploy ./dist --env preview"
            $defaults.Url = "https://your-app.azurestaticapps.net"
            $defaults.StagingUrl = ""
        }
        "GitHub Pages" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "npx gh-pages -d dist"
            $defaults.StagingDeploy = ""
            $defaults.Url = "https://your-username.github.io/your-repo"
            $defaults.StagingUrl = ""
        }
        "Docker + Kubernetes" {
            $defaults.Build = "docker build -t your-app:latest ."
            $defaults.Deploy = "kubectl apply -f k8s/"
            $defaults.StagingDeploy = "kubectl apply -f k8s/ --context staging"
            $defaults.Url = "https://your-app.your-cluster.com"
            $defaults.StagingUrl = "https://staging.your-app.your-cluster.com"
        }
        "Heroku" {
            $defaults.Build = ""
            $defaults.Deploy = "git push heroku HEAD:main"
            $defaults.StagingDeploy = "git push heroku-staging HEAD:main"
            $defaults.Url = "https://your-app.herokuapp.com"
            $defaults.StagingUrl = "https://your-app-staging.herokuapp.com"
        }
        "Fly.io" {
            $defaults.Build = ""
            $defaults.Deploy = "fly deploy"
            $defaults.StagingDeploy = "fly deploy --app your-app-staging"
            $defaults.Url = "https://your-app.fly.dev"
            $defaults.StagingUrl = "https://your-app-staging.fly.dev"
        }
        "Railway" {
            $defaults.Build = ""
            $defaults.Deploy = "railway up"
            $defaults.StagingDeploy = "railway up --environment staging"
            $defaults.Url = "https://your-app.railway.app"
            $defaults.StagingUrl = "https://your-app-staging.railway.app"
        }
        "Render" {
            $defaults.Build = "npm run build"
            $defaults.Deploy = "# Render auto-deploys from git"
            $defaults.StagingDeploy = ""
            $defaults.Url = "https://your-app.onrender.com"
            $defaults.StagingUrl = ""
        }
    }

    return $defaults
}

function New-SingleConfig {
    param(
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

function New-MultiConfig {
    param(
        [string]$BuildCmd
    )

    $targets = @()
    for ($i = 0; $i -lt $script:SelectedPlatforms.Count; $i++) {
        $targets += @{
            name = $script:SelectedPlatforms[$i]
            command = $script:DeployCommands[$i]
            verify = $script:VerifyUrls[$i]
        }
    }

    $config = @{
        build = @{
            command = $BuildCmd
            enabled = $true
        }
        deploy = @{
            targets = $targets
            parallel = $false
            stopOnFailure = $true
            enabled = $true
        }
        verify = @{
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
        defaultEnvironment = "production"
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
Write-Step "Step 1/5: Downloading ship.md"
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
Write-Step "Step 2/5: Select Your Platform(s)"

$platforms = @(
    "Firebase (Hosting + Functions)",
    "Google Cloud Run",
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

$selectedIndex = Select-OptionIndex "Which platform do you deploy to?" $platforms
$firstPlatform = $platforms[$selectedIndex]
Write-Host ""
Write-Host "  Selected: $firstPlatform" -ForegroundColor Green

# Check for git-only
if ($firstPlatform -like "Git only*") {
    Write-Step "Step 3/5: Configuration"
    Write-Host "Git-only mode selected. No deploy or verify configuration needed."

    Write-Step "Step 4/5: Saving Configuration"
    $config = @{
        build = @{
            command = ""
            enabled = $false
        }
        deploy = @{
            enabled = $false
        }
        git = @{
            addAll = $true
            pushUpstream = $true
        }
    } | ConvertTo-Json -Depth 10

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
    Write-Host "Usage:" -ForegroundColor White
    Write-Host '  /ship                    # Auto commit and push'
    Write-Host '  /ship "feat: feature"    # Custom commit message'
    Write-Host ""
    Write-Host "Open Claude Code and type /ship to get started!" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

# Store first platform
$script:SelectedPlatforms += $firstPlatform
$defaults = Get-PlatformDefaults $firstPlatform
$script:DeployCommands += $defaults.Deploy
$script:VerifyUrls += $defaults.Url
$buildCmd = $defaults.Build

# Ask about additional destinations
Write-Host ""
$multiDest = $false
if (Get-Confirmation "Do you want to deploy to additional destinations?" $false) {
    $multiDest = $true

    while ($true) {
        # Filter out already selected platforms and special options
        $availablePlatforms = @()
        foreach ($p in $platforms) {
            if ($p -notlike "Git only*" -and $p -notlike "Custom*") {
                $alreadySelected = $false
                foreach ($selected in $script:SelectedPlatforms) {
                    if ($p -eq $selected) {
                        $alreadySelected = $true
                        break
                    }
                }
                if (-not $alreadySelected) {
                    $availablePlatforms += $p
                }
            }
        }

        if ($availablePlatforms.Count -eq 0) {
            Write-Host "No more platforms available." -ForegroundColor Yellow
            break
        }

        Write-Host ""
        Write-Host "Currently selected:" -ForegroundColor White
        foreach ($p in $script:SelectedPlatforms) {
            Write-Host "  * $p"
        }
        Write-Host ""

        $selectedIndex = Select-OptionIndex "Select another platform:" $availablePlatforms
        $additionalPlatform = $availablePlatforms[$selectedIndex]
        Write-Host ""
        Write-Host "  Added: $additionalPlatform" -ForegroundColor Green

        $script:SelectedPlatforms += $additionalPlatform
        $defaults = Get-PlatformDefaults $additionalPlatform
        $script:DeployCommands += $defaults.Deploy
        $script:VerifyUrls += $defaults.Url

        Write-Host ""
        if (-not (Get-Confirmation "Add another destination?" $false)) {
            break
        }
    }
}

# Configure URLs for each destination
Write-Step "Step 3/5: Configure Your Destinations"

for ($i = 0; $i -lt $script:SelectedPlatforms.Count; $i++) {
    $platform = $script:SelectedPlatforms[$i]
    Write-Host ""
    Write-Host "[$($i + 1)/$($script:SelectedPlatforms.Count)] $platform" -ForegroundColor White

    $defaults = Get-PlatformDefaults $platform

    # Verify URL
    Write-Host "Example URL: $($defaults.Url)"
    $url = Get-Input "Verify URL" $defaults.Url
    $script:VerifyUrls[$i] = $url

    # Deploy command
    Write-Host "Default command: $($defaults.Deploy)"
    if (Get-Confirmation "Customize deploy command?" $false) {
        $cmd = Get-Input "Deploy command" $defaults.Deploy
        $script:DeployCommands[$i] = $cmd
    }
}

# Build command
Write-Step "Step 4/5: Build Configuration"

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

# Generate and save config
Write-Step "Step 5/5: Saving Configuration"

if ($script:SelectedPlatforms.Count -eq 1) {
    # Single destination - check for staging
    $defaults = Get-PlatformDefaults $script:SelectedPlatforms[0]
    Write-Host ""
    if (Get-Confirmation "Do you have a staging environment?" $false) {
        if ($defaults.StagingUrl) {
            Write-Host ""
            Write-Host "Example: $($defaults.StagingUrl)"
        }
        $stagingUrl = Get-Input "Staging URL" $defaults.StagingUrl
        $config = New-SingleConfig -AppUrl $script:VerifyUrls[0] -StagingUrl $stagingUrl -BuildCmd $buildCmd -DeployCmd $script:DeployCommands[0] -StagingDeployCmd $defaults.StagingDeploy
    } else {
        $config = New-SingleConfig -AppUrl $script:VerifyUrls[0] -StagingUrl "none" -BuildCmd $buildCmd -DeployCmd $script:DeployCommands[0] -StagingDeployCmd ""
    }
} else {
    # Multi-destination
    $config = New-MultiConfig -BuildCmd $buildCmd
}

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
if ($script:SelectedPlatforms.Count -eq 1) {
    Write-Host "  Platform: $($script:SelectedPlatforms[0])"
    Write-Host "  URL: $($script:VerifyUrls[0])"
} else {
    Write-Host "  Destinations:"
    for ($i = 0; $i -lt $script:SelectedPlatforms.Count; $i++) {
        Write-Host "    * $($script:SelectedPlatforms[$i]): $($script:VerifyUrls[$i])"
    }
}
Write-Host ""
Write-Host "Usage:" -ForegroundColor White
Write-Host '  /ship                    # Auto commit, push, build, deploy'
Write-Host '  /ship "feat: feature"    # Custom commit message'
Write-Host '  /ship --dry-run          # Preview without executing'
Write-Host '  /ship --no-deploy        # Commit and push only'
Write-Host ""
Write-Host "Open Claude Code and type /ship to get started!" -ForegroundColor Cyan
Write-Host ""
