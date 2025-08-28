#!/bin/bash
# helpers/create_script.sh

# Source environment variables
# Load environment variables from .env file
[ -f ".env" ] && source ".env"


set -euo pipefail
name=$1
cat <<EOF > "src/$name.sh"
#!/bin/bash
# $name.sh
# Version: 0.0.1  # assume starting version
# Description: [Enter description]
# Author: # src .env for AUTHOR_NAME or use "Your Name" or $whoami
# Created: $(date +%Y-%m-%d)
# Updated: $(date +%Y-%m-%d)
# Usage: $name.sh [args]
# Dependencies: bash (>=5.0)
# Alias: ${name}+  # Example alias for bash: alias ${name}+='/path/to/$name.sh' 
# Status: development
# Requirements: bash, dialog
# Project: scripts_main  # src .env for PROJECT_NAME or use "my_project"
# - optional metadata and dependencies
# Config: Requires CONFIG_FILE (default: config/config.json)
# License: MIT
# SPDX-License-Identifier: MIT
####### /HEADER ######
set -euo pipefail

CONFIG_FILE="\${CONFIG_FILE:-\$(dirname "\$0")/../config/config.json}"
if [[ ! -f "\$CONFIG_FILE" ]]; then
  echo "Error: Configuration file \$CONFIG_FILE not found" >&2
  exit 1
fi
source "\$(dirname "\$0")/../lib/utils.sh"
source "\$(dirname "\$0")/../lib/utils.sh"

readonly SCRIPT_NAME=\$(basename "\$0")
readonly SCRIPT_VERSION="0.0.1"

main() {
  echo "Hello from $name"
}

main "\$@"

### end of script ###

### ToDo ###
#TODO - Add logging function
EOF
chmod +x "src/$name.sh"

### end of script ###

### ToDo ###
#TODO - Add logging function