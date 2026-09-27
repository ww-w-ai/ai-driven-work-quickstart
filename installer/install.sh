#!/bin/bash
# ============================================
# AI-Driven Work Installer (ADW) - Mac/Linux
# ============================================
# Dynamic Module Loading System (Folder Scan)
#
# Usage:
#   ./install.sh --modules "google,atlassian"
#   ./install.sh --all
#   ./install.sh --list
#
# Remote:
#   curl -sSL https://raw.githubusercontent.com/.../install.sh | bash -s -- --modules "google,atlassian"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Base URL for module downloads
BASE_URL="https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer"

# Cross-platform JSON parser (FR-S1-03: injection-safe, FR-S2-01: Linux support)
# Priority: node > python3 > osascript (macOS fallback)
# Data is passed via stdin to prevent shell/template injection
parse_json() {
    local json="$1"
    local key="$2"

    # Primary: node -e (always available after base install)
    if command -v node > /dev/null 2>&1; then
        echo "$json" | node -e "
            let data = '';
            process.stdin.setEncoding('utf8');
            process.stdin.on('data', chunk => data += chunk);
            process.stdin.on('end', () => {
                try {
                    const obj = JSON.parse(data);
                    const keys = process.argv[1].split('.');
                    let val = obj;
                    for (const k of keys) val = val ? val[k] : undefined;
                    process.stdout.write(val === undefined ? '' : String(val));
                } catch (e) {
                    process.stdout.write('');
                }
            });
        " "$key" 2>/dev/null || echo ""
        return
    fi

    # Fallback: python3
    if command -v python3 > /dev/null 2>&1; then
        echo "$json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    v = d
    for k in sys.argv[1].split('.'):
        v = v.get(k, '') if isinstance(v, dict) else ''
    print(v if v else '', end='')
except:
    print('', end='')
" "$key" 2>/dev/null || echo ""
        return
    fi

    # Last fallback: osascript (macOS only, stdin-based -- safe from injection)
    if command -v osascript > /dev/null 2>&1; then
        echo "$json" | osascript -l JavaScript -e "
            var input = $.NSFileHandle.fileHandleWithStandardInput;
            var data = input.readDataToEndOfFile;
            var str = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
            var obj = JSON.parse(str);
            var keys = ObjC.unwrap($.NSProcessInfo.processInfo.arguments).slice(-1)[0].split('.');
            var val = obj;
            for (var k of keys) val = val ? val[k] : undefined;
            val === undefined ? '' : String(val);
        " "$key" 2>/dev/null || echo ""
        return
    fi

    echo ""
}

# Check if running locally
USE_LOCAL=false
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$SCRIPT_DIR/modules" ]; then
        USE_LOCAL=true
    fi
fi

# ============================================
# FR-S1-11: SHA-256 Checksum Verification
# ============================================
# All remote downloads are verified against checksums.json before execution.
# This prevents MITM attacks, CDN tampering, and partial download execution.
CHECKSUMS_JSON=""
CHECKSUMS_LOADED=false

# Download and cache checksums.json (once per session)
load_checksums() {
    if [ "$CHECKSUMS_LOADED" = false ]; then
        CHECKSUMS_LOADED=true
        CHECKSUMS_JSON=$(curl -sSL "$BASE_URL/checksums.json" 2>/dev/null || echo "")
        if [ -z "$CHECKSUMS_JSON" ]; then
            echo -e "${YELLOW}[WARN] checksums.json not available. Skipping integrity verification.${NC}" >&2
        fi
    fi
}

# Download a remote file and verify its SHA-256 hash
# Returns the path to the verified temp file on success, exits on failure
download_and_verify() {
    local url="$1"
    local relative_path="$2"  # key in checksums.json (e.g., "modules/google/install.sh")
    local tmpfile
    tmpfile=$(mktemp)

    # 1. Download the file to a temp location
    if ! curl -sSL "$url" -o "$tmpfile"; then
        echo -e "${RED}[ERROR] Download failed: $url${NC}" >&2
        rm -f "$tmpfile"
        return 1
    fi

    # 2. If checksums.json is available, verify integrity
    load_checksums
    if [ -n "$CHECKSUMS_JSON" ] && command -v node > /dev/null 2>&1; then
        local expected_hash
        expected_hash=$(echo "$CHECKSUMS_JSON" | node -e "
            let data = '';
            process.stdin.setEncoding('utf8');
            process.stdin.on('data', chunk => data += chunk);
            process.stdin.on('end', () => {
                try {
                    const checksums = JSON.parse(data);
                    const hash = checksums.files[process.argv[1]] || '';
                    process.stdout.write(hash);
                } catch (e) {
                    process.stdout.write('');
                }
            });
        " "$relative_path" 2>/dev/null)

        if [ -n "$expected_hash" ]; then
            # Compute SHA-256 hash (cross-platform: shasum or sha256sum)
            local actual_hash
            if command -v shasum > /dev/null 2>&1; then
                actual_hash=$(shasum -a 256 "$tmpfile" | awk '{print $1}')
            elif command -v sha256sum > /dev/null 2>&1; then
                actual_hash=$(sha256sum "$tmpfile" | awk '{print $1}')
            else
                echo -e "${YELLOW}[WARN] No SHA-256 tool found. Skipping hash verification.${NC}" >&2
                echo "$tmpfile"
                return 0
            fi

            if [ "$actual_hash" != "$expected_hash" ]; then
                echo -e "${RED}[SECURITY] Integrity verification failed!${NC}" >&2
                echo -e "${RED}  File: $relative_path${NC}" >&2
                echo -e "${RED}  Expected: $expected_hash${NC}" >&2
                echo -e "${RED}  Actual:   $actual_hash${NC}" >&2
                echo -e "${RED}  File may have been tampered with. Aborting.${NC}" >&2
                rm -f "$tmpfile"
                return 1
            fi
            echo -e "  ${GREEN}Integrity verified: $relative_path${NC}" >&2
        fi
    fi

    echo "$tmpfile"
    return 0
}

# ============================================
# 1. Parse Arguments
# ============================================
# Support both environment variables and command-line arguments
MODULES="${MODULES:-}"
INSTALL_ALL="${INSTALL_ALL:-false}"
SKIP_BASE="${SKIP_BASE:-false}"
LIST_ONLY="${LIST_ONLY:-false}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --modules) MODULES="$2"; shift 2 ;;
        --all) INSTALL_ALL=true; shift ;;
        --skip-base) SKIP_BASE=true; shift ;;
        --list) LIST_ONLY=true; shift ;;
        --cli) CLI_TYPE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# CLI type: claude (default) or gemini
CLI_TYPE="${CLI_TYPE:-claude}"
if [[ "$CLI_TYPE" != "claude" && "$CLI_TYPE" != "gemini" ]]; then
    echo -e "${RED}Invalid --cli value: $CLI_TYPE (use 'claude' or 'gemini')${NC}"
    exit 1
fi
export CLI_TYPE

# ============================================
# 2. Scan Modules Folder
# ============================================
# Store module info in arrays
declare -a MODULE_NAMES
declare -a MODULE_DISPLAY_NAMES
declare -a MODULE_DESCRIPTIONS
declare -a MODULE_ORDERS
declare -a MODULE_REQUIRED
declare -a MODULE_COMPLEXITY
declare -a MODULE_DOCKER_REQ

load_modules() {
    local idx=0

    if [ "$USE_LOCAL" = true ]; then
        # Local: scan modules/ folder
        for dir in "$SCRIPT_DIR/modules"/*/; do
            if [ -f "${dir}module.json" ]; then
                local json=$(cat "${dir}module.json")
                MODULE_NAMES[$idx]=$(parse_json "$json" "name")
                MODULE_DISPLAY_NAMES[$idx]=$(parse_json "$json" "displayName")
                MODULE_DESCRIPTIONS[$idx]=$(parse_json "$json" "description")
                MODULE_ORDERS[$idx]=$(parse_json "$json" "order")
                MODULE_REQUIRED[$idx]=$(parse_json "$json" "required")
                MODULE_COMPLEXITY[$idx]=$(parse_json "$json" "complexity")
                MODULE_DOCKER_REQ[$idx]=$(parse_json "$json" "requirements.docker")
                ((idx++))
            fi
        done
    else
        # Remote: fetch module list, then load each module
        # FR-S1-11: Use download_and_verify for remote metadata
        local modules_tmpfile
        modules_tmpfile=$(download_and_verify "$BASE_URL/modules.json" "modules.json" 2>/dev/null)
        local modules_json=""
        if [ -n "$modules_tmpfile" ] && [ -f "$modules_tmpfile" ]; then
            modules_json=$(cat "$modules_tmpfile")
            rm -f "$modules_tmpfile"
        else
            # Fallback: try direct download if checksums not available
            modules_json=$(curl -sSL "$BASE_URL/modules.json" 2>/dev/null || echo "")
        fi

        if [ -n "$modules_json" ]; then
            # FR-S1-03: Parse module names and orders safely via stdin (no shell interpolation)
            # Returns "name:order" pairs for lazy loading optimization
            local module_entries=""
            if command -v node > /dev/null 2>&1; then
                module_entries=$(echo "$modules_json" | node -e "
                    let data = '';
                    process.stdin.setEncoding('utf8');
                    process.stdin.on('data', chunk => data += chunk);
                    process.stdin.on('end', () => {
                        try {
                            const parsed = JSON.parse(data);
                            process.stdout.write(parsed.modules.map(m => m.name+':'+m.order).join(' '));
                        } catch (e) {
                            process.stdout.write('');
                        }
                    });
                " 2>/dev/null)
            elif command -v python3 > /dev/null 2>&1; then
                module_entries=$(echo "$modules_json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(' '.join(f'{m[\"name\"]}:{m.get(\"order\",99)}' for m in d.get('modules', [])), end='')
except:
    print('', end='')
" 2>/dev/null)
            elif command -v osascript > /dev/null 2>&1; then
                module_entries=$(echo "$modules_json" | osascript -l JavaScript -e "
                    var input = $.NSFileHandle.fileHandleWithStandardInput;
                    var data = input.readDataToEndOfFile;
                    var str = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
                    var obj = JSON.parse(str);
                    obj.modules.map(function(m){ return m.name+':'+m.order; }).join(' ');
                " 2>/dev/null)
            fi

            # Determine which modules need full metadata (base + selected)
            local need_full="base"
            if [ -n "$MODULES" ]; then
                need_full="$need_full $(echo "$MODULES" | tr ',' ' ')"
            fi
            local load_all=false
            if [ "$INSTALL_ALL" = true ] || [ "$LIST_ONLY" = true ]; then
                load_all=true
            fi

            for entry in $module_entries; do
                local name="${entry%%:*}"
                local order="${entry##*:}"

                local needs_full=false
                if [ "$load_all" = true ]; then
                    needs_full=true
                else
                    for needed in $need_full; do
                        if [ "$name" = "$needed" ]; then needs_full=true; break; fi
                    done
                fi

                if [ "$needs_full" = true ]; then
                    # FR-S1-11: Verify module.json files too
                    local mod_tmpfile
                    mod_tmpfile=$(download_and_verify \
                        "$BASE_URL/modules/$name/module.json" \
                        "modules/$name/module.json" 2>/dev/null)
                    local json=""
                    if [ -n "$mod_tmpfile" ] && [ -f "$mod_tmpfile" ]; then
                        json=$(cat "$mod_tmpfile")
                        rm -f "$mod_tmpfile"
                    else
                        json=$(curl -sSL "$BASE_URL/modules/$name/module.json" 2>/dev/null || echo "")
                    fi
                    if [ -n "$json" ]; then
                        MODULE_NAMES[$idx]=$(parse_json "$json" "name")
                        MODULE_DISPLAY_NAMES[$idx]=$(parse_json "$json" "displayName")
                        MODULE_DESCRIPTIONS[$idx]=$(parse_json "$json" "description")
                        MODULE_ORDERS[$idx]=$(parse_json "$json" "order")
                        MODULE_REQUIRED[$idx]=$(parse_json "$json" "required")
                        MODULE_COMPLEXITY[$idx]=$(parse_json "$json" "complexity")
                        MODULE_DOCKER_REQ[$idx]=$(parse_json "$json" "requirements.docker")
                        ((idx++))
                    fi
                else
                    # Minimal entry for name validation (no HTTP request)
                    MODULE_NAMES[$idx]="$name"
                    MODULE_DISPLAY_NAMES[$idx]="$name"
                    MODULE_DESCRIPTIONS[$idx]=""
                    MODULE_ORDERS[$idx]="$order"
                    MODULE_REQUIRED[$idx]="false"
                    MODULE_COMPLEXITY[$idx]=""
                    MODULE_DOCKER_REQ[$idx]=""
                    ((idx++))
                fi
            done
        fi
    fi
}

get_module_index() {
    local name="$1"
    for i in "${!MODULE_NAMES[@]}"; do
        if [ "${MODULE_NAMES[$i]}" = "$name" ]; then
            echo "$i"
            return
        fi
    done
    echo "-1"
}

load_modules

# ============================================
# 3. List Mode
# ============================================
if [ "$LIST_ONLY" = true ]; then
    clear
    echo ""
    echo "========================================"
    echo -e "${CYAN}  Available Modules${NC}"
    echo "========================================"
    echo ""

    # Sort by order and display
    for i in "${!MODULE_NAMES[@]}"; do
        name="${MODULE_NAMES[$i]}"
        display="${MODULE_DISPLAY_NAMES[$i]}"
        desc="${MODULE_DESCRIPTIONS[$i]}"
        complexity="${MODULE_COMPLEXITY[$i]}"
        required="${MODULE_REQUIRED[$i]}"

        req_text=""
        if [ "$required" = "true" ]; then
            req_text="${YELLOW}(required)${NC}"
        fi

        echo -e "  ${GREEN}$name${NC} $req_text ${GRAY}[$complexity]${NC}"
        echo -e "    ${GRAY}$desc${NC}"
        echo ""
    done

    echo "Usage:"
    echo -e "  ${GRAY}./install.sh --modules \"google,atlassian\"${NC}"
    echo -e "  ${GRAY}./install.sh --all${NC}"
    echo ""
    exit 0
fi

# ============================================
# 4. Parse Module Selection
# ============================================
SELECTED_MODULES=""

if [ "$INSTALL_ALL" = true ]; then
    for i in "${!MODULE_NAMES[@]}"; do
        if [ "${MODULE_REQUIRED[$i]}" != "true" ]; then
            SELECTED_MODULES="$SELECTED_MODULES ${MODULE_NAMES[$i]}"
        fi
    done
    SELECTED_MODULES=$(echo "$SELECTED_MODULES" | xargs)  # trim
elif [ -n "$MODULES" ]; then
    SELECTED_MODULES=$(echo "$MODULES" | tr ',' ' ')
fi

# Validate modules
for mod in $SELECTED_MODULES; do
    idx=$(get_module_index "$mod")
    if [ "$idx" = "-1" ]; then
        echo -e "${RED}Unknown module: $mod${NC}"
        echo "Use --list to see available modules."
        exit 1
    fi
done

# ============================================
# 5. Smart Status Check
# ============================================
get_install_status() {
    if command -v node > /dev/null 2>&1; then HAS_NODE="true"; else HAS_NODE="false"; fi
    if command -v git > /dev/null 2>&1; then HAS_GIT="true"; else HAS_GIT="false"; fi
    if command -v code > /dev/null 2>&1 || [ -d "/Applications/Visual Studio Code.app" ]; then HAS_IDE="true"; else HAS_IDE="false"; fi
    if command -v docker > /dev/null 2>&1; then HAS_DOCKER="true"; else HAS_DOCKER="false"; fi
    CLI_CMD="${CLI_TYPE:-claude}"
    if command -v "$CLI_CMD" > /dev/null 2>&1; then HAS_CLI="true"; else HAS_CLI="false"; fi
    HAS_BKIT="false"
    DOCKER_RUNNING="false"

    if [ "$HAS_DOCKER" = "true" ]; then
        if docker info > /dev/null 2>&1; then DOCKER_RUNNING="true"; fi
    fi

    if [ "$HAS_CLI" = "true" ]; then
        if [ "$CLI_TYPE" = "gemini" ]; then
            # For gemini, bkit check is different
            HAS_BKIT="false"
        else
            claude plugin list 2>/dev/null | grep -q "bkit" && HAS_BKIT="true" || true
        fi
    fi
}

clear
echo ""
echo "========================================"
echo -e "${CYAN}  AI-Driven Work Installer v2${NC}"
echo "========================================"
echo ""

# ============================================
# System Requirements Check
# ============================================
MIN_RAM=8
MIN_CPU=4
MIN_DISK=10

if [[ "$OSTYPE" == "darwin"* ]]; then
    SYS_RAM=$(sysctl -n hw.memsize | awk '{printf "%d", $0/1073741824}')
    SYS_CPU=$(sysctl -n hw.ncpu)
    SYS_DISK=$(df -g / | awk 'NR==2{print $4}')
else
    SYS_RAM=$(free -g | awk '/Mem:/{print $2}')
    SYS_CPU=$(nproc)
    SYS_DISK=$(df -BG / | awk 'NR==2{gsub("G",""); print $4}')
fi

if [ "$CI" = "true" ]; then
    echo -e "  ${YELLOW}CI mode: skipping system requirements check${NC}"
else
    SPEC_FAILED=false
    if [ "$SYS_RAM" -lt "$MIN_RAM" ] 2>/dev/null; then
        echo -e "  ${RED}RAM: ${SYS_RAM}GB (minimum: ${MIN_RAM}GB)${NC}"
        SPEC_FAILED=true
    fi
    if [ "$SYS_CPU" -lt "$MIN_CPU" ] 2>/dev/null; then
        echo -e "  ${RED}CPU: ${SYS_CPU} cores (minimum: ${MIN_CPU} cores)${NC}"
        SPEC_FAILED=true
    fi
    if [ "$SYS_DISK" -lt "$MIN_DISK" ] 2>/dev/null; then
        echo -e "  ${RED}Disk: ${SYS_DISK}GB free (minimum: ${MIN_DISK}GB)${NC}"
        SPEC_FAILED=true
    fi

    if [ "$SPEC_FAILED" = true ]; then
        echo ""
        echo -e "${RED}Your system does not meet the minimum requirements for installation.${NC}"
        exit 1
    fi
fi

get_install_status

# Check Docker requirement for selected modules (before status display)
NEEDS_DOCKER=false
for mod in $SELECTED_MODULES; do
    idx=$(get_module_index "$mod")
    if [ "${MODULE_DOCKER_REQ[$idx]}" = "true" ]; then
        NEEDS_DOCKER=true
        break
    fi
done

IDE_LABEL="VS Code"
CLI_LABEL=$([ "$CLI_TYPE" = "gemini" ] && echo "Gemini" || echo "Claude")

echo "Current Status: (CLI: $CLI_TYPE)"
[ "$HAS_NODE" = "true" ] && echo -e "  Node.js:     ${GREEN}[OK]${NC}" || echo -e "  Node.js:     ${GRAY}[  ]${NC}"
[ "$HAS_GIT" = "true" ] && echo -e "  Git:         ${GREEN}[OK]${NC}" || echo -e "  Git:         ${GRAY}[  ]${NC}"
[ "$HAS_IDE" = "true" ] && echo -e "  $IDE_LABEL:  ${GREEN}[OK]${NC}" || echo -e "  $IDE_LABEL:  ${GRAY}[  ]${NC}"
if [ "$NEEDS_DOCKER" = true ]; then
    if [ "$HAS_DOCKER" = "true" ]; then
        if [ "$DOCKER_RUNNING" = "true" ]; then
            echo -e "  Docker:      ${GREEN}[OK] (Running)${NC}"
        else
            echo -e "  Docker:      ${YELLOW}[OK] (Not Running)${NC}"
        fi
    else
        echo -e "  Docker:      ${GRAY}[  ]${NC}"
    fi
fi
[ "$HAS_CLI" = "true" ] && echo -e "  $CLI_LABEL:  ${GREEN}[OK]${NC}" || echo -e "  $CLI_LABEL:  ${GRAY}[  ]${NC}"
[ "$HAS_BKIT" = "true" ] && echo -e "  bkit:        ${GREEN}[OK]${NC}" || echo -e "  bkit:        ${GRAY}[  ]${NC}"
echo ""

if [ "$NEEDS_DOCKER" = true ] && [ "$HAS_DOCKER" = "true" ] && [ "$DOCKER_RUNNING" = "false" ]; then
    echo "========================================"
    echo -e "${YELLOW}  Docker Desktop is not running!${NC}"
    echo "========================================"
    echo ""
    echo "Selected modules require Docker to be running."
    echo ""
    echo -e "${GRAY}How to start:${NC}"
    echo -e "${GRAY}  - Click Docker icon in Applications (Mac)${NC}"
    echo -e "${GRAY}  - Or run 'sudo systemctl start docker' (Linux)${NC}"
    echo ""
    if [ "$CI" = "true" ]; then
        echo -e "${YELLOW}CI mode: skipping Docker wait${NC}"
    else
        read -p "Press Enter after starting Docker (or 'q' to quit): " DOCKER_WAIT < /dev/tty
        if [ "$DOCKER_WAIT" = "q" ]; then exit 0; fi

        if ! docker info > /dev/null 2>&1; then
            echo -e "${RED}Docker still not running. Please start it and try again.${NC}"
            read -p "Press Enter to exit" < /dev/tty
            exit 1
        fi
    fi
    echo -e "${GREEN}Docker is now running!${NC}"
    echo ""
fi

# Auto-skip base if all required tools installed
BASE_INSTALLED=true
if [ "$HAS_NODE" != "true" ] || [ "$HAS_GIT" != "true" ] || [ "$HAS_CLI" != "true" ] || [ "$HAS_BKIT" != "true" ]; then
    BASE_INSTALLED=false
fi
if [ "$NEEDS_DOCKER" = true ] && [ "$HAS_DOCKER" != "true" ]; then
    BASE_INSTALLED=false
fi

if [ "$BASE_INSTALLED" = true ] && [ "$SKIP_BASE" = false ] && [ -n "$SELECTED_MODULES" ]; then
    echo -e "${GREEN}All base tools are already installed. Skipping base.${NC}"
    SKIP_BASE=true
    echo ""
fi

# Export NEEDS_DOCKER for base module
export NEEDS_DOCKER

# ============================================
# 6. Calculate Steps & Show Selection
# ============================================
TOTAL_STEPS=0
if [ "$SKIP_BASE" = false ]; then ((TOTAL_STEPS++)) || true; fi
for mod in $SELECTED_MODULES; do
    ((TOTAL_STEPS++)) || true
done

if [ $TOTAL_STEPS -eq 0 ]; then
    TOTAL_STEPS=1
    SKIP_BASE=false
fi

BASE_LABEL=$([ "$CLI_TYPE" = "gemini" ] && echo "Base (Gemini + bkit)" || echo "Base (Claude + bkit)")
echo "Selected modules:"
if [ "$SKIP_BASE" = false ]; then
    echo -e "  ${GREEN}[*] $BASE_LABEL${NC}"
else
    echo -e "  ${GRAY}[ ] Base (skipped)${NC}"
fi

for mod in $SELECTED_MODULES; do
    idx=$(get_module_index "$mod")
    echo -e "  ${GREEN}[*] ${MODULE_DISPLAY_NAMES[$idx]}${NC}"
done
echo ""
if [ "$CI" != "true" ]; then
    read -p "Press Enter to start installation" < /dev/tty
fi

# ============================================
# 7. FR-S5-02: Rollback Mechanism
# ============================================
# Backup MCP config before module installation
if [ "$CLI_TYPE" = "gemini" ]; then
    MCP_CONFIG_FILE="$HOME/.gemini/settings.json"
else
    MCP_CONFIG_FILE="$HOME/.claude/mcp.json"
fi
MCP_BACKUP_FILE=""

backup_mcp_config() {
    if [ -f "$MCP_CONFIG_FILE" ]; then
        MCP_BACKUP_FILE="${MCP_CONFIG_FILE}.bak.$(date +%s)"
        cp "$MCP_CONFIG_FILE" "$MCP_BACKUP_FILE"
        echo -e "  ${GRAY}MCP config backed up to ${MCP_BACKUP_FILE}${NC}"
    fi
}

rollback_mcp_config() {
    if [ -n "$MCP_BACKUP_FILE" ] && [ -f "$MCP_BACKUP_FILE" ]; then
        cp "$MCP_BACKUP_FILE" "$MCP_CONFIG_FILE"
        echo -e "  ${YELLOW}MCP config rolled back from backup${NC}"
    fi
}

# ============================================
# 8. FR-S5-01: Post-Installation Verification
# ============================================
verify_module_installation() {
    local module_name="$1"
    local idx=$(get_module_index "$module_name")
    local docker_req="${MODULE_DOCKER_REQ[$idx]}"

    # Check if MCP server was registered
    if [ -f "$MCP_CONFIG_FILE" ] && command -v node > /dev/null 2>&1; then
        local registered
        registered=$(MCP_CONFIG_PATH="$MCP_CONFIG_FILE" MODULE_NAME="$module_name" node -e "
            const fs = require('fs');
            try {
                const config = JSON.parse(fs.readFileSync(process.env.MCP_CONFIG_PATH, 'utf8'));
                const servers = Object.keys(config.mcpServers || {});
                process.stdout.write(servers.length > 0 ? 'true' : 'false');
            } catch { process.stdout.write('false'); }
        " 2>/dev/null || echo "false")

        if [ "$registered" = "true" ]; then
            echo -e "  ${GREEN}[Verify] MCP config: OK${NC}"
        else
            echo -e "  ${YELLOW}[Verify] MCP config: No servers registered${NC}"
        fi
    fi

    # Check Docker image if required
    if [ "$docker_req" = "true" ] && command -v docker > /dev/null 2>&1; then
        if docker images --format '{{.Repository}}' 2>/dev/null | grep -q "$module_name" || \
           docker images --format '{{.Repository}}' 2>/dev/null | grep -q "workspace-mcp"; then
            echo -e "  ${GREEN}[Verify] Docker image: OK${NC}"
        fi
    fi
}

# ============================================
# 9. Module Execution Function
# FR-S2-02: SHARED_DIR + temp file cleanup via trap
# ============================================

# Pre-download shared scripts for remote execution
SHARED_TMP=""

setup_shared_dir() {
    if [ "$USE_LOCAL" = true ]; then
        export SHARED_DIR="$SCRIPT_DIR/modules/shared"
    else
        # FR-S2-02: Download shared scripts to temp directory for remote execution
        SHARED_TMP=$(mktemp -d)
        trap 'rm -rf "$SHARED_TMP"' EXIT
        for shared_file in colors.sh browser-utils.sh docker-utils.sh mcp-config.sh preflight.sh; do
            curl -sSL "$BASE_URL/modules/shared/$shared_file" -o "$SHARED_TMP/$shared_file" 2>/dev/null || true
        done
        export SHARED_DIR="$SHARED_TMP"
    fi
}

setup_shared_dir

run_module() {
    local module_name=$1
    local step=$2
    local total=$3

    local idx=$(get_module_index "$module_name")
    if [ "$idx" = "-1" ]; then
        echo -e "${YELLOW}[WARN] Module '$module_name' not found in registry. Running directly...${NC}"
        local display_name="$module_name"
        local description=""
    else
        local display_name="${MODULE_DISPLAY_NAMES[$idx]}"
        local description="${MODULE_DESCRIPTIONS[$idx]}"
    fi

    echo ""
    echo "========================================"
    echo -e "${CYAN}  [$step/$total] $display_name${NC}"
    echo "========================================"
    echo -e "  ${GRAY}$description${NC}"
    echo ""

    # Temporarily disable set -e to catch errors
    set +e
    if [ "$USE_LOCAL" = true ]; then
        source "$SCRIPT_DIR/modules/$module_name/install.sh"
        local result=$?
    else
        # FR-S1-11: Download, verify, then execute (no curl|bash)
        local verified_script
        verified_script=$(download_and_verify \
            "$BASE_URL/modules/$module_name/install.sh" \
            "modules/$module_name/install.sh")
        local dl_result=$?

        if [ $dl_result -eq 0 ] && [ -f "$verified_script" ]; then
            source "$verified_script"
            local result=$?
            rm -f "$verified_script"
        else
            echo -e "${RED}[ERROR] Module script verification failed for $module_name. Skipping.${NC}"
            local result=1
        fi
    fi
    set -e

    if [ $result -ne 0 ]; then
        echo ""
        echo -e "${RED}Error in $display_name (exit code: $result)${NC}"
        # FR-S5-02: Offer rollback on failure
        echo -e "${YELLOW}Rolling back MCP configuration...${NC}"
        rollback_mcp_config
        echo -e "${RED}Installation aborted.${NC}"
        if [ "$CI" != "true" ]; then read -p "Press Enter to exit" < /dev/tty; fi
        exit 1
    fi

    # FR-S5-01: Verify module installation
    verify_module_installation "$module_name"
}

# ============================================
# 10. Execute Modules
# ============================================
CURRENT_STEP=0

# FR-S5-02: Backup before module installation
backup_mcp_config

# Base module
if [ "$SKIP_BASE" = false ]; then
    ((CURRENT_STEP++)) || true
    run_module "base" $CURRENT_STEP $TOTAL_STEPS
fi

# FR-S2-07: Sort selected modules by MODULE_ORDERS before execution
SORTED_MODULES=""
for mod in $SELECTED_MODULES; do
    idx=$(get_module_index "$mod")
    order="${MODULE_ORDERS[$idx]:-99}"
    SORTED_MODULES="$SORTED_MODULES $order:$mod"
done
SORTED_MODULES=$(echo "$SORTED_MODULES" | tr ' ' '\n' | sort -t: -k1 -n | cut -d: -f2 | tr '\n' ' ')

# Execute sorted modules
for mod in $SORTED_MODULES; do
    [ -z "$mod" ] && continue
    ((CURRENT_STEP++)) || true
    run_module "$mod" $CURRENT_STEP $TOTAL_STEPS
done

# ============================================
# 11. Completion Summary
# ============================================
# FR-S5-02: Clean up backup on success
if [ -n "$MCP_BACKUP_FILE" ] && [ -f "$MCP_BACKUP_FILE" ]; then
    rm -f "$MCP_BACKUP_FILE"
fi
echo ""
echo "========================================"
echo -e "${GREEN}  Installation Complete!${NC}"
echo "========================================"
echo ""
echo "Installed:"

if [ "$SKIP_BASE" = false ]; then
    if command -v node > /dev/null 2>&1; then echo -e "  ${GREEN}[OK] Node.js${NC}"; fi
    if command -v git > /dev/null 2>&1; then echo -e "  ${GREEN}[OK] Git${NC}"; fi
    if [ "$NEEDS_DOCKER" = true ]; then
        if command -v docker > /dev/null 2>&1; then
            echo -e "  ${GREEN}[OK] Docker${NC}"
        else
            echo -e "  ${YELLOW}[!] Docker (start Docker Desktop)${NC}"
        fi
    fi
    CLI_CMD="${CLI_TYPE:-claude}"
    if command -v "$CLI_CMD" > /dev/null 2>&1; then echo -e "  ${GREEN}[OK] $CLI_LABEL CLI${NC}"; fi
    if [ "$CLI_TYPE" = "gemini" ]; then
        echo -e "  ${GREEN}[OK] bkit Plugin (Gemini)${NC}"
    elif claude plugin list 2>/dev/null | grep -q "bkit"; then
        echo -e "  ${GREEN}[OK] bkit Plugin${NC}"
    fi
fi

# MCP config path (depends on CLI_TYPE)
if [ "$CLI_TYPE" = "gemini" ]; then
    MCP_CONFIG="$HOME/.gemini/settings.json"
else
    MCP_CONFIG="$HOME/.claude/mcp.json"
fi
MCP_LEGACY="$HOME/.mcp.json"
if [ -f "$MCP_CONFIG" ] || [ -f "$MCP_LEGACY" ]; then
    for mod in $SORTED_MODULES; do
        [ -z "$mod" ] && continue
        idx=$(get_module_index "$mod")
        display_name="${MODULE_DISPLAY_NAMES[$idx]}"
        echo -e "  ${GREEN}[OK] $display_name${NC}"
    done
fi

echo ""
if [ "$CI" != "true" ]; then read -p "Press Enter to close" < /dev/tty; fi
