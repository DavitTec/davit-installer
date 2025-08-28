#!/usr/bin/env bash
# vscode.sh
# Version: 0.0.1
# Description: Stub to call central vscode.sh for project setup.
# Alias: Generic

# Call central vscode.sh (no duplicates; assumes central handles env/manifest)
 /opt/davit/bin/vscode.sh -p "$(pwd)" "$@"

# End of vscode.sh