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
DOWNLOADER=''

###############################################################################
# Check dependencies (use absolute paths for each of them)
###############################################################################
check_deps() {
    SED="$(command -v sed)"
    if [ 0 -ne $? ] ; then
        printf 'The script requires sed\n'
        exit 1
    fi
    local dlder
    for dlder in "wget" "curl" ; do
        DOWNLOADER="$(command -v "$dlder")"
        if [ 0 -eq $? ] ; then
            return 0
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
    case "$DOWNLOADER" in
        *wget )
            SNAPSHOT_NEW=$("$DOWNLOADER" -nv --show-progress -O - -- "$SITE" \
                | sed -e "$_site_filter")
            ;;
        *curl )
            SNAPSHOT_NEW=$("$DOWNLOADER" -f --progress -- "$SITE" \
                | sed -e "$_site_filter")
            ;;
        * )
            printf -- 'Unknown downloader: "%s"\n' "$DOWNLOADER" 1>&2
            exit 1
    esac
}

###############################################################################
# Save a file
#
# $1 - an URL of the file
# $2 - a path to store the file
###############################################################################
file_downloader()
{
    if [ 2 -ne $# ] ; then
        printf '@file_downloader: missing arguments\n' 1>&2
        return 1
    fi
    local rc
    case "$DOWNLOADER" in
        *wget )
            "$DOWNLOADER" -O "$2" -nv --show-progress -- "$1"
            rc=$?
            ;;
        *curl )
            "$DOWNLOADER" -o "$2" -f --progress-bar -- "$1"
            rc=$?
            ;;
        * )
            printf -- 'Unknown downloader: "%s"\n' "$DOWNLOADER" 1>&2
            exit 1
    esac
    # clean up in case of downloading failure
    if [ 0 -ne $rc ] ; then
        rm "$2"
    fi
}

###############################################################################
# Ask if a user wishes to overwrite the old snapshot with a new one
###############################################################################
ask_overwrite() {
    printf '\n'
    while true ; do
        read -rp 'Overwrite the old snapshot (y/n)? ' yn
        case "$yn" in
            [Yy]* )
                printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
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
#
# $1 - the diff between an old and a new snapshot
###############################################################################
fetch_and_download() {
    local links
    links=$(printf -- '%s' "$1" \
        | "$SED" -n '/^>/p' | cut -d '"' -f 2 \
        | "$SED" -n '/\.[jJ][pP][eE]\?[gG]/p' | sort -u)
    printf '\n'
    if [ -n "$links" ] ; then
        local fname
        local link
        # show a list of fetched link(s) and loop through them
        printf -- 'Fetched links:\n%s\n\n' "$links"
        for link in $links; do
            fname=$(printf -- '%s' "$link" | cut -d '/' -f 2)
            # ask if a user wishes to save the file from the fetched link
            while true; do
                read -rp "Save \"$fname\" (y/n)? " yn
                case "$yn" in
                    [Yy]* )
                        file_downloader "${SITE}${link}" "./$fname"
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
        printf -- '%s\n' "$1"
        printf -- '-----END DIFF BLOCK-----\n'
    fi
    ask_overwrite
}

###############################################################################
# Is there something new?
###############################################################################
find_diffs() {
    local _diffs
    _diffs=$(printf -- '%s' "$SNAPSHOT_NEW" | diff "$SNAPSHOT_OLD" -)
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
        printf -- 'Snapshot "%s" found\n' "$SNAPSHOT_OLD"
        find_diffs
    else
        printf -- 'Snapshot "%s" not found\n' "$SNAPSHOT_OLD"
        printf -- '%s' "$SNAPSHOT_NEW" >"$SNAPSHOT_OLD"
        printf -- 'Snapshot of the site saved as "%s"\n' "$SNAPSHOT_OLD"
fi
