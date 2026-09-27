#!/bin/bash
# ============================================
# Base Module - Claude + bkit Installation (Mac/Linux)
# ============================================
# This module installs: Homebrew, Node.js, Git, VS Code, Docker, Claude CLI, bkit Plugin

# FR-S3-05a: Source shared color definitions instead of inline
SHARED_DIR="${SHARED_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../shared" 2>/dev/null && pwd)}"
if [ -n "$SHARED_DIR" ] && [ -f "$SHARED_DIR/colors.sh" ]; then
    source "$SHARED_DIR/colors.sh"
else
    # Fallback for remote execution
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'
fi

DOCKER_NEEDS_RESTART=false

# ── Helper: persist a directory to PATH (shell configs + current session) ─────
# Usage: _add_to_path "/some/bin/dir"
_add_to_path() {
    local dir="$1"
    [ -z "$dir" ] && return

    local export_line="export PATH=\"$dir:\$PATH\""

    # Determine which shell config files to update
    local configs
    if [[ "$OSTYPE" == "darwin"* ]]; then
        configs=("$HOME/.zprofile" "$HOME/.zshrc")
    else
        configs=("$HOME/.bashrc" "$HOME/.profile")
    fi

    for _cfg in "${configs[@]}"; do
        # Create file if .zprofile or .zshrc doesn't exist yet
        if [[ "$_cfg" == *".zprofile" ]] || [[ "$_cfg" == *".zshrc" ]] || [ -f "$_cfg" ]; then
            touch "$_cfg" 2>/dev/null || true
            if ! grep -qF "$dir" "$_cfg" 2>/dev/null; then
                echo "$export_line" >> "$_cfg"
            fi
        fi
    done

    # Apply immediately to current session
    export PATH="$dir:$PATH"
}

# ============================================
# 1. Homebrew (Mac only)
# ============================================
echo -e "${YELLOW}[1/7] Checking Homebrew...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Use preflight-detected path, fall back to detecting both
    BREW_BIN="${PREFLIGHT_BREW_PATH:-}/bin/brew"
    if [ ! -f "$BREW_BIN" ]; then
        # Fallback detection
        if [ -f "/opt/homebrew/bin/brew" ]; then
            BREW_BIN="/opt/homebrew/bin/brew"
        elif [ -f "/usr/local/bin/brew" ]; then
            BREW_BIN="/usr/local/bin/brew"
        fi
    fi

    # Add to PATH first (in case installed but not in current session)
    if [ -f "$BREW_BIN" ]; then
        eval "$("$BREW_BIN" shellenv)"
    fi

    # Fix invalidated Xcode CLT (common after macOS upgrade)
    if [[ "${PREFLIGHT_XCODE_NEEDS_REINSTALL:-false}" == true ]]; then
        echo -e "  ${YELLOW}Reinstalling invalid Xcode Command Line Tools...${NC}"
        sudo rm -rf /Library/Developer/CommandLineTools < /dev/tty 2>/dev/null || true
        xcode-select --install 2>/dev/null || true
        sleep 2
        if ! xcrun cc --version &>/dev/null 2>&1; then
            echo -e "  ${YELLOW}Xcode CLT installation dialog may have opened.${NC}"
            echo -e "  ${YELLOW}Complete the installation, then re-run this installer.${NC}"
            exit 1
        fi
    fi

    if ! command -v brew > /dev/null 2>&1; then
        echo -e "  ${GRAY}Installing Homebrew...${NC}"
        # Cache sudo credentials before Homebrew install
        # sudo reads password from /dev/tty, so it works even in curl|bash
        echo -e "  ${YELLOW}Homebrew requires admin access. Enter your password:${NC}"
        sudo -v < /dev/tty
        # NONINTERACTIVE=1 allows install without TTY prompts
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Reload PATH after installation
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    if command -v brew > /dev/null 2>&1; then
        # Persist brew shellenv to shell config files so PATH survives new terminals
        _brew_prefix="$(brew --prefix)"
        _brew_shellenv_line="eval \"\$(${_brew_prefix}/bin/brew shellenv)\""
        for _cfg in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile"; do
            if [[ "$_cfg" == *".zprofile" ]] || [ -f "$_cfg" ]; then
                touch "$_cfg" 2>/dev/null || true
                if ! grep -qF "brew shellenv" "$_cfg" 2>/dev/null; then
                    echo "$_brew_shellenv_line" >> "$_cfg"
                fi
            fi
        done
        echo -e "  ${GREEN}OK - $(brew --version | head -1)${NC}"
    else
        echo -e "  ${RED}FAILED - Homebrew installation failed${NC}"
        echo -e "  ${YELLOW}Please install manually:${NC}"
        echo -e "  ${CYAN}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        echo -e "  ${YELLOW}Then add to PATH (~/.zprofile):${NC}"
        echo -e "  ${CYAN}echo 'eval \"\$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile && source ~/.zprofile${NC}"
        echo -e "  ${YELLOW}Then re-run the installer.${NC}"
    fi
else
    echo -e "  ${GRAY}Skipped (Linux)${NC}"
fi

# ============================================
# 2. Node.js
# ============================================
echo ""
echo -e "${YELLOW}[2/7] Checking Node.js...${NC}"

if [[ "${PREFLIGHT_HAS_NODE_MANAGER:-false}" == true ]]; then
    # nvm/fnm/volta detected — skip brew install to avoid conflict
    if command -v node > /dev/null 2>&1; then
        echo -e "  ${GREEN}OK - $(node --version) (managed by nvm/fnm/volta)${NC}"
    else
        echo -e "  ${YELLOW}Version manager detected but node not active in this session.${NC}"
        echo -e "  ${GRAY}Run: nvm install --lts  (or equivalent for your manager)${NC}"
    fi
elif ! command -v node > /dev/null 2>&1; then
    echo -e "  ${GRAY}Installing Node.js...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew > /dev/null 2>&1; then
            brew install node
        else
            echo -e "  ${YELLOW}Homebrew not available. Please install Node.js from https://nodejs.org${NC}"
        fi
    else
        # FR-S2-04: Linux - multi-package manager support
        if command -v apt-get > /dev/null 2>&1; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif command -v dnf > /dev/null 2>&1; then
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo -E bash -
            sudo dnf install -y nodejs
        elif command -v pacman > /dev/null 2>&1; then
            sudo pacman -S --noconfirm nodejs npm
        else
            echo -e "  ${YELLOW}Unsupported package manager. Please install Node.js from https://nodejs.org${NC}"
        fi
    fi
fi

# Set npm global prefix to user directory — prevents EACCES on global installs
if command -v npm > /dev/null 2>&1; then
    _npm_prefix="$(npm config get prefix 2>/dev/null || true)"
    _system_prefixes=("/usr/local" "/opt/homebrew" "/usr" "")
    _is_system=false
    for _sp in "${_system_prefixes[@]}"; do
        if [[ "$_npm_prefix" == "$_sp" ]]; then
            _is_system=true
            break
        fi
    done
    if $_is_system; then
        mkdir -p "$HOME/.npm-global"
        npm config set prefix "$HOME/.npm-global"
        _add_to_path "$HOME/.npm-global/bin"
        echo -e "  ${GRAY}npm prefix set to ~/.npm-global (prevents EACCES on global installs)${NC}"
    fi
fi

if command -v node > /dev/null 2>&1; then
    echo -e "  ${GREEN}OK - $(node --version)${NC}"
else
    echo -e "  ${YELLOW}Installed (restart terminal to use)${NC}"
fi

# ============================================
# 3. Git
# ============================================
echo ""
echo -e "${YELLOW}[3/7] Checking Git...${NC}"
if ! command -v git > /dev/null 2>&1; then
    echo -e "  ${GRAY}Installing Git...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git
    else
        # FR-S2-04: Multi-package manager support
        if command -v apt-get > /dev/null 2>&1; then
            sudo apt-get install -y git
        elif command -v dnf > /dev/null 2>&1; then
            sudo dnf install -y git
        elif command -v pacman > /dev/null 2>&1; then
            sudo pacman -S --noconfirm git
        fi
    fi
fi

if command -v git > /dev/null 2>&1; then
    GIT_VERSION=$(git --version)
    # Apply recommended global settings (non-destructive — only sets if unset)
    git config --global core.quotepath false 2>/dev/null || true   # UTF-8 filename display
    git config --global init.defaultBranch main 2>/dev/null || true
    echo -e "  ${GREEN}OK - $GIT_VERSION${NC}"
else
    echo -e "  ${YELLOW}Installed (restart terminal to use)${NC}"
fi

# ============================================
# 4. VS Code
# ============================================
echo ""
echo -e "${YELLOW}[4/7] Checking VS Code...${NC}"
VS_CODE_INSTALLED=false
if command -v code > /dev/null 2>&1 || [ -d "/Applications/Visual Studio Code.app" ]; then
    VS_CODE_INSTALLED=true
fi

if ! $VS_CODE_INSTALLED; then
    echo -e "  ${GRAY}Installing VS Code...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew > /dev/null 2>&1; then
            brew install --cask visual-studio-code || {
                echo -e "  ${RED}Brew cask install failed.${NC}"
                echo -e "  ${YELLOW}Manual download: https://code.visualstudio.com${NC}"
            }
        else
            echo -e "  ${YELLOW}Homebrew not available. Please install VS Code from https://code.visualstudio.com${NC}"
        fi
    else
        # FR-S2-04: Linux - multi-package manager VS Code support
        if command -v snap > /dev/null 2>&1; then
            sudo snap install code --classic
        elif command -v dnf > /dev/null 2>&1; then
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
            echo -e "  ${YELLOW}Please install VS Code manually from https://code.visualstudio.com${NC}"
        elif command -v pacman > /dev/null 2>&1; then
            echo -e "  ${YELLOW}Please install VS Code from AUR or https://code.visualstudio.com${NC}"
        else
            echo -e "  ${YELLOW}Please install VS Code manually from https://code.visualstudio.com${NC}"
        fi
    fi
fi

# Ensure 'code' CLI is in PATH (macOS — VS Code installs it under the .app bundle)
if [[ "$OSTYPE" == "darwin"* ]]; then
    _code_cli_dir="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    if [ -d "$_code_cli_dir" ] && ! command -v code > /dev/null 2>&1; then
        _add_to_path "$_code_cli_dir"
        export PATH="$_code_cli_dir:$PATH"   # needed immediately for the extension step below
        echo -e "  ${GRAY}Added 'code' to PATH${NC}"
    fi
fi

# Gatekeeper: remove quarantine attribute (prevents "unverified developer" dialog)
if [[ "$OSTYPE" == "darwin"* ]] && [ -d "/Applications/Visual Studio Code.app" ]; then
    xattr -rd com.apple.quarantine "/Applications/Visual Studio Code.app" 2>/dev/null || true
fi

echo -e "  ${GREEN}OK${NC}"

# Install IDE extension based on CLI type
if command -v code > /dev/null 2>&1; then
    if [ "$CLI_TYPE" = "gemini" ]; then
        echo -e "  ${GRAY}Installing Gemini CLI Companion extension...${NC}"
        _ext_output="$(code --install-extension Google.gemini-cli-vscode-ide-companion --force 2>&1 || true)"
        if echo "$_ext_output" | grep -qi "failed\|error\|ENOENT\|ECONNREFUSED\|certificate"; then
            echo -e "  ${YELLOW}Gemini extension install issue detected:${NC}"
            echo -e "  ${GRAY}$_ext_output${NC}" | head -5
            echo -e "  ${YELLOW}Manual install: Open VS Code > Extensions > search 'Gemini CLI Companion'${NC}"
        else
            echo -e "  ${GREEN}Gemini CLI Companion extension installed${NC}"
        fi
    else
        echo -e "  ${GRAY}Installing Claude extension...${NC}"
        _ext_output="$(code --install-extension anthropic.claude-code --force 2>&1 || true)"
        if echo "$_ext_output" | grep -qi "failed\|error\|ENOENT\|ECONNREFUSED\|certificate"; then
            echo -e "  ${YELLOW}Claude extension install issue detected:${NC}"
            echo -e "  ${GRAY}$_ext_output${NC}" | head -5
            echo -e "  ${YELLOW}Manual install: Open VS Code > Extensions > search 'Claude Code' (anthropic.claude-code)${NC}"
        else
            echo -e "  ${GREEN}Claude extension installed${NC}"
        fi
    fi
fi

# ============================================
# 5. Docker Desktop (only if needed)
# ============================================
echo ""
echo -e "${YELLOW}[5/7] Checking Docker...${NC}"
if [ "$NEEDS_DOCKER" = true ]; then
    if ! command -v docker > /dev/null 2>&1; then
        echo -e "  ${GRAY}Installing Docker Desktop...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command -v brew > /dev/null 2>&1; then
                echo -e "  ${YELLOW}Homebrew not available. Please install Docker Desktop from https://docker.com${NC}"
            else
                echo -e "  ${GRAY}This may take 3~5 minutes. Please wait...${NC}"
                # Run brew install in background with spinner
                brew install --cask docker > /dev/null 2>&1 &
                BREW_PID=$!
                SPINNER='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
                while kill -0 $BREW_PID 2>/dev/null; do
                    for (( i=0; i<${#SPINNER}; i++ )); do
                        kill -0 $BREW_PID 2>/dev/null || break
                        printf "\r  ${GRAY}%s Installing Docker Desktop...${NC}" "${SPINNER:$i:1}"
                        sleep 0.3
                    done
                done
                wait $BREW_PID
                BREW_EXIT=$?
                printf "\r%-65s\r" ""
                if [ $BREW_EXIT -eq 0 ]; then
                    # Remove quarantine so Docker opens without Gatekeeper warning
                    xattr -rd com.apple.quarantine "/Applications/Docker.app" 2>/dev/null || true
                    DOCKER_NEEDS_RESTART=true
                    echo -e "  ${YELLOW}Installed (start Docker Desktop after setup)${NC}"
                else
                    echo -e "  ${RED}Installation failed. Please install Docker Desktop manually from https://docker.com${NC}"
                fi
            fi
        else
            # Linux
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker "$USER"
            DOCKER_NEEDS_RESTART=true
            echo -e "  ${YELLOW}Installed (logout/login required to use docker without sudo)${NC}"
        fi
    else
        # Docker binary exists — check if daemon is running
        if ! docker info > /dev/null 2>&1; then
            echo -e "  ${YELLOW}Docker installed but daemon not running.${NC}"
            echo -e "  ${GRAY}Start Docker Desktop application, then re-run installer.${NC}"
        else
            echo -e "  ${GREEN}OK${NC}"
        fi
    fi
else
    echo -e "  ${GRAY}Skipped (not required by selected modules)${NC}"
fi

# ============================================
# 6. AI CLI (Claude or Gemini)
# ============================================
echo ""
if [ "$CLI_TYPE" = "gemini" ]; then
    echo -e "${YELLOW}[6/7] Checking Gemini CLI...${NC}"
    if ! command -v gemini > /dev/null 2>&1; then
        echo -e "  ${GRAY}Installing Gemini CLI...${NC}"
        npm install -g @google/gemini-cli
    fi
    # Ensure npm-global bin is in PATH
    _add_to_path "$HOME/.npm-global/bin"
    if command -v gemini > /dev/null 2>&1; then
        GEMINI_VERSION=$(gemini --version 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}OK - $GEMINI_VERSION${NC}"
    else
        echo -e "  ${YELLOW}Installed (restart terminal to use)${NC}"
        echo -e "  ${GRAY}Run: source ~/.zshrc  (or open a new terminal tab)${NC}"
    fi
else
    echo -e "${YELLOW}[6/7] Checking Claude Code CLI...${NC}"

    # Remove deprecated npm global Claude CLI to prevent PATH conflict
    if [[ "${PREFLIGHT_HAS_NPM_CLAUDE:-false}" == true ]]; then
        echo -e "  ${GRAY}Removing deprecated npm global Claude CLI...${NC}"
        npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
        rm -f "$HOME/.npm-global/bin/claude" 2>/dev/null || true
        npm cache clean --force 2>/dev/null || true
        echo -e "  ${GRAY}Removed.${NC}"
    fi

    if ! command -v claude > /dev/null 2>&1; then
        echo -e "  ${GRAY}Installing Claude Code CLI (native)...${NC}"
        curl -fsSL https://claude.ai/install.sh | bash
    fi

    # Auto-add ~/.local/bin to PATH (Claude native installer puts binary here)
    _add_to_path "$HOME/.local/bin"

    # Gatekeeper: remove quarantine attributes from Claude binary and runtime files
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -f "$HOME/.local/bin/claude" ]; then
            xattr -d com.apple.quarantine "$HOME/.local/bin/claude" 2>/dev/null || true
        fi
        if [ -d "$HOME/.local/share/claude-code" ]; then
            # -cr: recursive + clear all quarantine attributes (catches .node files)
            xattr -cr "$HOME/.local/share/claude-code" 2>/dev/null || true
        fi
        echo -e "  ${GRAY}Removed Gatekeeper quarantine attributes${NC}"
    fi

    if command -v claude > /dev/null 2>&1; then
        CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}OK - $CLAUDE_VERSION${NC}"
    else
        echo -e "  ${YELLOW}Installed (restart terminal to use)${NC}"
        echo -e "  ${GRAY}Run: source ~/.zshrc  (or open a new terminal tab)${NC}"
    fi
fi

# ============================================
# 7. bkit Plugin
# ============================================
echo ""
if [ "$CLI_TYPE" = "gemini" ]; then
    echo -e "${YELLOW}[7/7] Installing bkit Plugin (Gemini)...${NC}"
    echo "y" | gemini extensions install https://github.com/ww-w-ai/bkit-gemini.git 2>/dev/null || true
    echo -e "  ${GREEN}OK${NC}"
else
    echo -e "${YELLOW}[7/7] Installing bkit Plugin...${NC}"
    claude plugin marketplace add ww-w-ai/bkit-claude-code 2>/dev/null || true
    claude plugin install bkit@bkit-marketplace 2>/dev/null || true

    if claude plugin list 2>/dev/null | grep -q "bkit"; then
        echo -e "  ${GREEN}OK${NC}"
    else
        echo -e "  ${YELLOW}Installed (verify with 'claude plugin list')${NC}"
    fi
fi

# ============================================
# Summary
# ============================================
echo ""
echo "----------------------------------------"
echo -e "${GREEN}Base installation complete!${NC}"

if [ "$DOCKER_NEEDS_RESTART" = true ]; then
    echo ""
    echo -e "${YELLOW}IMPORTANT: Docker was installed.${NC}"
    echo "  1. Start Docker Desktop application"
    echo "  2. Run installer again with --skip-base flag:"
    echo -e "     ${CYAN}./install.sh --modules \"google,atlassian\" --skip-base${NC}"
fi

# Remind about PATH if we modified shell configs
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo -e "${GRAY}Note: Shell config files updated for PATH. Changes take effect in new terminals.${NC}"
    echo -e "${GRAY}To apply now: source ~/.zprofile && source ~/.zshrc${NC}"
fi
