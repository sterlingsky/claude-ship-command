#!/bin/bash

# Claude Ship Command - Interactive Installer
# Supports: macOS, Linux, WSL

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Config
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
CONFIG_FILE="$CLAUDE_DIR/ship.config.json"
REPO_URL="https://raw.githubusercontent.com/Sterling-Sky/claude-ship-command/main"

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}        ${BOLD}Claude Ship Command - Interactive Setup${NC}           ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"
}

# Check for required tools
check_requirements() {
    local missing=()

    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing+=("curl or wget")
    fi

    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing required tools: ${missing[*]}${NC}"
        echo "Please install them and try again."
        exit 1
    fi
}

# Download file with curl or wget
download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl &> /dev/null; then
        curl -fsSL "$url" -o "$dest"
    else
        wget -q "$url" -O "$dest"
    fi
}

# Prompt for selection from list
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0

    echo -e "${YELLOW}$prompt${NC}"
    echo ""

    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done

    echo ""
    while true; do
        read -p "Enter number (1-${#options[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            selected=$((choice-1))
            break
        fi
        echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#options[@]}.${NC}"
    done

    echo "${options[$selected]}"
}

# Prompt for yes/no
confirm() {
    local prompt="$1"
    local default="${2:-y}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -p "$prompt" response
    response=${response:-$default}

    [[ "$response" =~ ^[Yy] ]]
}

# Prompt for input with default
prompt_input() {
    local prompt="$1"
    local default="$2"
    local value

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        value=${value:-$default}
    else
        read -p "$prompt: " value
    fi

    echo "$value"
}

# Generate config based on selections
generate_config() {
    local platform="$1"
    local app_url="$2"
    local staging_url="$3"
    local build_cmd="$4"
    local deploy_cmd="$5"
    local staging_deploy_cmd="$6"

    local config='{
  "build": {
    "command": "'$build_cmd'",
    "enabled": true
  },
  "deploy": {
    "command": "'$deploy_cmd'",
    "enabled": true
  },
  "verify": {
    "url": "'$app_url'",
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
  }'

    # Add environments if staging URL provided
    if [ -n "$staging_url" ] && [ "$staging_url" != "none" ]; then
        config="$config"',
  "environments": {
    "production": {
      "deploy": { "command": "'$deploy_cmd'" },
      "verify": { "url": "'$app_url'" },
      "protectedBranches": ["main", "master"]
    },
    "staging": {
      "deploy": { "command": "'$staging_deploy_cmd'" },
      "verify": { "url": "'$staging_url'" }
    }
  },
  "defaultEnvironment": "production"'
    fi

    config="$config"'
}'

    echo "$config"
}

# Main installation flow
main() {
    print_header
    check_requirements

    # Create directories
    mkdir -p "$SKILLS_DIR"

    # Download skill file
    print_step "Step 1/4: Downloading ship.md"
    download_file "$REPO_URL/ship.md" "$SKILLS_DIR/ship.md"
    echo -e "${GREEN}✓${NC} Downloaded ship.md to $SKILLS_DIR/"

    # Check for existing config
    if [ -f "$CONFIG_FILE" ]; then
        print_step "Existing Configuration Found"
        echo "Found existing config at: $CONFIG_FILE"
        echo ""
        if ! confirm "Do you want to replace it with a new configuration?"; then
            echo -e "\n${GREEN}✓${NC} Keeping existing configuration."
            echo -e "\n${GREEN}Installation complete!${NC}"
            echo "Type /ship in Claude Code to use the command."
            exit 0
        fi
        echo ""
    fi

    # Interactive configuration
    print_step "Step 2/4: Select Your Platform"

    platforms=(
        "Firebase (Hosting + Functions)"
        "Vercel"
        "Netlify"
        "Cloudflare Pages"
        "AWS Amplify"
        "AWS S3 + CloudFront"
        "Azure Static Web Apps"
        "GitHub Pages"
        "Docker + Kubernetes"
        "Heroku"
        "Fly.io"
        "Railway"
        "Render"
        "Git only (no deploy)"
        "Custom (I'll configure manually)"
    )

    platform=$(select_option "Which platform do you deploy to?" "${platforms[@]}")
    echo -e "\n${GREEN}✓${NC} Selected: $platform"

    # Set defaults based on platform
    case "$platform" in
        "Firebase"*)
            build_cmd="npm run build"
            deploy_cmd="firebase deploy --only functions,hosting"
            staging_deploy_cmd="firebase deploy --only functions,hosting --project staging"
            url_example="https://your-app.web.app"
            staging_example="https://your-app-staging.web.app"
            ;;
        "Vercel")
            build_cmd="npm run build"
            deploy_cmd="vercel --prod"
            staging_deploy_cmd="vercel"
            url_example="https://your-app.vercel.app"
            staging_example=""
            ;;
        "Netlify")
            build_cmd="npm run build"
            deploy_cmd="netlify deploy --prod --dir=dist"
            staging_deploy_cmd="netlify deploy --dir=dist"
            url_example="https://your-app.netlify.app"
            staging_example=""
            ;;
        "Cloudflare Pages")
            build_cmd="npm run build"
            deploy_cmd="wrangler pages deploy dist --project-name=your-app"
            staging_deploy_cmd="wrangler pages deploy dist --project-name=your-app-staging"
            url_example="https://your-app.pages.dev"
            staging_example=""
            ;;
        "AWS Amplify")
            build_cmd="npm run build"
            deploy_cmd="amplify publish --yes"
            staging_deploy_cmd="amplify publish --yes --envName dev"
            url_example="https://main.your-app-id.amplifyapp.com"
            staging_example="https://dev.your-app-id.amplifyapp.com"
            ;;
        "AWS S3"*)
            build_cmd="npm run build"
            deploy_cmd="aws s3 sync dist/ s3://your-bucket --delete"
            staging_deploy_cmd="aws s3 sync dist/ s3://your-bucket-staging --delete"
            url_example="https://your-cloudfront-domain.cloudfront.net"
            staging_example=""
            ;;
        "Azure Static Web Apps")
            build_cmd="npm run build"
            deploy_cmd="swa deploy ./dist"
            staging_deploy_cmd="swa deploy ./dist --env preview"
            url_example="https://your-app.azurestaticapps.net"
            staging_example=""
            ;;
        "GitHub Pages")
            build_cmd="npm run build"
            deploy_cmd="npx gh-pages -d dist"
            staging_deploy_cmd=""
            url_example="https://your-username.github.io/your-repo"
            staging_example=""
            ;;
        "Docker"*)
            build_cmd="docker build -t your-app:latest ."
            deploy_cmd="kubectl apply -f k8s/"
            staging_deploy_cmd="kubectl apply -f k8s/ --context staging"
            url_example="https://your-app.your-cluster.com"
            staging_example="https://staging.your-app.your-cluster.com"
            ;;
        "Heroku")
            build_cmd=""
            deploy_cmd="git push heroku HEAD:main"
            staging_deploy_cmd="git push heroku-staging HEAD:main"
            url_example="https://your-app.herokuapp.com"
            staging_example="https://your-app-staging.herokuapp.com"
            ;;
        "Fly.io")
            build_cmd=""
            deploy_cmd="fly deploy"
            staging_deploy_cmd="fly deploy --app your-app-staging"
            url_example="https://your-app.fly.dev"
            staging_example="https://your-app-staging.fly.dev"
            ;;
        "Railway")
            build_cmd=""
            deploy_cmd="railway up"
            staging_deploy_cmd="railway up --environment staging"
            url_example="https://your-app.railway.app"
            staging_example="https://your-app-staging.railway.app"
            ;;
        "Render")
            build_cmd="npm run build"
            deploy_cmd="# Render auto-deploys from git"
            staging_deploy_cmd=""
            url_example="https://your-app.onrender.com"
            staging_example=""
            ;;
        "Git only"*)
            build_cmd=""
            deploy_cmd=""
            staging_deploy_cmd=""
            url_example=""
            staging_example=""
            ;;
        "Custom"*)
            build_cmd="npm run build"
            deploy_cmd=""
            staging_deploy_cmd=""
            url_example=""
            staging_example=""
            ;;
    esac

    # Skip URL questions for git-only
    if [[ "$platform" == "Git only"* ]]; then
        print_step "Step 3/4: Configuration"
        echo "Git-only mode selected. No deploy or verify configuration needed."
        app_url=""
        staging_url="none"
    else
        print_step "Step 3/4: Configure Your URLs"

        # Production URL
        if [ -n "$url_example" ]; then
            echo -e "${YELLOW}What is your production URL?${NC}"
            echo -e "Example: $url_example"
        fi
        app_url=$(prompt_input "Production URL" "$url_example")

        # Staging environment
        echo ""
        if confirm "Do you have a staging environment?" "n"; then
            if [ -n "$staging_example" ]; then
                echo -e "\nExample: $staging_example"
            fi
            staging_url=$(prompt_input "Staging URL" "$staging_example")
        else
            staging_url="none"
        fi
    fi

    # Build command customization
    if [[ "$platform" != "Git only"* ]]; then
        echo ""
        if [ -n "$build_cmd" ]; then
            echo -e "${YELLOW}Build command:${NC} $build_cmd"
            if confirm "Would you like to customize it?" "n"; then
                build_cmd=$(prompt_input "Build command" "$build_cmd")
            fi
        else
            if confirm "Do you need a build step?" "n"; then
                build_cmd=$(prompt_input "Build command" "npm run build")
            fi
        fi

        # Deploy command customization
        echo ""
        if [ -n "$deploy_cmd" ]; then
            echo -e "${YELLOW}Deploy command:${NC} $deploy_cmd"
            if confirm "Would you like to customize it?" "n"; then
                deploy_cmd=$(prompt_input "Deploy command" "$deploy_cmd")
            fi
        fi
    fi

    # Generate and save config
    print_step "Step 4/4: Saving Configuration"

    config=$(generate_config "$platform" "$app_url" "$staging_url" "$build_cmd" "$deploy_cmd" "$staging_deploy_cmd")
    echo "$config" > "$CONFIG_FILE"

    echo -e "${GREEN}✓${NC} Configuration saved to: $CONFIG_FILE"

    # Summary
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}               ${BOLD}Installation Complete!${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Files installed:${NC}"
    echo "  Skill:  $SKILLS_DIR/ship.md"
    echo "  Config: $CONFIG_FILE"
    echo ""
    echo -e "${BOLD}Your configuration:${NC}"
    echo "  Platform: $platform"
    if [ -n "$app_url" ]; then
        echo "  URL: $app_url"
    fi
    if [ "$staging_url" != "none" ] && [ -n "$staging_url" ]; then
        echo "  Staging: $staging_url"
    fi
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  /ship                    # Auto commit, push, build, deploy"
    echo "  /ship \"feat: feature\"    # Custom commit message"
    if [ "$staging_url" != "none" ] && [ -n "$staging_url" ]; then
        echo "  /ship --env=staging      # Deploy to staging"
    fi
    echo "  /ship --dry-run          # Preview without executing"
    echo "  /ship --no-deploy        # Commit and push only"
    echo ""
    echo -e "${CYAN}Open Claude Code and type /ship to get started!${NC}"
    echo ""
}

# Run main function
main
