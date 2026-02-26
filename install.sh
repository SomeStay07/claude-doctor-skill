#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

REPO="https://raw.githubusercontent.com/SomeStay07/claude-doctor-skill/main"
DIR=".claude/skills/doctor"
VERSION="2.3.0"

# Header
echo ""
echo -e "${CYAN}${BOLD}  Doctor Skill Installer v${VERSION}${NC}"
echo -e "${CYAN}  46 checks across 6 layers — adaptive scoring${NC}"
echo ""

# Check if already installed
if [ -f "$DIR/SKILL.md" ]; then
  echo -e "${YELLOW}  Doctor already installed at $DIR/${NC}"
  echo -e "${YELLOW}  Reinstalling (updating)...${NC}"
  echo ""
fi

# Create directories
mkdir -p "$DIR/layers"

# Download main files
echo -e "  Downloading main files..."
for file in SKILL.md GUARDRAILS.md CHECKLIST.md; do
  if curl -sSL "$REPO/$file" -o "$DIR/$file" 2>/dev/null; then
    echo -e "    ${GREEN}+${NC} $file"
  else
    echo -e "    ${RED}x${NC} Failed to download $file"
    echo -e ""
    echo -e "  ${RED}${BOLD}Installation failed.${NC} Check your internet connection."
    echo -e "  Repo: https://github.com/SomeStay07/claude-doctor-skill"
    echo -e "  ${YELLOW}Try manual install: https://github.com/SomeStay07/claude-doctor-skill#option-b-manual${NC}"
    exit 1
  fi
done

# Download layer files
echo -e "  Downloading layer details..."
for layer in SECURITY SECURITY-EXTRA FOUNDATION FOUNDATION-EXTRA QUALITY QUALITY-EXTRA QUALITY-PROD INTELLIGENCE CONTEXT DX DX-EXTRA MATURITY; do
  if curl -sSL "$REPO/layers/$layer.md" -o "$DIR/layers/$layer.md" 2>/dev/null; then
    echo -e "    ${GREEN}+${NC} layers/$layer.md"
  else
    echo -e "    ${RED}x${NC} Failed to download layers/$layer.md"
    exit 1
  fi
done

# Verify installation
echo ""
echo -e "  ${BOLD}Verifying...${NC}"
file_count=0
for f in "$DIR/SKILL.md" "$DIR/GUARDRAILS.md" "$DIR/CHECKLIST.md" \
         "$DIR/layers/SECURITY.md" "$DIR/layers/SECURITY-EXTRA.md" \
         "$DIR/layers/FOUNDATION.md" "$DIR/layers/FOUNDATION-EXTRA.md" \
         "$DIR/layers/QUALITY.md" "$DIR/layers/QUALITY-EXTRA.md" "$DIR/layers/QUALITY-PROD.md" \
         "$DIR/layers/INTELLIGENCE.md" "$DIR/layers/CONTEXT.md" \
         "$DIR/layers/DX.md" "$DIR/layers/DX-EXTRA.md" \
         "$DIR/layers/MATURITY.md"; do
  if [ -f "$f" ] && [ -s "$f" ]; then
    file_count=$((file_count + 1))
  else
    echo -e "    ${RED}x${NC} Missing or empty: $f"
  fi
done

if [ "$file_count" -eq 15 ]; then
  echo -e "    ${GREEN}${BOLD}All 15 files verified${NC}"
else
  echo -e "    ${RED}${BOLD}Only $file_count/15 files installed${NC}"
  exit 1
fi

# Success
echo ""
echo -e "  ${GREEN}${BOLD}Doctor installed to ${DIR}/${NC}"
echo ""
echo -e "  ${BOLD}Usage:${NC}"
echo -e "    ${CYAN}/doctor${NC}              Full audit (adaptive scoring)"
echo -e "    ${CYAN}/doctor quick${NC}        TOP-3 priorities (30 seconds)"
echo -e "    ${CYAN}/doctor scan${NC}         Diagnose only"
echo -e "    ${CYAN}/doctor fix${NC}          Apply fixes"
echo -e "    ${CYAN}/doctor layer 0${NC}      Security audit"
echo -e "    ${CYAN}/doctor verify${NC}       Health check"
echo ""
