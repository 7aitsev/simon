#!/bin/bash

# Usage:
#
# 1. place the script in a directory, i.e. "./simon/simon.sh"
# 2. cd to the folder
# 3. run the script (if it is the first run, then you'll be prompted just to create a snapshot of the site
#     - file called "simon.old") and follow the prompts.

SNAPSHOT_OLD='simon.old'
BASE='http://simonstalenhag.se/'
SNAPSHOT_NEW=$(curl -ks "$BASE" | sed -e 's/.$//;/^$/d;s/^[[:space:]]*//;s/[[:space:]]*$//')

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
                            wget -nv "$BASE$link";
                            break;;
# -P prefix
# --directory-prefix=prefix
#   Set directory prefix to prefix.  The directory prefix is the directory where all other files and subdirectories will be
#   saved to, i.e. the top of the retrieval tree.  The default is . (the current directory).
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
