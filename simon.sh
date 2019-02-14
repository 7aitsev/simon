#!/bin/bash

###############################################################################
# Usage:
#
# 1. Place the script in a dedicated directory, e.g., "./simon/simon.sh".
# 2. cd to the folder.
# 3. Run the script and follow the prompts. If it's the first run, then
#    you'll be informed that a snapshot named "simon.old" has been created.
###############################################################################

###############################################################################
# Global vals and vars
###############################################################################
SNAPSHOT_OLD='simon.old'
SITE='http://simonstalenhag.se/'
SNAPSHOT_NEW=''
SED=''
COURIER=''

###############################################################################
# Check dependencies (use absolute paths for each of them)
###############################################################################
check_deps() {
    SED="$(command -v sed)"
    if [ 1 -eq $? ] ; then
        printf 'The script requires sed\n'
        exit 1
    fi
    for courier in "wget" "curl" ; do
        COURIER="$(command -v "$courier")"
        if [ 0 -eq $? ] ; then
            return
        fi
    done
    printf 'The script requires wget or curl\n'
    exit 1
}

###############################################################################
# Download the index.html page from the site
###############################################################################
download_page()
{
    local _site_filter
    _site_filter='s/.$//;/^$/d;s/^[[:space:]]*//;s/[[:space:]]*$//'
    #SNAPSHOT_NEW=$("$SED" -e "$_site_filter" <"simon.new")
    #return 0
    case "$COURIER" in
        *wget )
            SNAPSHOT_NEW=$("$COURIER" -q -O /dev/stdout "$SITE" \
                | sed -e "$_site_filter")
            ;;
        *curl )
            SNAPSHOT_NEW=$("$COURIER" -s "$SITE" \
                | sed -e "$_site_filter")
            ;;
        * )
            printf 'Unknown courier\n' 1>&2
            exit 1
    esac
}

###############################################################################
# Rewrite the old snapshot?
###############################################################################
ask_overwrite() {
    printf '\n'
    while true ; do
        read -rp 'Overwrite the old snapshot (y/n)? ' yn
        case "$yn" in
            [Yy]* )
                printf '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
                printf 'Snapshot overwritten\n'
                break;;
            [Nn]* )
                printf 'Snapshot untouched\n';
                break;;
            * )
                printf 'Please answer yes or no\n';;
        esac
    done
}

###############################################################################
# Fetch link(s) from diff and download pic(s)
###############################################################################
fetch_and_download() {
    local _links
    _links=$(printf '%s' "$1" \
        | "$SED" -n '/^>/p' | cut -d '"' -f 2 \
        | "$SED" -n '/\.[jJ][pP][eE]\?[gG]/p' | sort -u)
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
                            # TODO: write a function to download a file
                            "$COURIER" -nv "$SITE$link";
                            break;;
                        [Nn]* )
                            #printf 'Skipping...\n'
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

###############################################################################
# Is there something new?
###############################################################################
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

###############################################################################
# Entry point
###############################################################################

check_deps

download_page

# Is there simon.old file?
if [ -f "$SNAPSHOT_OLD" ]
    then
        printf 'Snapshot "%s" found\n' "$SNAPSHOT_OLD"
        find_diffs
    else
        printf 'Snapshot "%s" not found\n' "$SNAPSHOT_OLD"
        printf '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
        printf 'Snapshot of the site saved as "%s"\n' "$SNAPSHOT_OLD"
fi
