#!/bin/bash

# Usage:
#
# 1. place the script in a directory, i.e. "./simon/simon.sh"
# 2. cd to the folder
# 3. run the script (if it is the first run, then you'll be prompted just to create a snapshot of the site
#     - file called "simon.old") and follow the prompts.

SNAPSHOT_OLD="simon.old"
BASE="http://simonstalenhag.se/"
SNAPSHOT_NEW=$(curl -ks $BASE | sed -e 's/.$//;/^$/d;s/^[[:space:]]*//;s/[[:space:]]*$//')

# overwrite the old snapshot?
askOverwrite() {
    while true ; do
        read -p "Overwrite the old snapshot (y/n)? " yn
        case $yn in
            [Yy]* ) echo -n "$SNAPSHOT_NEW" >$SNAPSHOT_OLD; break;;
            [Nn]* ) break;;
            *) echo "Please answer yes or no ";;
        esac
    done
}

# fetch link(s) from diff and download pic(s)
fetchNDownload() {
    _links=$(echo "$1" | grep -E "^>" | cut -d '"' -f 2 | grep ".jpg" | sort -u)
    if [[ -n $_links ]]
        then
            # show a list of fetched link(s)
            echo -e "\nFetched links:\n$_links\n"
            for link in $_links; do
                _fname=$(echo $link | cut -d '/' -f 2)
                # ask if user wishes to save file by the fetched link
                while true; do
                    read -p "Save \"$_fname\" (y/n)? " yn
                    case $yn in
                        [Yy]* ) wget -nv $BASE$link; break;;
# -P prefix
# --directory-prefix=prefix
#   Set directory prefix to prefix.  The directory prefix is the directory where all other files and subdirectories will be
#   saved to, i.e. the top of the retrieval tree.  The default is . (the current directory).
                        [Nn]* ) break;;
                        * ) echo "Please answer yes or no";;
                    esac
                done
            done
        else
            echo "Snapshots are different, but no links fetched..."
            echo "$1"
    fi
    askOverwrite
}

# is there something new?
findDiffs() {
    _diffs=$(diff $SNAPSHOT_OLD <(echo -n "$SNAPSHOT_NEW"))
    if [[ -n $_diffs ]]
        then
            fetchNDownload "$_diffs"
        else
            echo "Snapshots are the same"
    fi
}

# is there simon.old file?
if [[ -f $SNAPSHOT_OLD ]]
    then
        echo "Snapshot \"$SNAPSHOT_OLD\" found"
        findDiffs
    else
        echo "Snapshot \"$SNAPSHOT_OLD\" not found"
        echo -n "$SNAPSHOT_NEW" > $SNAPSHOT_OLD
        echo "Snapshot of the site saved to \"$SNAPSHOT_OLD\""
fi