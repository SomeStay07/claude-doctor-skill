#!/bin/bash
set -e

REPO="https://raw.githubusercontent.com/SomeStay07/claude-doctor-skill/main"
DIR=".claude/skills/doctor"

echo "Installing Doctor Skill..."

mkdir -p "$DIR/layers"

# Main files
curl -sSL "$REPO/SKILL.md" -o "$DIR/SKILL.md"
curl -sSL "$REPO/CHECKLIST.md" -o "$DIR/CHECKLIST.md"

# Layer detail files
for layer in SECURITY FOUNDATION QUALITY QUALITY-EXTRA INTELLIGENCE CONTEXT DX; do
  curl -sSL "$REPO/layers/$layer.md" -o "$DIR/layers/$layer.md"
done

echo ""
echo "Doctor installed to $DIR/"
echo ""
echo "  9 files, 42 checks across 6 layers"
echo ""
echo "  Usage:"
echo "    /doctor              Full audit"
echo "    /doctor scan         Diagnose only"
echo "    /doctor fix          Apply fixes"
echo "    /doctor layer 0      Security audit"
echo "    /doctor verify       Health check"
