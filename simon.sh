#!/bin/bash

# Usage:
#
# 1. Place the script in a dedicated directory, e.g., "./simon/simon.sh".
# 2. cd to the folder.
# 3. Run the script and follow the prompts. If it's the first run, then
#    you'll be informed that a snapshot named "simon.old" has been created.

SNAPSHOT_OLD='simon.old'
SITE='http://simonstalenhag.se/'
SITE_FILTER='s/.$//;/^$/d;s/^[[:space:]]*//;s/[[:space:]]*$//'
SNAPSHOT_NEW=$(curl -ks "$SITE" | sed -e "$SITE_FILTER")

# overwrite the old snapshot?
ask_overwrite() {
    printf '\n'
    while true ; do
        read -rp 'Overwrite the old snapshot (y/n)? ' yn
        case "$yn" in
            [Yy]* )
                printf '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
                printf 'Snapshot overwritten'
                break;;
            [Nn]* )
                printf 'Snapshot untouched';
                break;;
            * )
                printf 'Please answer yes or no\n';;
        esac
    done
}

# fetch link(s) from diff and download pic(s)
fetch_and_download() {
    local _links
    _links=$(printf '%s' "$1" \
        | grep -E '^>' | cut -d '"' -f 2 | grep -i '.jpe\?g' | sort -u)
    printf '\n'
    if [ -n "$_links" ]
        then
            local _fname
            # show a list of fetched link(s)
            printf 'Fetched links:\n%s\n\n' "$_links"
            for link in $_links; do
                _fname=$(printf '%s\n' "$link" | cut -d '/' -f 2)
                # ask if a user wishes to save the file from the fetched link
                while true; do
                    read -rp "Save \"$_fname\" (y/n)? " yn
                    case "$yn" in
                        [Yy]* )
                            wget -nv "$SITE$link";
                            break;;
                        [Nn]* )
                            #printf 'Skipping...'
                            break;;
                        * )
                            printf 'Please answer yes or no\n';;
                    esac
                done
            done
        else
            printf 'No links fetched...\n\n'
            printf -- '-----BEGIN DIFF BLOCK-----\n'
            printf '%s\n' "$1"
            printf -- '-----END DIFF BLOCK-----\n'
    fi
    ask_overwrite
}

# is there something new?
find_diffs() {
    local _diffs
    _diffs=$(printf '%s' "$SNAPSHOT_NEW" | diff "$SNAPSHOT_OLD" -)
    printf '\n'
    if [ -n "$_diffs" ]
        then
            printf 'Snapshots are different\n'
            fetch_and_download "$_diffs"
        else
            printf 'Snapshots are the same\n'
    fi
}

# is there simon.old file?
if [ -f "$SNAPSHOT_OLD" ]
    then
        printf 'Snapshot "%s" found\n' "$SNAPSHOT_OLD"
        find_diffs
    else
        printf 'Snapshot "%s" not found\n' "$SNAPSHOT_OLD"
        printf '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
        printf 'Snapshot of the site saved as "%s"\n' "$SNAPSHOT_OLD"
fi
