#!/bin/bash
set -e  # Exit on any error

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ODOO_BFF_PATH="$(realpath "$SCRIPT_DIR/../..")"
source "$ODOO_BFF_PATH/bff.conf"

log "Ticket folders with OPW IDs but no remote branches containing the OPW ID:"
log "-----------------------------------------------------------------------"

# Folder containing ticket folders
for folder in "$TICKETS_PATH"/*; do
    [ -d "$folder" ] || continue

    opw_id=$(basename "$folder")
    # Keep only id (separators: - or _)
    opw_id="${opw_id%%[-_]*}"

    # Check Odoo Community repo for remote branches with the OPW ID
    odoo_matches=$(git -C "$ODOO_OC_PATH" branch -r | grep "opw-$opw_id" | grep "$NAME")

    # Check Enterprise repo for remote branches with the OPW ID
    enterprise_matches=$(git -C "$ODOO_OE_PATH" branch -r | grep "opw-$opw_id" | grep "$NAME")

    # If no matches in either repo, print the ticket folder
    if [ -z "$odoo_matches" ] && [ -z "$enterprise_matches" ]; then
        log "$folder"

        last_commit_oc=$(git -C "${folder}/odoo" log -1 --pretty=format:"%h %s")
        log "OC: $last_commit_oc"
        last_commit_oe=$(git -C "${folder}/enterprise" log -1 --pretty=format:"%h %s")
        log "OE: $last_commit_oe"

        read -p "Do you want to delete this worktree? [y/n]: " yn
        case "$yn" in
            [Yy]* )
                log "Deleting $folder"
                [ -d "$folder/odoo" ] && \
                    git -C "$ODOO_OC_PATH" worktree remove "${folder}/odoo"

                [ -d "$folder/enterprise" ] && \
                    git -C "$ODOO_OE_PATH" worktree remove "${folder}/enterprise"

                # TODO clean delete ?
                rm "${folder}/.vscode/launch.json"
                rmdir "${folder}/.vscode"
                rmdir "${folder}"

                # Also clean database/filestore with id in its name ?
                # Keep filestore manual for now

                # List databases containing the OPW ID
                dbs_to_drop=$(psql -Atc "SELECT datname FROM pg_database WHERE datname LIKE '%$opw_id%';")
                if [ -n "$dbs_to_drop" ]; then
                    log "Databases found:"
                    echo "$dbs_to_drop"

                    read -p "Do you want to drop these databases? [y/n]: " drop_confirm
                    if [[ "$drop_confirm" =~ ^[Yy] ]]; then
                        for db in $dbs_to_drop; do
                            echo "Dropping database: $db"
                            dropdb "$db"
                        done
                    fi
                else
                    log "No databases found with id $opw_id"
                fi
                ;;
            * )
                log "Skipping"
                ;;
        esac
        log "------------------------------"
    fi
done
