# davit-installer

Advanced INSTALL script for DavitTec projects. Simple version in project roots; advanced in /opt/davit/bin.

## Overview

Handles project setup, env creation, manifest updates, aliases, and integration with helpers like cat2md, logger.

This project will focus on developing, testing, and deploying the "INSTALL" script as a core helper tool. The simple version will live in each project's root for basic setup, while the advanced version (with options like --create-env, --bump-version, etc.) will be installed globally in /opt/davit/bin/INSTALL to handle project-wide installations, manifest updates, aliases, and metadata.

This setup aligns with Bash scripting best practices (from sources like Google's Bash Style Guide, ShellCheck recommendations, and community tips): use strict mode (set -euo pipefail), modular functions, linting with ShellCheck, consistent directory structures, and semantic versioning. It also supports your DavitTec framework goals: consistency across mono/simple scripts and monorepos, integration with helpers (e.g., logger, cat2md, create_script), and easy deployment/testing.

Assume you're working in a Linux Mint environment with VSCode Insiders, using your existing .env-example and tools. Run these in a terminal from /opt/davit/development/.

Version: 0.0.1

## Installation

Run `./INSTALL` or global `/opt/davit/bin/INSTALL --project <name>`.

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
