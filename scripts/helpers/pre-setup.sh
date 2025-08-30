#!/bin/bash
# pre-setup.sh - Create .env and requirements.yaml with menu prompts
# Version: 0.0.4
set -e
ROOT_DIR="$1"  # Passed from vscode.sh

if [ -z "$ROOT_DIR" ]; then
  echo "Error: ROOT_DIR required."
  exit 1
fi

cd "$ROOT_DIR" || exit 1
LOG_DIR="$ROOT_DIR/logs"

# Create required directories
if [ ! -d "$LOG_DIR" ]; then
  echo -n "Warning: $LOG_DIR required."
  mkdir -p "$LOG_DIR"
  echo -e "-[Log Directory: <$LOG_DIR> created]\n"
fi
if [ ! -d "$ROOT_DIR/archives" ]; then
  mkdir -p "$ROOT_DIR/archives"
  echo "- [Archives Directory: <$ROOT_DIR/archives> created]"
fi
if [ ! -d "$ROOT_DIR/tests" ]; then
  mkdir -p "$ROOT_DIR/tests"
  echo "- [Tests Directory: <$ROOT_DIR/tests> created]"
fi

# Default suggestions
DEFAULT_DOMAIN="davit"
DEFAULT_GITHUB_USER="$(git config github.user || echo "DavitTec")"
DEFAULT_AUTHOR="$USER"
DEFAULT_PROJECT_NAME="$(basename "$ROOT_DIR")"
DEFAULT_DEV_DIR="/opt/${DEFAULT_DOMAIN}/development/"
DEFAULT_BIN_DIR="/opt/${DEFAULT_DOMAIN}/bin/"
DEFAULT_GIT_ENABLED="true"
DEFAULT_GITHUB_URL="https://github.com/${DEFAULT_GITHUB_USER}/${DEFAULT_PROJECT_NAME}"
DEFAULT_DIFF_TOOL="diff"
DEFAULT_VISUAL_DIFF="meld"

# Menu prompts
read -p "Domain (default: $DEFAULT_DOMAIN): " DOMAIN
DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}

read -p "Author (default: $DEFAULT_AUTHOR): " AUTHOR
AUTHOR=${AUTHOR:-$DEFAULT_AUTHOR}

read -p "Project Name (default: $DEFAULT_PROJECT_NAME): " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}

read -p "Dev Dir (default: $DEFAULT_DEV_DIR): " DEV_DIR
DEV_DIR=${DEV_DIR:-$DEFAULT_DEV_DIR}

read -p "Bin Dir (default: $DEFAULT_BIN_DIR): " BIN_DIR
BIN_DIR=${BIN_DIR:-$DEFAULT_BIN_DIR}

read -p "Git Enabled (true/false, default: $DEFAULT_GIT_ENABLED): " GIT_ENABLED
GIT_ENABLED=${GIT_ENABLED:-$DEFAULT_GIT_ENABLED}

# SETUP GITHUB 
if [ "$GIT_ENABLED" = "true" ]; then
  read -p "Git User (default: $DEFAULT_GITHUB_USER): " GITHUB_USER
  GITHUB_USER=${GITHUB_USER:-$DEFAULT_GITHUB_USER}

  read -p "Git URL (default: $DEFAULT_GITHUB_URL): " GITHUB_URL
  GITHUB_URL=${GITHUB_URL:-$DEFAULT_GITHUB_URL}
else
  GITHUB_USER=""
  GITHUB_URL=""
fi

read -p "Diff Tool (default: $DEFAULT_DIFF_TOOL): " DIFF_TOOL
DIFF_TOOL="${DIFF_TOOL:-$DEFAULT_DIFF_TOOL}"

read -p "Visual Diff (default: $DEFAULT_VISUAL_DIFF): " VISUAL_DIFF
VISUAL_DIFF=${VISUAL_DIFF:-$DEFAULT_VISUAL_DIFF}

# Generate .env
timestamp=$(date '+%Y%m%d-%H:%M')
cat << EOF > .env
# .env file for vscode.sh
DOMAIN="$DOMAIN"
AUTHOR="$AUTHOR"
PROJECT_NAME="$PROJECT_NAME"
REQUIREMENTS=true
BIN_DIR="$BIN_DIR"
DEV_DIR="$DEV_DIR"
ROOT_DIR="${DEV_DIR}${PROJECT_NAME}"
CREATED="$timestamp"
LAST_VISITED="$timestamp"
VERSION=""
ARCHIVES_DIR="${ROOT_DIR}/archives"
TEMP_DIR="${ROOT_DIR}/tmp/${PROJECT_NAME}"
DB_FILE="${ROOT_DIR}/data/files.json"
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"
TEST_DIR="${ROOT_DIR}/tests/${PROJECT_NAME}.log"
GIT_ENABLED=$GIT_ENABLED
GIT_USER="$GIT_USER"
GITHUB_USER="$GITHUB_USER"
GITHUB_URL="$GITHUB_URL"
DIFF_TOOL="$DIFF_TOOL"
VISUAL_DIFF="$VISUAL_DIFF"
EOF
echo "Generated .env with CREATED=$timestamp"

# Generate requirements.yaml
read -p "Add custom extensions? (y/n): " CUSTOM_EXT
if [ "$CUSTOM_EXT" = "y" ]; then
  read -p "Enter extensions (space-separated IDs): " EXT_INPUT
  EXT_ARRAY=("$EXT_INPUT")
  EXT_YAML=$(printf '  - %s\n' "${EXT_ARRAY[@]}")
else
  EXT_YAML=$(cat << 'EXT'
  - timonwong.shellcheck
  - mads-hartmann.bash-ide-vscode
  - esbenp.prettier-vscode
  - dbaeumer.vscode-eslint
  - christian-kohler.npm-intellisense
  - eamodio.gitlens
  - knisterpeter.vscode-commitizen
  - mhutchie.git-graph
  - rogalmic.bash-debug
EXT
)
fi

cat << EOF > requirements.yaml
extensions:
$EXT_YAML
settings:
  editor.formatOnSave: true
  prettier.enable: true
  eslint.enable: true
  eslint.validate: ["javascript", "typescript"]
  shellcheck.enable: true
  shellcheck.useWorkspaceRootAsCwd: true
  gitlens.hovers.currentLine.over: "line"
  commitizen.path: "cz-conventional-changelog"
  debug.node.autoAttach: "on"
  tasks.runners: ["pnpm run parallel"]
launch:
  configurations:
    - name: Debug vscode.sh
      type: bashdb
      request: launch
      program: "${workspaceFolder}/vscode.sh"
      cwd: "${workspaceFolder}"
      terminalKind: integrated
      args: []
EOF
echo "Generated requirements.yaml"

# Create stub vscode.sh in ROOT_DIR
cat << EOF > vscode.sh
#!/bin/bash
# Stub to call central vscode.sh
/opt/davit/bin/vscode.sh -p "\$(pwd)" "\$@"
EOF
chmod +x vscode.sh
echo "Generated vscode.sh stub"

# Self-delete
rm -- "$0"
echo "Pre-setup complete."

# end of script