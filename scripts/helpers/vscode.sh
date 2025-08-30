#!/bin/bash
# vscode.sh
# Version: 0.0.9
# Alias: code+
# Description: A bash script for setting up VSCode-Insiders with project-specific variables
# Requirements: yq for YAML parsing, .env for configuration
# Usage: ./vscode.sh [-p|--project <dir>] [--force] [--clean] [--typora]
# Exit on errors (but handle extension install failures gracefully)
set -e
# Parse arguments
PROJECT_DIR=""
FORCE=false
CLEAN=false
TYPORA=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -p|--project) PROJECT_DIR="$2"; shift ;;
    --force) FORCE=true ;;
    --clean) CLEAN=true ;;
    --typora) TYPORA=true ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done
# Set ROOT_DIR from -p, prepending DEV_DIR if relative
DEV_DIR="/opt/davit/development/"
if [ -n "$PROJECT_DIR" ]; then
  if [[ "$PROJECT_DIR" = /* ]]; then
    ROOT_DIR="$PROJECT_DIR"
  else
    ROOT_DIR="$DEV_DIR$PROJECT_DIR"
  fi
else
  ROOT_DIR="$(pwd)"
fi
# Check if ROOT_DIR exists and is under DEV_DIR
if [ ! -d "$ROOT_DIR" ] || [[ ! "$ROOT_DIR" = "$DEV_DIR"* ]]; then
  echo "Error: ROOT_DIR ($ROOT_DIR) must be under $DEV_DIR and exist."
  exit 1
fi
cd "$ROOT_DIR" || exit 1
ENV_FILE="$ROOT_DIR/.env"
REQUIREMENTS_FILE="$ROOT_DIR/requirements.yaml"
README_FILE="$ROOT_DIR/README.md"
VSCODE_DIR="$ROOT_DIR/.vscode"
SETTINGS_FILE="$VSCODE_DIR/settings.json"
EXTENSIONS_FILE="$VSCODE_DIR/extensions.json"
LAUNCH_FILE="$VSCODE_DIR/launch.json"
PROJECT_NAME=$(basename "$ROOT_DIR")
PROFILE_NAME="Project-$PROJECT_NAME"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/$PROJECT_NAME.log"
# Logging function
log() {
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  if [ -n "${LOG_FILE:-}" ] && [ -d "$LOG_DIR" ] && [ -w "$LOG_DIR" ]; then
    echo "[$timestamp] $1" >> "$LOG_FILE"
  else
    echo "[$timestamp] $1" >&2
  fi
}
# Run pre-setup if missing files
if [ ! -f "$ENV_FILE" ] || [ ! -f "$REQUIREMENTS_FILE" ]; then
  log "Missing .env or requirements.yaml; running pre-setup.sh"
  if [ ! -f "/opt/davit/bin/pre-setup.sh" ]; then
    log "Error: /opt/davit/bin/pre-setup.sh not found. Run install.sh first."
    exit 1
  fi
  /opt/davit/bin/pre-setup.sh "$ROOT_DIR"
fi
# Source .env
if [ ! -f "$ENV_FILE" ]; then
  log "Error: .env file not found at $ENV_FILE"
  exit 1
fi
(
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  # shellcheck disable=SC2034
  readenv=true  # for debugging
  export LAST_VISITED LOG_FILE GIT_ENABLED GIT_USER GIT_URL
) || log "Warning: Error sourcing $ENV_FILE; proceeding with limited env."
# Validate LOG_FILE
if [ -n "${LOG_FILE:-}" ] && { [ ! -d "$LOG_DIR" ] || [ ! -w "$LOG_DIR" ]; }; then
  log "Warning: LOG_FILE ($LOG_FILE) directory invalid or unwritable; logging to stderr."
  unset LOG_FILE
fi
# Validate Git settings
if [ "${GIT_ENABLED:-false}" = "true" ]; then
  if [ -z "${GIT_USER:-}" ] || [ -z "${GIT_URL:-}" ]; then
    log "Error: GIT_ENABLED=true requires GIT_USER and GIT_URL in .env"
    exit 1
  fi
  if ! git remote get-url origin >/dev/null 2>&1; then
    log "Setting git remote to $GIT_URL"
    git remote add origin "$GIT_URL" || log "Warning: Failed to set git remote"
  fi
fi
# Check if yq is installed
if ! command -v yq &> /dev/null; then
  log "Error: 'yq' is required to parse $REQUIREMENTS_FILE. Install it (e.g., 'sudo apt-get install yq')."
  exit 1
fi
# Check if using code-insiders
if command -v code &> /dev/null && ! command -v code-insiders &> /dev/null; then
  log "Warning: Found 'code' but not 'code-insiders'. This script requires VSCode-Insiders."
  exit 1
elif ! command -v code-insiders &> /dev/null; then
  log "Error: 'code-insiders' not found in PATH. Install VSCode-Insiders."
  exit 1
fi
# Check if requirements.yaml exists and is valid
if [ ! -f "$REQUIREMENTS_FILE" ]; then
  log "Error: $REQUIREMENTS_FILE not found in project root."
  exit 1
fi
if ! yq e '.extensions and .settings and .launch' "$REQUIREMENTS_FILE" >/dev/null 2>&1; then
  log "Error: $REQUIREMENTS_FILE missing required keys (extensions, settings, launch)."
  exit 1
fi
# Create .vscode directory if it doesn't exist
if [ ! -d "$VSCODE_DIR" ]; then
  mkdir -p "$VSCODE_DIR"
  log "Created $VSCODE_DIR"
fi
# Generate .vscode files if missing or --force
if [ ! -f "$SETTINGS_FILE" ] || [ "$FORCE" = true ]; then
  yq e '.settings' "$REQUIREMENTS_FILE" -o json > "$SETTINGS_FILE"
  log "Generated $SETTINGS_FILE from $REQUIREMENTS_FILE"
else
  log "$SETTINGS_FILE already exists, skipping creation."
fi
if [ ! -f "$EXTENSIONS_FILE" ] || [ "$FORCE" = true ]; then
  yq e '.extensions | { "recommendations": . }' "$REQUIREMENTS_FILE" -o json > "$EXTENSIONS_FILE"
  log "Generated $EXTENSIONS_FILE from $REQUIREMENTS_FILE"
else
  log "$EXTENSIONS_FILE already exists, skipping creation."
fi
if [ ! -f "$LAUNCH_FILE" ] || [ "$FORCE" = true ]; then
  yq e '.launch | { "version": "0.2.0", "configurations": .configurations }' "$REQUIREMENTS_FILE" -o json > "$LAUNCH_FILE"
  log "Generated $LAUNCH_FILE from $REQUIREMENTS_FILE"
else
  log "$LAUNCH_FILE already exists, skipping creation."
fi
# Check requirements.yaml checksum for auto-force
if [ -f "$REQUIREMENTS_FILE" ] && [ -f "$VSCODE_DIR/requirements.sha256" ] && [ "$(sha256sum "$REQUIREMENTS_FILE" | cut -d' ' -f1)" != "$(cat "$VSCODE_DIR/requirements.sha256")" ]; then
  FORCE=true
  log "Detected changes in $REQUIREMENTS_FILE; forcing regeneration of .vscode files."
fi
sha256sum "$REQUIREMENTS_FILE" | cut -d' ' -f1 > "$VSCODE_DIR/requirements.sha256"
# Create profile if it doesn't exist
if ! code-insiders --list-extensions --profile "$PROFILE_NAME" &>/dev/null; then
  log "Profile $PROFILE_NAME does not exist. Creating it..."
  temp_dir=$(mktemp -d)
  code-insiders "$temp_dir" --profile "$PROJECT_NAME" --new-window >/dev/null 2>&1 &
  PID=$!
  for i in $(seq 1 20); do
    if code-insiders --list-extensions --profile "$PROJECT_NAME" &>/dev/null; then
      break
    fi
    sleep 0.1
  done
  kill $PID >/dev/null 2>&1 || true
  rm -rf "$temp_dir"
  if ! code-insiders --list-extensions --profile "$PROJECT_NAME" &>/dev/null; then
    log "Failed to create profile $PROJECT_NAME. Check VSCode-Insiders installation."
    exit 1
  fi
  log "Profile $PROJECT_NAME created."
else
  log "Profile $PROJECT_NAME already exists."
fi
# Clean unused extensions if --clean
if [ "$CLEAN" = true ]; then
  log "Cleaning extensions not in $REQUIREMENTS_FILE..."
  INSTALLED_EXTENSIONS=$(code-insiders --list-extensions --profile "$PROFILE_NAME" 2>/dev/null || true)
  while IFS= read -r installed_ext; do
    if ! yq e ".extensions.[] | select(. == \"$installed_ext\")" "$REQUIREMENTS_FILE" >/dev/null 2>&1; then
      if code-insiders --uninstall-extension "$installed_ext" --profile "$PROFILE_NAME"; then
        log "Uninstalled unused extension $installed_ext from profile $PROFILE_NAME"
      else
        log "Warning: Failed to uninstall extension $installed_ext"
      fi
    fi
  done <<< "$INSTALLED_EXTENSIONS"
fi
# Install extensions to the profile
INSTALLED_EXTENSIONS=$(code-insiders --list-extensions --profile "$PROFILE_NAME" 2>/dev/null || true)
while IFS= read -r ext; do
  # Skip version parsing unless @ is explicitly in the extension
  if [[ "$ext" == *@* ]]; then
    ext_id=${ext%%@*}
    ext_version=${ext#*@}
  else
    ext_id="$ext"
    ext_version=""
  fi
  if echo "$INSTALLED_EXTENSIONS" | grep -Fx "$ext_id" >/dev/null; then
    log "Extension $ext_id already installed in profile $PROFILE_NAME, skipping."
  else
    if code-insiders --install-extension "$ext_id${ext_version:+@$ext_version}" --profile "$PROFILE_NAME" --force; then
      log "Installed extension $ext_id${ext_version:+@$ext_version} to profile $PROFILE_NAME"
    else
      log "Warning: Failed to install extension $ext_id${ext_version:+@$ext_version}. Continuing..."
    fi
  fi
done < <(yq e '.extensions.[]' "$REQUIREMENTS_FILE")
# Determine launch command: Check if >1 day since last visit
OPEN_CMD="code-insiders . --profile \"$PROFILE_NAME\""
if [ -n "${LAST_VISITED:-}" ] && [ -f "$README_FILE" ]; then
  last_sec=$(date -d "$LAST_VISITED" +%s 2>/dev/null || echo 0)
  if [ "$last_sec" -eq 0 ]; then
    log "Warning: Invalid LAST_VISITED format; opening normally."
  else
    curr_sec=$(date +%s)
    diff_days=$(( (curr_sec - last_sec) / 86400 ))
    if [ "$diff_days" -gt 1 ]; then
      todo_line=$(grep -n '^#\{1,2\} TODO' "$README_FILE" | cut -d: -f1 | head -1)
      if [ -n "$todo_line" ]; then
        OPEN_CMD="code-insiders . --goto \"$README_FILE:$todo_line:1\" --profile \"$PROFILE_NAME\""
        log "Project not opened in over a day; opening README.md at TODO section."
        if [ "$TYPORA" = true ]; then
          if command -v typora >/dev/null 2>&1; then
            typora "$README_FILE" >/dev/null 2>&1 &
            log "Opened README.md in Typora."
          else
            log "Warning: Typora not installed; skipping."
          fi
        fi
      else
        log "Warning: TODO section not found in README.md; opening normally."
      fi
    else
      log "Project opened recently; restoring last session."
    fi
  fi
else
  log "No valid LAST_VISITED or README.md; opening normally."
fi
# Launch VSCode-Insiders
eval "$OPEN_CMD"
log "VSCode-Insiders launched with profile '$PROFILE_NAME' for project '$PROJECT_NAME'."
# Update .env with last visited timestamp
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
if grep -q "^LAST_VISITED=" "$ENV_FILE"; then
  sed -i "s/^LAST_VISITED=.*/LAST_VISITED=\"$timestamp\"/" "$ENV_FILE"
else
  echo "LAST_VISITED=\"$timestamp\"" >> "$ENV_FILE"
fi
log "Updated LAST_VISITED in .env to \"$timestamp\"."
# end of script