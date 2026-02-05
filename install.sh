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
REPO_URL="https://raw.githubusercontent.com/sterlingsky/claude-ship-command/main"

# Expected SHA256 checksums for integrity verification
SHIP_MD_SHA256="SKIP"  # Set to actual hash in releases, "SKIP" for development

# Arrays for multi-destination support
declare -a SELECTED_PLATFORMS
declare -a DEPLOY_COMMANDS
declare -a VERIFY_URLS

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

# Download file with curl or wget (with verification)
download_file() {
    local url="$1"
    local dest="$2"
    local expected_hash="${3:-}"
    local temp_file
    temp_file=$(mktemp)

    # Download to temp file first
    if command -v curl &> /dev/null; then
        if ! curl -fsSL "$url" -o "$temp_file" 2>/dev/null; then
            rm -f "$temp_file"
            echo -e "${RED}ERROR: Failed to download $url${NC}" >&2
            return 1
        fi
    else
        if ! wget -q "$url" -O "$temp_file" 2>/dev/null; then
            rm -f "$temp_file"
            echo -e "${RED}ERROR: Failed to download $url${NC}" >&2
            return 1
        fi
    fi

    # Verify file is not empty
    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        echo -e "${RED}ERROR: Downloaded file is empty${NC}" >&2
        return 1
    fi

    # Verify checksum if provided and not "SKIP"
    if [ -n "$expected_hash" ] && [ "$expected_hash" != "SKIP" ]; then
        local actual_hash
        if command -v sha256sum &> /dev/null; then
            actual_hash=$(sha256sum "$temp_file" | cut -d ' ' -f1)
        elif command -v shasum &> /dev/null; then
            actual_hash=$(shasum -a 256 "$temp_file" | cut -d ' ' -f1)
        else
            echo -e "${YELLOW}WARNING: Cannot verify checksum (sha256sum/shasum not found)${NC}" >&2
            actual_hash="$expected_hash"  # Skip verification
        fi

        if [ "$actual_hash" != "$expected_hash" ]; then
            rm -f "$temp_file"
            echo -e "${RED}ERROR: Checksum mismatch - file may be corrupted or tampered${NC}" >&2
            echo -e "${RED}Expected: $expected_hash${NC}" >&2
            echo -e "${RED}Actual:   $actual_hash${NC}" >&2
            return 1
        fi
    fi

    # Atomic move to destination
    mv "$temp_file" "$dest"
}

# Prompt for selection from list (returns index)
select_option_index() {
    local prompt="$1"
    shift
    local options=("$@")

    echo -e "${YELLOW}$prompt${NC}"
    echo ""

    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}"
    done

    echo ""
    while true; do
        read -p "Enter number (1-${#options[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo $((choice-1))
            return
        fi
        echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#options[@]}.${NC}"
    done
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

# Escape string for JSON (prevents injection)
json_escape() {
    local str="$1"
    # Escape backslashes first, then quotes, then control characters
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Get platform defaults
get_platform_defaults() {
    local platform="$1"

    case "$platform" in
        "Firebase (Hosting + Functions)")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="firebase deploy --only functions,hosting"
            PLATFORM_STAGING_DEPLOY="firebase deploy --only functions,hosting --project staging"
            PLATFORM_URL="https://your-app.web.app"
            PLATFORM_STAGING_URL="https://your-app-staging.web.app"
            ;;
        "Google Cloud Run")
            PLATFORM_BUILD="gcloud builds submit --tag \$REGION-docker.pkg.dev/\$PROJECT_ID/\$REPO_NAME/your-app:\$(git rev-parse --short HEAD)"
            PLATFORM_DEPLOY="gcloud run deploy your-app --image \$REGION-docker.pkg.dev/\$PROJECT_ID/\$REPO_NAME/your-app:\$(git rev-parse --short HEAD) --platform managed --region \$REGION --allow-unauthenticated"
            PLATFORM_STAGING_DEPLOY="gcloud run deploy your-app-staging --image \$REGION-docker.pkg.dev/\$PROJECT_ID/\$REPO_NAME/your-app:\$(git rev-parse --short HEAD) --platform managed --region \$REGION --allow-unauthenticated"
            PLATFORM_URL="https://your-app-xxxxx-uc.a.run.app"
            PLATFORM_STAGING_URL="https://your-app-staging-xxxxx-uc.a.run.app"
            ;;
        "Vercel")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="vercel --prod"
            PLATFORM_STAGING_DEPLOY="vercel"
            PLATFORM_URL="https://your-app.vercel.app"
            PLATFORM_STAGING_URL=""
            ;;
        "Netlify")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="netlify deploy --prod --dir=dist"
            PLATFORM_STAGING_DEPLOY="netlify deploy --dir=dist"
            PLATFORM_URL="https://your-app.netlify.app"
            PLATFORM_STAGING_URL=""
            ;;
        "Cloudflare Pages")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="wrangler pages deploy dist --project-name=your-app"
            PLATFORM_STAGING_DEPLOY="wrangler pages deploy dist --project-name=your-app-staging"
            PLATFORM_URL="https://your-app.pages.dev"
            PLATFORM_STAGING_URL=""
            ;;
        "AWS Amplify")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="amplify publish --yes"
            PLATFORM_STAGING_DEPLOY="amplify publish --yes --envName dev"
            PLATFORM_URL="https://main.your-app-id.amplifyapp.com"
            PLATFORM_STAGING_URL="https://dev.your-app-id.amplifyapp.com"
            ;;
        "AWS S3 + CloudFront")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="aws s3 sync dist/ s3://your-bucket --delete"
            PLATFORM_STAGING_DEPLOY="aws s3 sync dist/ s3://your-bucket-staging --delete"
            PLATFORM_URL="https://your-cloudfront-domain.cloudfront.net"
            PLATFORM_STAGING_URL=""
            ;;
        "Azure Static Web Apps")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="swa deploy ./dist"
            PLATFORM_STAGING_DEPLOY="swa deploy ./dist --env preview"
            PLATFORM_URL="https://your-app.azurestaticapps.net"
            PLATFORM_STAGING_URL=""
            ;;
        "GitHub Pages")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="npx gh-pages -d dist"
            PLATFORM_STAGING_DEPLOY=""
            PLATFORM_URL="https://your-username.github.io/your-repo"
            PLATFORM_STAGING_URL=""
            ;;
        "Docker + Kubernetes")
            PLATFORM_BUILD="docker build -t your-app:latest ."
            PLATFORM_DEPLOY="kubectl apply -f k8s/"
            PLATFORM_STAGING_DEPLOY="kubectl apply -f k8s/ --context staging"
            PLATFORM_URL="https://your-app.your-cluster.com"
            PLATFORM_STAGING_URL="https://staging.your-app.your-cluster.com"
            ;;
        "Heroku")
            PLATFORM_BUILD=""
            PLATFORM_DEPLOY="git push heroku HEAD:main"
            PLATFORM_STAGING_DEPLOY="git push heroku-staging HEAD:main"
            PLATFORM_URL="https://your-app.herokuapp.com"
            PLATFORM_STAGING_URL="https://your-app-staging.herokuapp.com"
            ;;
        "Fly.io")
            PLATFORM_BUILD=""
            PLATFORM_DEPLOY="fly deploy"
            PLATFORM_STAGING_DEPLOY="fly deploy --app your-app-staging"
            PLATFORM_URL="https://your-app.fly.dev"
            PLATFORM_STAGING_URL="https://your-app-staging.fly.dev"
            ;;
        "Railway")
            PLATFORM_BUILD=""
            PLATFORM_DEPLOY="railway up"
            PLATFORM_STAGING_DEPLOY="railway up --environment staging"
            PLATFORM_URL="https://your-app.railway.app"
            PLATFORM_STAGING_URL="https://your-app-staging.railway.app"
            ;;
        "Render")
            PLATFORM_BUILD="npm run build"
            PLATFORM_DEPLOY="# Render auto-deploys from git"
            PLATFORM_STAGING_DEPLOY=""
            PLATFORM_URL="https://your-app.onrender.com"
            PLATFORM_STAGING_URL=""
            ;;
    esac
}

# Generate single-destination config
generate_single_config() {
    local app_url="$1"
    local staging_url="$2"
    local build_cmd="$3"
    local deploy_cmd="$4"
    local staging_deploy_cmd="$5"

    # Escape all user inputs for JSON safety
    local esc_app_url esc_staging_url esc_build_cmd esc_deploy_cmd esc_staging_deploy_cmd
    esc_app_url=$(json_escape "$app_url")
    esc_staging_url=$(json_escape "$staging_url")
    esc_build_cmd=$(json_escape "$build_cmd")
    esc_deploy_cmd=$(json_escape "$deploy_cmd")
    esc_staging_deploy_cmd=$(json_escape "$staging_deploy_cmd")

    local config='{
  "build": {
    "command": "'"$esc_build_cmd"'",
    "enabled": true
  },
  "deploy": {
    "command": "'"$esc_deploy_cmd"'",
    "enabled": true
  },
  "verify": {
    "url": "'"$esc_app_url"'",
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

    if [ -n "$staging_url" ] && [ "$staging_url" != "none" ]; then
        config="$config"',
  "environments": {
    "production": {
      "deploy": { "command": "'"$esc_deploy_cmd"'" },
      "verify": { "url": "'"$esc_app_url"'" },
      "protectedBranches": ["main", "master"]
    },
    "staging": {
      "deploy": { "command": "'"$esc_staging_deploy_cmd"'" },
      "verify": { "url": "'"$esc_staging_url"'" }
    }
  },
  "defaultEnvironment": "production"'
    fi

    config="$config"'
}'

    echo "$config"
}

# Generate multi-destination config
generate_multi_config() {
    local build_cmd="$1"
    local has_staging="$2"

    # Escape build command
    local esc_build_cmd
    esc_build_cmd=$(json_escape "$build_cmd")

    # Build targets array with escaped values
    local targets=""
    for i in "${!SELECTED_PLATFORMS[@]}"; do
        local esc_name esc_cmd esc_url
        esc_name=$(json_escape "${SELECTED_PLATFORMS[$i]}")
        esc_cmd=$(json_escape "${DEPLOY_COMMANDS[$i]}")
        esc_url=$(json_escape "${VERIFY_URLS[$i]}")

        if [ "$i" -gt 0 ]; then
            targets="$targets,"
        fi
        targets="$targets
      {
        \"name\": \"$esc_name\",
        \"command\": \"$esc_cmd\",
        \"verify\": \"$esc_url\"
      }"
    done

    local config='{
  "build": {
    "command": "'"$esc_build_cmd"'",
    "enabled": true
  },
  "deploy": {
    "targets": ['"$targets"'
    ],
    "parallel": false,
    "stopOnFailure": true,
    "enabled": true
  },
  "verify": {
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
  "defaultEnvironment": "production"
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
    print_step "Step 1/5: Downloading ship.md"
    if ! download_file "$REPO_URL/ship.md" "$SKILLS_DIR/ship.md" "$SHIP_MD_SHA256"; then
        echo -e "${RED}Installation failed: Could not download skill file${NC}"
        exit 1
    fi
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

    # Platform selection
    print_step "Step 2/5: Select Your Platform(s)"

    platforms=(
        "Firebase (Hosting + Functions)"
        "Google Cloud Run"
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

    selected_index=$(select_option_index "Which platform do you deploy to?" "${platforms[@]}")
    first_platform="${platforms[$selected_index]}"
    echo -e "\n${GREEN}✓${NC} Selected: $first_platform"

    # Check for git-only or custom
    if [[ "$first_platform" == "Git only"* ]]; then
        print_step "Step 3/5: Configuration"
        echo "Git-only mode selected. No deploy or verify configuration needed."

        print_step "Step 4/5: Saving Configuration"
        config='{
  "build": {
    "command": "",
    "enabled": false
  },
  "deploy": {
    "enabled": false
  },
  "git": {
    "addAll": true,
    "pushUpstream": true
  }
}'
        # Write config atomically with secure permissions
        local config_temp
        config_temp=$(mktemp "$CLAUDE_DIR/ship.config.XXXXXX")
        echo "$config" > "$config_temp"
        chmod 600 "$config_temp"
        mv "$config_temp" "$CONFIG_FILE"
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
        echo -e "${BOLD}Usage:${NC}"
        echo "  /ship                    # Auto commit and push"
        echo "  /ship \"feat: feature\"    # Custom commit message"
        echo ""
        echo -e "${CYAN}Open Claude Code and type /ship to get started!${NC}"
        echo ""
        exit 0
    fi

    # Store first platform
    SELECTED_PLATFORMS+=("$first_platform")
    get_platform_defaults "$first_platform"
    DEPLOY_COMMANDS+=("$PLATFORM_DEPLOY")
    VERIFY_URLS+=("$PLATFORM_URL")
    build_cmd="$PLATFORM_BUILD"

    # Ask about additional destinations
    echo ""
    multi_dest=false
    if confirm "Do you want to deploy to additional destinations?" "n"; then
        multi_dest=true

        while true; do
            # Filter out already selected platforms and special options
            available_platforms=()
            for p in "${platforms[@]}"; do
                if [[ "$p" != "Git only"* ]] && [[ "$p" != "Custom"* ]]; then
                    already_selected=false
                    for selected in "${SELECTED_PLATFORMS[@]}"; do
                        if [ "$p" = "$selected" ]; then
                            already_selected=true
                            break
                        fi
                    done
                    if ! $already_selected; then
                        available_platforms+=("$p")
                    fi
                fi
            done

            if [ ${#available_platforms[@]} -eq 0 ]; then
                echo -e "${YELLOW}No more platforms available.${NC}"
                break
            fi

            echo ""
            echo -e "${BOLD}Currently selected:${NC}"
            for p in "${SELECTED_PLATFORMS[@]}"; do
                echo "  • $p"
            done
            echo ""

            selected_index=$(select_option_index "Select another platform:" "${available_platforms[@]}")
            additional_platform="${available_platforms[$selected_index]}"
            echo -e "\n${GREEN}✓${NC} Added: $additional_platform"

            SELECTED_PLATFORMS+=("$additional_platform")
            get_platform_defaults "$additional_platform"
            DEPLOY_COMMANDS+=("$PLATFORM_DEPLOY")
            VERIFY_URLS+=("$PLATFORM_URL")

            echo ""
            if ! confirm "Add another destination?" "n"; then
                break
            fi
        done
    fi

    # Configure URLs for each destination
    print_step "Step 3/5: Configure Your Destinations"

    for i in "${!SELECTED_PLATFORMS[@]}"; do
        platform="${SELECTED_PLATFORMS[$i]}"
        echo -e "\n${BOLD}[$((i+1))/${#SELECTED_PLATFORMS[@]}] $platform${NC}"

        get_platform_defaults "$platform"

        # Verify URL
        echo -e "Example URL: ${PLATFORM_URL}"
        url=$(prompt_input "Verify URL" "$PLATFORM_URL")
        VERIFY_URLS[$i]="$url"

        # Deploy command
        echo -e "Default command: ${PLATFORM_DEPLOY}"
        if confirm "Customize deploy command?" "n"; then
            cmd=$(prompt_input "Deploy command" "$PLATFORM_DEPLOY")
            DEPLOY_COMMANDS[$i]="$cmd"
        fi
    done

    # Build command
    print_step "Step 4/5: Build Configuration"

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

    # Generate and save config
    print_step "Step 5/5: Saving Configuration"

    if [ ${#SELECTED_PLATFORMS[@]} -eq 1 ]; then
        # Single destination - check for staging
        get_platform_defaults "${SELECTED_PLATFORMS[0]}"
        echo ""
        if confirm "Do you have a staging environment?" "n"; then
            if [ -n "$PLATFORM_STAGING_URL" ]; then
                echo -e "\nExample: $PLATFORM_STAGING_URL"
            fi
            staging_url=$(prompt_input "Staging URL" "$PLATFORM_STAGING_URL")
            config=$(generate_single_config "${VERIFY_URLS[0]}" "$staging_url" "$build_cmd" "${DEPLOY_COMMANDS[0]}" "$PLATFORM_STAGING_DEPLOY")
        else
            config=$(generate_single_config "${VERIFY_URLS[0]}" "none" "$build_cmd" "${DEPLOY_COMMANDS[0]}" "")
        fi
    else
        # Multi-destination
        config=$(generate_multi_config "$build_cmd" "false")
    fi

    # Write config atomically with secure permissions
    local config_temp
    config_temp=$(mktemp "$CLAUDE_DIR/ship.config.XXXXXX")
    echo "$config" > "$config_temp"
    chmod 600 "$config_temp"
    mv "$config_temp" "$CONFIG_FILE"
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
    if [ ${#SELECTED_PLATFORMS[@]} -eq 1 ]; then
        echo "  Platform: ${SELECTED_PLATFORMS[0]}"
        echo "  URL: ${VERIFY_URLS[0]}"
    else
        echo "  Destinations:"
        for i in "${!SELECTED_PLATFORMS[@]}"; do
            echo "    • ${SELECTED_PLATFORMS[$i]}: ${VERIFY_URLS[$i]}"
        done
    fi
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  /ship                    # Auto commit, push, build, deploy"
    echo "  /ship \"feat: feature\"    # Custom commit message"
    echo "  /ship --dry-run          # Preview without executing"
    echo "  /ship --no-deploy        # Commit and push only"
    echo ""
    echo -e "${CYAN}Open Claude Code and type /ship to get started!${NC}"
    echo ""
}

# Run main function
main
