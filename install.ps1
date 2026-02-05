# Claude Ship Command Installer for Windows
# Run in PowerShell as Administrator

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║     Claude Ship Command Installer      ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# Set directories
$ClaudeDir = "$env:USERPROFILE\.claude"
$SkillsDir = "$ClaudeDir\skills"

# Create directories if they don't exist
Write-Host "Creating directories..." -ForegroundColor Yellow
if (-not (Test-Path $SkillsDir)) {
    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
    Write-Host "  Created $SkillsDir" -ForegroundColor Green
}

# Repository URL
$RepoUrl = "https://raw.githubusercontent.com/YOUR_USERNAME/claude-ship-command/main"

# Download the skill file
Write-Host "Downloading ship.md..." -ForegroundColor Yellow
try {
    $ProgressPreference = 'SilentlyContinue'  # Speed up Invoke-WebRequest
    Invoke-WebRequest -Uri "$RepoUrl/ship.md" -OutFile "$SkillsDir\ship.md" -UseBasicParsing
    Write-Host "  Downloaded ship.md" -ForegroundColor Green
} catch {
    Write-Host "  Error downloading ship.md: $_" -ForegroundColor Red
    exit 1
}

# Check if config already exists
$ConfigFile = "$ClaudeDir\ship.config.json"
if (Test-Path $ConfigFile) {
    Write-Host "Config file already exists at $ConfigFile" -ForegroundColor Yellow
    Write-Host "  Skipping config creation (your existing config is preserved)" -ForegroundColor Yellow
} else {
    # Create default config
    Write-Host "Creating default config..." -ForegroundColor Yellow
    $DefaultConfig = @'
{
  "build": {
    "command": "npm run build",
    "enabled": true
  },
  "deploy": {
    "command": null,
    "enabled": false
  },
  "verify": {
    "url": null,
    "enabled": false
  },
  "git": {
    "addAll": true,
    "pushUpstream": true
  }
}
'@
    Set-Content -Path $ConfigFile -Value $DefaultConfig -Encoding UTF8
    Write-Host "  Created default config" -ForegroundColor Green
}

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow

$AllGood = $true

if (Test-Path "$SkillsDir\ship.md") {
    Write-Host "  ship.md installed successfully" -ForegroundColor Green
} else {
    Write-Host "  ship.md installation failed" -ForegroundColor Red
    $AllGood = $false
}

if (Test-Path $ConfigFile) {
    Write-Host "  Config file exists" -ForegroundColor Green
} else {
    Write-Host "  Config file missing" -ForegroundColor Red
    $AllGood = $false
}

if (-not $AllGood) {
    Write-Host ""
    Write-Host "Installation failed!" -ForegroundColor Red
    exit 1
}

# Success message
Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║      Installation Complete!            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Files installed:" -ForegroundColor White
Write-Host "  Skill:  $SkillsDir\ship.md" -ForegroundColor Cyan
Write-Host "  Config: $ConfigFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Edit $ConfigFile to customize for your project"
Write-Host "2. Open Claude Code and type /ship to use the command"
Write-Host ""
Write-Host "Example configurations:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Firebase:"
Write-Host '    "deploy": { "command": "firebase deploy", "enabled": true }'
Write-Host ""
Write-Host "  Vercel:"
Write-Host '    "deploy": { "command": "vercel --prod", "enabled": true }'
Write-Host ""
Write-Host "  Netlify:"
Write-Host '    "deploy": { "command": "netlify deploy --prod", "enabled": true }'
Write-Host ""
Write-Host "For more configurations, see: https://github.com/YOUR_USERNAME/claude-ship-command" -ForegroundColor Blue
