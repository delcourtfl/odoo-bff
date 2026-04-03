#!/bin/bash
set -e  # Exit on any error

check_worktree() {
    local path="$1"
    local git_path="$2"
    cd "${git_path}"

    # Check if worktree exists and folder is present
    if git worktree list --porcelain | grep -q "^worktree $path$" && [[ -d "$path" ]]; then
        return 0
    else
        echo "Worktree or directory missing for path '$path'."
        return 1
    fi
}

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ODOO_BFF_PATH="$(realpath "$SCRIPT_DIR/../..")"
source "$ODOO_BFF_PATH/bff.conf"

CURRENT_PATH=$( git rev-parse --show-toplevel )
if [[ "$CURRENT_PATH" == */odoo ]]; then
    CURRENT_TYPE="OC"
    TARGET_PATH="${CURRENT_PATH%/odoo}/enterprise"
elif [[ "$CURRENT_PATH" == */enterprise ]]; then
    CURRENT_TYPE="OE"
    TARGET_PATH="${CURRENT_PATH%/enterprise}/odoo"
else
    log "Not inside an OC/OE worktree"
    exit 1
fi

BRANCH_NAME=$( git branch --show-current )

log "Sync OC / OE ..."
log "Copy branch state from $CURRENT_PATH into $TARGET_PATH"
log $BRANCH_NAME

curr_ok=false
targ_ok=false

if [[ "$CURRENT_TYPE" == "OE" ]]; then
    check_worktree "$CURRENT_PATH" "$ODOO_OE_PATH" && curr_ok=true
    check_worktree "$TARGET_PATH" "$ODOO_OC_PATH" && targ_ok=true
else
    check_worktree "$CURRENT_PATH" "$ODOO_OC_PATH" && curr_ok=true
    check_worktree "$TARGET_PATH" "$ODOO_OE_PATH" && targ_ok=true
fi

# Check that both paths are valid
if ! [[ $curr_ok == true && $targ_ok == true ]]; then
    log "At least one worktree missing or not ready..."
    exit 1
fi

cd $CURRENT_PATH
UPSTREAM=$( git rev-parse --abbrev-ref $BRANCH_NAME@{upstream} )
if [[ -z "$UPSTREAM" ]]; then
    log "No upstream set on $CURRENT_PATH for $BRANCH_NAME."
    exit 1
fi

log $UPSTREAM

cd $TARGET_PATH
git fetch --multiple origin dev

if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    git checkout $BRANCH_NAME
else
    git checkout -b $BRANCH_NAME $UPSTREAM
fi

log "OC/OE Synchronized"
