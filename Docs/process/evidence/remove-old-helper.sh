#!/usr/bin/env bash
# remove-old-helper.sh — rebuild step P0.1. Run with sudo.
# Unloads the old privileged helper and keeps launchd from loading it again.
set -uo pipefail
LABEL=com.jctec.zhen.helper
[ "$(id -u)" = 0 ] || { echo "Run with sudo."; exit 1; }
echo "== before"; launchctl print "system/$LABEL" 2>&1 | grep -E 'type =|state =|BTM uuid' || true
launchctl bootout "system/$LABEL" 2>&1 || true
launchctl disable "system/$LABEL"
echo "== after"; launchctl print "system/$LABEL" 2>&1 | head -1
launchctl print-disabled system | grep "$LABEL"
