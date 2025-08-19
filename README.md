# Odoo Bugfix Flow

`opw.sh` - script to manage **Git worktrees** for Odoo tickets and configure VSCode for development and debugging.

---

## Features

- Checks if Odoo worktrees exist for a given ticket.
- Creates missing worktrees based on a branch or base version.
- Optionally renames worktree branches.
- Automatically generates VSCode `.vscode/launch.json` for debugging.
- Updates the Odoo workspace file with the current ticket folder.

---

## Prerequisites

- `git` installed
- `jq` for JSON manipulation:

```bash
sudo apt-get install jq
```

## Usage

```bash
bash opw.sh <ticket_id> [options]
```

## Options

```
-b, --branch <branch_name>: Use an existing branch for the ticket.
-r, --rename <new_branch_name>: Rename the ticket worktree branch.
```
