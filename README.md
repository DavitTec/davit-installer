# davit-installer

## Overview

`davit-installer` is a production-ready installer for DAVIT projects, adding `INSTALL` commands to projects or running via alias `install+` from `/opt/davit/bin`. It manages environment setup, manifest generation, and validation, ensuring consistency across projects under `/opt/davit/development`. Version 0.0.6 stabilizes .env handling with strict naming and color output fixes.

- **Version**: 0.0.8 (bump patches per commit; use `./scripts/create-manifest.sh --bump patch`)
- **Branch**: patch/v0.0.2-fixes (merge to main after stabilization)
- **GitHub**: https://github.com/DavitTec/davit-installer
- **Changelog**: See CHANGELOG.md for features, fixes, and docs updates.

## Must-Haves

- **Dependencies** (from `requirements.yaml`):

  - `jq`: JSON parsing for manifests.
  - `git`: Version control.

    **Standards**: Use `/opt/davit/development/.env-standard` as global template. Validate with `./scripts/check-env.sh`.

  - `.env`: Example environment `.env-example` and `create-env.sh`

    **Fix Hash Mismatch**:

  - If `requirements.sha256` is for integrity, regenerate it:
    `bash
sha256sum requirements.yaml > .vscode/requirements.sha256
`
  - Or delete if unused (likely a remnant from verifying VSCode deps).
  - Purpose: `requirements.sha256` is typically for verifying file integrity (e.g., in `pre-setup.sh` or `vscode.sh` to check if requirements changed before installing extensions).

  **Ensure yq v4.47.1**:

  - `yq`: YAML parsing for `requirements.yaml`. Install:
  - Verify: `yq --version` (should show 4.47.1 or similar).
  - If not, re-run your install command:

  ```bash
  sudo VERSION=v4.47.1 BINARY=yq_linux_amd64; wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - | tar xz && mv ${BINARY} /usr/local/bin/yq
  ```

  **Folder Naming**: Lowercase, dashes only (no spaces, dots, underscores). E.g., `davit-installer`, not `Davit_Installer`.

## Setup

1. **Clone and Branch**:

   - `git checkout main`
   - `git pull origin main`
   - `git checkout -b patch/v0.0.4-fixes`

2. **Install Dependencies**:

   - From requirements.yaml: jq, git, yq (for YAML parsing).

3. **Environment Stabilization**:

   - Copy `.env-example` to `.env` and customize.
   - Run `./scripts/check-env.sh` to validate against `/opt/davit/development/.env-standard` and requirements.yaml.
   - If errors, fix .env (uppercase underscore keys, no dots/dashes).

4. **Generate Manifest**:

   - `./scripts/create-manifest.sh --create`

5. **Test**:
   - `./test/test-install.sh`

## Scripts

- **check-env.sh**: Validates .env against standard and rules. Required/optional keys from requirements.yaml. Logs to check-env.log.
- **create-env.sh**: Generates .env from .env-example (fix pending; use for now).
- **create-manifest.sh**: Generates manifest.json from scripts (uses check-env.sh).
- **davit-installer.sh**: Main installer (alias install+).
- **helpers/create_script.sh**: Helper for new scripts.

## Environment Stabilization

- **.env Rules**:

  - Keys: Uppercase with underscores (e.g., PROJECT_NAME, no DirectoryName).
  - Values: Prefer expressions for dynamic (e.g., PROJECT_NAME="$(basename "$PWD")")—evaluates when sourced in Bash, but literal in non-Bash (e.g., Docker).
  - Required keys fail validation if missing/invalid; optional warn with defaults.
  - Min keys threshold: Warn if <5 (adjust in check-env.sh).

  **Required .env Keys** (uppercase, underscores only):

  - `ENV_VERSION`: "0001" (version code).
  - `DOMAIN`: Min 3 chars (e.g., "davit").
  - `HOST`: Min 4 chars (e.g., "node").
  - `PROJECT_NAME`: Min 5 chars (matches folder).
  - `VERSION`: Semantic (X.Y.Z, e.g., "0.0.6").
  - `SYNC_LEVEL`: Enum (patch/minor/major).

- **.env-standard** (in /opt/davit/development): Global template with expressions.
- **requirements.yaml**: Defines validation_rules for required/optional keys, types, min_length, regex, defaults.
- **key-list.json**: Full list of possible keys for reference/generation.

## Suggestions and Recommendations

- **Generic Checks**: check-env.sh is flexible for all projects—validates any .env type (.env, .env-local, .env-example).
- **Backward Compatibility**: Use ENV_VERSION in .env to check against standard (warn on mismatch).
- **Variables vs Hardcoding**: Use expressions in .env for portability (e.g., paths auto-detect). Avoid in non-Bash contexts.
- **Deployment**: Once stable, use install+ to deploy to other projects. Sync .env-standard globally.
- **Full Lifecycle**: Sync manifest after patch bumps (if SYNC_LEVEL=patch). Use GitHub Flow for branches/PRs.
- **VSCode**: Use .vscode/ for debugging (launch.json for scripts). Extensions include shellcheck for linting.

## Troubleshooting

- yq Errors: Install yq if using requirements.yaml. Fallback to dummy rules.
- Unbound Variables: Ensure standard loads early.
- Validation Failures: Check log for per-key errors/recommendations.

## TODOs (from docs/todo.md)

- Fix create-env.sh for generic generation.
- Add more keys to key-list.json as projects evolve.
- Integrate check-env.sh into create-manifest.sh.

For questions, open GitHub issue.

## Installation

Run `./INSTALL` or global `/opt/davit/bin/INSTALL --project <name>`.

### Project Creation Procedure

1. Create Directory:

- Path: `/opt/davit/development/<project-name>` (lowercase, dashes).
- `mkdir /opt/davit/development/new-project`

2. Initialize Git:

   ```bash
     cd /opt/davit/development/new-project
     git init
     git remote add origin https://github.com/DavitTec/new-project
   ```

3. Copy Templates:

- cp `/opt/davit/development/.env-standard .env-example`
- `./scripts/create-env.sh` (fix pending).
- Copy `requirements.yaml`, `key-list.json`, `.vscode/`.

4. Setup VSCode:

- `/opt/davit/bin/vscode.sh -p "$(pwd)"`

5. Create Files:

- Use scripts/helpers/create_script.sh for scripts:

  ```bash
  #!/usr/bin/env bash
  # <script-name>.sh
  # Version: 0.0.1
  # Description: <description>
  # Alias: <alias>
  ```

Initialize README.md, CHANGELOG.md, .gitignore.

6. Validate and Commit:

- ./scripts/check-env.sh

```bash
  git add . && git commit -m "chore: initialize project"
  git push origin main
```

7. Archive:

- bashmkdir -p archives/v0.0.1
- rsync -av --exclude 'archives/_' --exclude 'logs/_' --exclude 'tmp/\*' . archives/v0.0.1/

# Scripts

- check-env.sh: Validates .env (v0.0.8).
- create-env.sh: Generates .env (broken, v0.0.2).
- create-manifest.sh: Generates manifest.json (v0.0.5).
- test-install.sh: Tests setup (v0.0.2).
- davit-installer.sh: Main installer (alias install+).
- helpers/create_script.sh: Creates scripts.
- vscode.sh: Sets up VSCode (v0.0.1).
- pre-setup.sh: Initializes projects (v0.0.1).

## Usage

- `--create-env`: Generate .env
- `--bump-version`: Semantic version bump

## Development

Use VSCode with .vscode/ configs. Lint with ShellCheck.

## TODO

See [docs/todo.md](docs/todo.md)

## References

- Cheatsheets
  - [Cheatsheets for davit-installer](docs/cheatsheets.md)
