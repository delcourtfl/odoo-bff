#!/bin/bash
# url shortcut for odoo utils

open_q() {
    local url="$1"
    open "$url" >/dev/null 2>&1 &
}

open_commit() {
    local repo="$1"
    local id="$2"
    case "$repo" in
        oc)
            repo_name="odoo"
            ;;
        oe)
            repo_name="enterprise"
            ;;
        *)
            echo "Usage: commit [oc|oe] <id>"
            return 1
            ;;
    esac
    open_q "https://github.com/odoo/$repo_name/commit/$id"
}

open_pr() {
    local repo="$1"
    local id="$2"
    case "$repo" in
        oc)
            repo_name="odoo"
            ;;
        oe)
            repo_name="enterprise"
            ;;
        *)
            echo "Usage: commit [oc|oe] <id>"
            return 1
            ;;
    esac
    open_q "https://github.com/odoo/$repo_name/pull/$id"
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <tag> [<optional parameters>]"
    exit 1
fi

shortcut="$1"
shift

case "$shortcut" in
    odoo)
        open_q "/home/odoo/GitHub/odoo/"
        ;;
    time-off)
        open_q "https://www.odoo.com/odoo/time-off-overview"
        ;;
    doc)
        open_q "https://www.odoo.com/documentation/"
        ;;
    filestore)
        open_q "/home/odoo/.local/share/Odoo/filestore/"
        ;;
    mail)
        open_q "https://mail.google.com/mail/u/0/#inbox"
        ;;
    tasks)
        open_q "https://www.odoo.com/odoo/project/49/tasks"
        ;;
    pr)
        open_pr "$1" "$2"
        ;;
    commit)
        open_commit "$1" "$2"
        ;;
    mailhog)
        ~/go/bin/MailHog
        ;;
    my-pr)
        open_q "https://github.com/pulls/authored?q=state%3Aopen+archived%3Afalse+sort%3Aupdated-desc+author%3A%40me"
        ;;
    my-tasks)
        open_q "https://www.odoo.com/odoo/my-tasks"
        ;;
    *)
        echo "Unknown command: $cmd"
        ;;
esac
