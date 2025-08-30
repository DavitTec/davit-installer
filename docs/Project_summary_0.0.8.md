# Project summary

## Comprehensive Summary of Project "davit-installer" (Branch: patch/v0.0.2, Version 0.0.7 Snapshot)

Assistant: Grok <https://grok.com/chat/05e18d66-6668-4e01-b812-f25394bff222>

This summary compiles all comments, rules, recommendations, and suggestions from our conversation (#013 to #019) into a self-contained overview.

It serves as a stable base for opening a new Grok chat. The project is at version 0.0.8 (as per your last stable state) in git branch `patch/v0.0.2-fixes`, with proposed fixes for 0.0.8 focusing on debugging `check-env.sh`.

This summary is organised for clarity, avoiding conflicts by prioritising your stated rules (e.g., uppercase underscore keys, patch bumps per commit, archiving per patch without frequent commits during debugging).

### Project Overview

- **Purpose**: `davit-installer` is a production-ready installer for DAVIT projects, adding `INSTALL` commands to other projects or running from `/opt/davit/bin` via alias `install+`.
  - It focuses on full-circle lifecycle development:
    - standardizing script structures,
    - .env generation/validation,
    - manifest synchronization with a master manifest in `/opt/davit/development/`, and
    - integration with helpers like `vscode.sh` and `pre-setup.sh`.

- **The goal**:  To stabilise environment variables (.env), and project requirements for all projects, ensuring backward compatibility, and enforcing strict conventions to fix old scripts/systems and flexibility for portability in future systems, from Linux, Mac or Win to .
- **Current Branch**: `patch/v0.0.2-fixes` (started from v0.0.1, with patch bumps for each change without committing until stable). Stay on this branch until a test passes; no new branch needed.
- **Versioning Process**: Patch bumps project (e.g., 0.0.7 to 0.0.8) for every change, even during debugging. Update .env VERSION to match any included script, then gzip archive all files (except logs/tmp/archives) to `archives/vX.Y.Z/`. Also, after each Project version bumps, a `cat2md` comand will public all scripts, tree and file structure into `archives/files|tree_vX.Y.Z.md`. This avoids frequent commits for small fixes. Use `./scripts/create-manifest.sh --bump patch` once stable. Archiving command: `mkdir -p archives/v0.0.8 && rsync -av --exclude 'archives/*' --exclude 'logs/*' --exclude 'tmp/*' . archives/v0.0.8/`.
- **Project Structure (from tree_v0.0.7.txt snapshot)**: Root under `/opt/davit/development/davit-installer`.
  - Directories: `docs/` (cheatsheets.md, todo.md, hist/), `scripts/` (check-env.sh, create-env.sh, create-manifest.sh, davit-installer.sh, helpers/create_script.sh), `test/` (test-install.sh), `tests/` (sample_manifest.json), `.vscode/` (extensions.json, launch.json, requirements.sha256, settings.json), `logs/` (check-env.log), `archives/` (for patch archives).
  - Files: CHANGELOG.md, cliff.toml, debug-create-manifest.sh.txt, .env, .env-example, .gitignore, INSTALL, README.md, requirements.yaml, vscode.sh.
- **Dependencies**: From `requirements.yaml`: jq, git, yq (installed via sudo wget/tar command for v4.47.1). VSCode extensions (shellcheck, gitlens, etc.) for development.
- **Key Tools**: yq for parsing requirements.yaml (critical for validation_rules). ShellCheck for linting scripts. Bash for execution (dependent on OS/Bash version for regex).

#### Key Components and Files

- **.env-standard** (in /opt/davit/development): Global template with uppercase underscore keys, expressions for dynamic values (e.g., PROJECT_NAME="$(basename "$PWD")"). Used as reference for validation.
  - There is a symlink of `.env-standard` located in `./tests/` for reference or use.

- **.env-example**: Project-specific template, copied from .env-standard.
- **.env**: Project .env, generated from .env-example via create-env.sh (broken, needs fixing for generic use).
- **requirements.yaml**: Defines dependencies and validation_rules (required/optional keys, type, min_length, regex, error_code, help_comment).
  - Used by check-env.sh for validation. Not redundant—centralises rules for must-have keys.
  - Also used by other scripts, like vscode.sh.  
  - **Note**: this file open to be used by more than one script ultimately

- **key-list.json**: JSON reference for all possible .env keys (key, type, required, description). Expanded format for integration; use for prechecks instead of embedded keys. Format: array of objects.
- **check-env.sh** (v0.0.8): Validates .env against .env-standard and requirements.yaml. Modular functions for file existence, loading, validation. Logs pass/fail per key to logs/check-env.log. Errors fixed: line reading for expressions, regex validation, yq parsing, help_comment extraction.
- **Other Scripts**: create-env.sh (broken, v0.0.2—generates .env), create-manifest.sh (broken v0.0.4—generates manifest.json, calls check-env.sh, ), test-install.sh (broken v0.0.3—tests), vscode.sh (broken, v0.0.9—sets up VSCode), pre-setup.sh (broken, v0.0.4—initializes projects), helpers/create_script.sh (creates scripts with standard header).
  - **Note**: ./helpers/*scripts* were previously deployed in '/opt/davit/bin' but since this Project development and restructuring, these helper scripts will need fixing/updated in there own projects, however, they can be fixed here to keep development in sync.

#### Rules and Standards

- **.env Rules**: Uppercase keys with underscores only (e.g., PROJECT_NAME, DIR_NAME). No dots/dashes. Values can use Bash expressions for dynamic (e.g., "$(basename "$PWD")" for auto-detection—evaluated when sourced). Required keys fail validation if missing/invalid; optional warn with defaults.
- Feature: Min keys threshold (5) warns if low. This is a consideration for now but each project has its independent requirements. Precheck expressions for resulting value (e.g., if "$" present, verify data).
- **Folder Naming**: Lowercase, dashes only (no spaces, dots, underscores). Project root in /opt/davit/development, monorepos in /opt (exceptions in manifest.json).

  - folder name check and or renaming, which include search and replace in project maybe a necessary extra feature for another project utility tool

- **Script Headers**: Strict format:

  - I have started to create a create-script.sh utility that has a more comprehensive creation features as part of a create-project toolset. However, all these tools and ultities need upgrading to follow this project.

  - below is the basic script header and footer.

  ```bash
  #!/usr/bin/env bash
  # <script-name>.sh
  # Version: X.Y.Z (patch bump per change)
  # Description: <description>
  # Alias: <aliases>
  
  <code here>
  # end of script
  # ToDo section
  <add TODO lines below>
  ```

  - most script will have "TODO" and or "FIXME" lines added to allow for easy script fixes or enhancements. This data can be captures my other helper scripts and or vscode TODO extensions

- **Versioning**: Patch bumps for every change (even debugging). Update .env VERSION, archive files to archives/vX.Y.Z/.
- **Regex Dependency**: Regex is OS/Bash-dependent (e.g., GNU vs BSD grep). Use `grep -qE -- "$regex"` for safety.
- **Required/Optional Keys**: From requirements.yaml—required are breaking (e.g., DOMAIN, PROJECT_NAME); optional non-critical (e.g., GIT_ENABLED with default false).
- **Archiving**: Per patch, copy all files (exclude archives/logs/tmp) to archives/vX.Y.Z/. For snapshots, use the `cat2md` utility during debugging without commits but only works with project version bump not script version pump.
- **VSCode**: .vscode/ for debugging (launch.json for scripts). Extensions include shellcheck for linting add more.

#### Current Issues and Errors (from #018 Output)

- **Invalid Line Errors**: Lines with expressions (e.g., `PROJECT_NAME="$(basename "$PWD")"`) flagged as invalid and skipped. Fixed by updating regex to handle nested quotes and commands.
- **Invalid Format Errors**: All keys fail with `Invalid format (must match key)` due to regex check bug (misapplied to non-regex keys, incorrect handling of pipes in regex like `^ghp_...|^$`). Fixed by conditional regex check and safe grep.
- **WARN for GITHUB_TOKEN**: Missing optional key—correct, but help_comment was "Unknown" due to parsing failure. Fixed to show "GitHub access token (or empty)".
- **E999 Codes**: yq failure or fallback to dummy—fixed with better yq checks and dummy rules.
- **DirectoryName**: Check no invalid key (not uppercase underscore)—fixed by flagging and skipping, ensure replaced with DIR_NAME in .env-standard/.env.
- **Fix key duplicates.**: `key-list.json` should be consider he master key list and referenced is KEY are similar or duplicate and or malformed. This file may need enhancement to cover all exceptions and new projects.

#### Recommendations and Suggestions for Fixing Next Version Patches (0.0.8+)

- **Verbose Debug Feedback**: Add a `--debug` flag to `check-env.sh` for more output (e.g., echo "Processing line $line_num: $line" in load_env_file). Use `bash -x` for full trace.
- **File Existence Check**: Add a function `check_files_exist` to verify .env, .env-example, .env-standard, key-list.json, requirements.yaml. Exit with ERROR if missing.
- **Expand key-list.json**: Use expanded format (key, expected_type, error_code, key_desc, status). Integrate in `check-env.sh` by loading key-list.json with jq for validation instead of embedded keys (e.g., `jq -r '.[] | .key + " " + .type + " " + .error_code + " " + .description' key-list.json`).
- **Precheck Expressions**: Add a function `precheck_expression` to evaluate values with "$" (e.g., if [[ "$tgt_value" =~ \$ ]]; then eval "value=$tgt_value" 2>/dev/null || log ERROR; fi). This verifies resulting data before regex, avoiding redundant errors.
- **Regex Dependency**: Test regex on your OS/Bash (e.g., GNU grep on Linux Mint). Use `grep -E` for portability, avoid complex pipes in regex (use separate checks).
- **Error Levels**: Log levels: PASS (info), WARN (non-breaking, optional keys), FAIL (required keys), ERROR (script failures like missing files).
- **yq/requirements.yaml**: Ensure yq v4.47.1. If errors, test `yq e . requirements.yaml`. Update requirements.yaml with all keys from key-list.json.
- **Rethink Strategy**: For new chat, start with stabilized base: fixed `check-env.sh` v0.0.8, updated .env-standard, requirements.yaml, key-list.json. Use modular functions for file checks, expression prechecks, and KEY-list integration. Test simple cases (1 key) before full .env.
- **General**: Avoid embedded keys—use key-list.json for flexibility. Patch bump per change, archive without commits during debugging. Once stable, fix `create-env.sh` to generate .env from key-list.json and requirements.yaml.

## TODO

### Feature requests

- Add and set KEY Value for "LANG"="en-uk"
- the check-env.sh must be modular and fuctional
  - check and process `.env-standard` first
    1. check if script ENV_VERSION="0001" of `check-env.sh` and `.env-standard` are equal.
    2. consider  converting and deleting `.env-standard` with and expanded ``key-list.json` `. This would break `check-env.sh` and other associate scripts.
    3. including above, extend `key-list.json` to include; comment, error_id, command, sample-txt, url (for docs), options etc.  Putting `key-list.json`  as the main file for creating, checking, updated and resorting project .env(s)
  - To reduce the need for complex Regex, consider BLOCK search and replace. loops ie mark key-value lines with $ or not, delete lines a starting with #, clean up extra spaces or tabs.  remove lines with no key (in **`key-list.json`**), mark lines with not value. and sort and group. Also, listing and processing keys which are listed in requirements.yaml as an array keys_required (array).

- If check-env.sh can cer to a PASS state, then we redesign create.env and others
- update markdownlint and shellcheck config to impove linting and less errors
  - allow no line wrap limit
  - set language to UK english
  - add cspell extension and config
  - dont break tables

- we need to fix vscode.sh to check requirements.yaml and vscode extentions are loaded

This summary covers all our comments (e.g., rules for keys/expressions, archiving, version bumps, modular functions, verbose debug, file checks, KEY-list expansion, regex/OS dependency). Use it as the starting point for your new Grok chat, including the snapshot from `combined.md` (v0.0.7 state). If needed, attach updated files in the new chat.
