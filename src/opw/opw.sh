#!/bin/bash
set -e  # Exit on any error
# -----------------------------------------------------------------------------
# Manage git worktrees when debugging tickets:
# Check, create if missing, and setup VSCode configs.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

go_to_worktree() {
    local path="$1"
    local git_path="$2"
    cd "${git_path}"

    # Check if worktree exists and folder is present
    if git worktree list --porcelain | grep -q "^worktree $path$" && [[ -d "$path" ]]; then
        cd "$path"
        return 0
    else
        echo "Worktree or directory missing for path '$path'."
        return 1
    fi
}

create_worktree() {
    local path="$1"
    local git_path="$2"
    local branch="$3"
    local version="$4"
    cd "${git_path}"

    git fetch origin
    # Check branch locally
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo "Using existing branch $branch"
        git worktree add "$path" "$branch" && cd "$path"
    else
        echo "Creating new branch $branch from origin/$version"
        git worktree add -b "$branch" "$path" "origin/$version" && cd "$path"
    fi
}

rename_worktree_branch() {
    local ticket_oc_path="$1"
    local ticket_oe_path="$2"
    local new_branch="$3"

    # Rename OC branch
    cd "$ticket_oc_path"
    git branch -m "$new_branch"

    # Rename OE branch
    cd "$ticket_oe_path"
    git branch -m "$new_branch"

    echo "Renamed worktree branch of '$TICKET_PATH' to '$RENAME_BRANCH'"
}

to_json_array() {
    if [ $# -eq 0 ]; then
        echo '[]'
    else
        printf '%s\n' "$@" | jq -R . | jq -s .
    fi
}

# -----------------------------------------------------------------------------
# Main script
# -----------------------------------------------------------------------------

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# parent folder as default path
ODOO_BFF_PATH="$(realpath "$SCRIPT_DIR/../..")"
# sourcing configuration file
source "$ODOO_BFF_PATH/bff.conf"

# Get ticket opw id
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <ticket_id> [other options: -b branch_to_use, -r new_branch_name]"
    exit 1
fi
TICKET_ID="$1"; shift
BRANCH=""
RENAME_BRANCH=""

# Optional:
# -b branch (create with existing branch)
# -r branch (rename to given branch)
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--branch)     BRANCH="$2"; shift 2 ;;
        -r|--rename)     RENAME_BRANCH="$2"; shift 2 ;;
        *) echo "Unknown option $1"; exit 1;;
    esac
done

# parameters
DB_NAME="bugfix-${TICKET_ID}"
DEV_MODE="xml"

# ticket paths
TICKET_PATH="$TICKETS_PATH/$TICKET_ID"
TICKET_OC_PATH="$TICKET_PATH/odoo"
TICKET_OE_PATH="$TICKET_PATH/enterprise"
PROGRAM_PATH="$TICKET_OC_PATH/odoo-bin"
ADDONS_PATH="$TICKET_OC_PATH/addons,$TICKET_OE_PATH/"

oc_ok=false
oe_ok=false

go_to_worktree "$TICKET_OC_PATH" "$ODOO_OC_PATH" && oc_ok=true
go_to_worktree "$TICKET_OE_PATH" "$ODOO_OE_PATH" && oe_ok=true

if [[ $oc_ok == true && $oe_ok == true ]]; then
    echo "Both OC and OE worktrees OK"
    if [[ -n "$RENAME_BRANCH" ]]; then
        rename_worktree_branch "$TICKET_OC_PATH" "$TICKET_OE_PATH" "$RENAME_BRANCH"
    fi
    if [[ -n "$BRANCH" ]]; then
        echo "-b branch parameter was ignored as worktree exists"
    fi
else
    echo "At least one worktree missing or not ready..."
    VERSION=""

    if [[ -z "$BRANCH" ]]; then
        # no branch/version given
        while [[ -z "$VERSION" ]]; do
            read -rp "Enter base version: " VERSION
            [[ -z "$VERSION" ]] && echo "Version cannot be empty!"
        done
        BRANCH="${VERSION}-opw-${TICKET_ID}--${NAME}"
        echo "Base version: $VERSION"
    else
        VERSION="${BRANCH%%-opw-*}"
        echo "Base version: $VERSION"
    fi

    # For OC
    if [[ $oc_ok != true ]]; then
        create_worktree "$TICKET_OC_PATH" "$ODOO_OC_PATH" "$BRANCH" "$VERSION"
    fi
    # For OE
    if [[ $oe_ok != true ]]; then
        create_worktree "$TICKET_OE_PATH" "$ODOO_OE_PATH" "$BRANCH" "$VERSION"
    fi

    if [[ -n "$RENAME_BRANCH" ]]; then
        # Is OK because the previous branch was not used yet ?
        rename_worktree_branch "$TICKET_OC_PATH" "$TICKET_OE_PATH" "$RENAME_BRANCH"
    fi
fi

VSCODE_PATH="$TICKET_PATH/.vscode"
# Create .vscode directory if it doesn't exist
mkdir -p "${VSCODE_PATH}"

# Only generate launch.json if it does not exist yet
if [ ! -f "${VSCODE_PATH}/launch.json" ]; then

    TEMPLATE_LAUNCH="$ODOO_BFF_PATH/templates/template_launch.json"
    # Generate launch.json from template and update args and program
    jq --arg program "$PROGRAM_PATH" \
        --arg cwd_ticket "$TICKET_OC_PATH" \
        --arg db_name "$DB_NAME" \
        --arg addons_path "$ADDONS_PATH" \
        --arg dev_mode "$DEV_MODE" \
        '
        def odoo_run_args:
            [
            "-d", $db_name,
            "--addons-path=" + $addons_path,
            "--dev=" + $dev_mode,
            "--http-port", "8069",
            "--smtp=0.0.0.0:1025",
            "--smtp-port=0",
            "--smtp-user=admin",
            "--smtp-password=admin"
            ];

        def odoo_test_args:
            [
            "-d", $db_name,
            "--addons-path=" + $addons_path,
            "--dev=" + $dev_mode,
            "-i", "",
            "--test-tags", "",
            "--stop-after-init"
            ];

        .configurations |= map(
            if .name == "Odoo Run" then
                .program = $program
                | .args = odoo_run_args
                | .cwd = $cwd_ticket
            elif .name == "Odoo Test" then
                .program = $program
                | .args = odoo_test_args
                | .cwd = $cwd_ticket
            else
            .
            end
        )
        ' "${TEMPLATE_LAUNCH}" > "${VSCODE_PATH}/launch.json"

    echo "Generated launch.json:"
fi

TEMPLATE_WORKSPACE="$ODOO_BFF_PATH/templates/template_workspace.json"
# Switch ticket_id in workspace
jq --arg ticket "${TICKETS_FOLDER}/${TICKET_ID}/" '
  .folders |=
    (map(select(.path | startswith("${TICKETS_FOLDER}/") | not)) + [{"path": $ticket}])
' ${TEMPLATE_WORKSPACE} > ${WORKSPACE_PATH}

# -----------------------------------------------------------------------------

echo "Ticket ${TICKET_ID} is ready!"

echo "Go to :"

echo "${TICKET_OC_PATH}"
