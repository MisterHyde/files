#!/usr/bin/env fish
#
# Manual AUR update script.
# For each git repo one level below the current directory: pull, and if new
# commits arrived, show the diff and offer to run `makepkg -sri`.

set -l root (pwd)

for entry in */
    set -l dir (string trim -r -c / -- $entry)

    if not test -d $dir/.git
        continue
    end

    echo "==> $dir"
    cd $root/$dir

    set -l before (git rev-parse HEAD)

    if not git pull --ff-only
        echo "    pull failed, skipping"
        cd $root
        continue
    end

    set -l after (git rev-parse HEAD)

    if test "$before" = "$after"
        echo "    up to date"
        cd $root
        continue
    end

    git --no-pager diff $before $after

    echo ""
    read -l -P "    Build $dir? [y/N] " answer
    if string match -qri '^y(es)?$' -- $answer
        makepkg -sri
    end

    cd $root
end
