#!/bin/bash
# ============================================
# ADW Installation Diagnostic Tool (Mac/Linux)
# ============================================
# Run this if installation failed:
#   bash <(curl -sSL https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer/diagnose.sh)

BASE_URL="https://raw.githubusercontent.com/ww-w-ai/ai-driven-work-quickstart/main/installer"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

clear
echo ""
echo "========================================"
echo -e "${CYAN}  ADW Installation Diagnostic${NC}"
echo "========================================"
echo ""
echo -e "${GRAY}Checking your environment for potential${NC}"
echo -e "${GRAY}installation issues...${NC}"
echo ""

TMPFILE=$(mktemp)
if curl -sSL "$BASE_URL/modules/shared/preflight.sh" -o "$TMPFILE" 2>/dev/null; then
    source "$TMPFILE"
    RESULT=$?
    rm -f "$TMPFILE"
    if [ $RESULT -ne 0 ]; then
        echo -e "${YELLOW}Diagnostic cancelled.${NC}"
    fi
else
    rm -f "$TMPFILE"
    echo -e "${RED}Failed to download diagnostic script.${NC}"
    echo -e "${GRAY}Check your internet connection and try again.${NC}"
fi

echo ""
if [ "$CI" != "true" ]; then read -p "Press Enter to close" < /dev/tty; fi
