# davit-installer

Advanced INSTALL script for DavitTec projects. Simple version in project roots; advanced in /opt/davit/bin.

## Overview

Handles project setup, env creation, manifest updates, aliases, and integration with helpers like cat2md, logger.

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



Cheatsheets

- [Cheatsheets for davit-installer](docs/cheatsheets.md)
