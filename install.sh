#!/bin/bash
set -e
# [Dependency needed to manipulate json] jq : `sudo apt-get install jq``
# Note) For each command
#   Make the script executable and create an alias for global access:
#   `alias opw='/home/odoo/GitHub/odoo/odoo-bff/opw.sh'`
#   `chmod +x /home/odoo/GitHub/odoo/odoo-bff/opw.sh`
#   or make it as a function in .bashrc to avoid the alias
#   or use the install script to do everything at once

echo "Installation started..."

if ! command -v jq >/dev/null 2>&1
then
    echo "jq is not found, installing now..."
    sudo apt-get install jq
fi

LOCAL_COMPLETION="$HOME/.local/share/bash-completion/completions"
mkdir -p $LOCAL_COMPLETION
BASHRC_FILE="$HOME/.bashrc"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "Path used : $SCRIPT_DIR"

source "$SCRIPT_DIR/bff.conf"

# -----------------------------------------------------------------------------
# OPW
# -----------------------------------------------------------------------------
cd "opw/"
if ! grep -q 'opw()' "$BASHRC_FILE"; then
    echo "Adding opw command to $BASHRC_FILE"
    echo "" >> "$BASHRC_FILE"
    OPW_PATH="$SCRIPT_DIR/opw/opw.sh"
    export OPW_PATH
    envsubst '$OPW_PATH' < .bashrc_config >> "$BASHRC_FILE"
fi

export TICKETS_PATH
echo "Adding opw completion to $LOCAL_COMPLETION/opw"
envsubst '$TICKETS_PATH' < .bash_completion > "$LOCAL_COMPLETION/opw"
# add exe permission on opw
chmod +x opw.sh

echo "Installation complete!"
