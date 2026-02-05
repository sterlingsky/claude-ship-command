#!/bin/bash

# Claude Ship Command Installer
# Supports: macOS, Linux, WSL

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║     Claude Ship Command Installer      ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Detect OS
OS="unknown"
case "$(uname -s)" in
    Linux*)     OS="linux";;
    Darwin*)    OS="macos";;
    CYGWIN*|MINGW*|MSYS*) OS="windows";;
esac

echo -e "${YELLOW}Detected OS:${NC} $OS"

# Set Claude config directory
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"

# Create directories if they don't exist
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$SKILLS_DIR"

# Download the skill file
echo -e "${YELLOW}Downloading ship.md...${NC}"
REPO_URL="https://raw.githubusercontent.com/YOUR_USERNAME/claude-ship-command/main"

if command -v curl &> /dev/null; then
    curl -fsSL "$REPO_URL/ship.md" -o "$SKILLS_DIR/ship.md"
elif command -v wget &> /dev/null; then
    wget -q "$REPO_URL/ship.md" -O "$SKILLS_DIR/ship.md"
else
    echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Installed ship.md to $SKILLS_DIR/ship.md"

# Check if config already exists
CONFIG_FILE="$CLAUDE_DIR/ship.config.json"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Config file already exists at $CONFIG_FILE${NC}"
    echo -e "${YELLOW}Skipping config creation (your existing config is preserved)${NC}"
else
    # Create default config
    echo -e "${YELLOW}Creating default config...${NC}"
    cat > "$CONFIG_FILE" << 'EOF'
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
EOF
    echo -e "${GREEN}✓${NC} Created default config at $CONFIG_FILE"
fi

# Verify installation
echo ""
echo -e "${YELLOW}Verifying installation...${NC}"

if [ -f "$SKILLS_DIR/ship.md" ]; then
    echo -e "${GREEN}✓${NC} ship.md installed successfully"
else
    echo -e "${RED}✗${NC} ship.md installation failed"
    exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓${NC} Config file exists"
else
    echo -e "${RED}✗${NC} Config file missing"
    exit 1
fi

# Success message
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Installation Complete! 🚀         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Files installed:"
echo -e "  ${BLUE}Skill:${NC}  $SKILLS_DIR/ship.md"
echo -e "  ${BLUE}Config:${NC} $CONFIG_FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit $CONFIG_FILE to customize for your project"
echo "2. Open Claude Code and type /ship to use the command"
echo ""
echo -e "${YELLOW}Example configurations:${NC}"
echo ""
echo "  Firebase:"
echo '    "deploy": { "command": "firebase deploy", "enabled": true }'
echo ""
echo "  Vercel:"
echo '    "deploy": { "command": "vercel --prod", "enabled": true }'
echo ""
echo "  Netlify:"
echo '    "deploy": { "command": "netlify deploy --prod", "enabled": true }'
echo ""
echo -e "For more configurations, see: ${BLUE}https://github.com/YOUR_USERNAME/claude-ship-command${NC}"
