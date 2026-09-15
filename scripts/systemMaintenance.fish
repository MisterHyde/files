#!/usr/bin/fish
#
# Arch system maintenance — read-only by default.
#
# Merged from systemMaintenance.fish (dotfiles) and ~/.local/bin/systemMaintenance.
#
# Usage:
#   systemMaintenance                  inspect only, change nothing
#   systemMaintenance --clean-cache    actually prune the package cache (keep 1)
#   systemMaintenance --accept-setuid  adopt the current setuid/setgid set as baseline
#
# Everything except --clean-cache and --accept-setuid is read-only.

argparse h/help clean-cache accept-setuid -- $argv
or exit 1

if set -q _flag_help
    sed -n '3,12p' (status filename) | string replace -r '^# ?' ''
    exit 0
end

set -g state_dir ~/.local/share/systemMaintenance
set -g setuid_baseline $state_dir/setuid.baseline
set -g setuid_current (mktemp)

function section --argument-names title
    set_color --bold cyan
    echo
    echo "── $title"
    set_color normal
    echo
end

function need --argument-names cmd
    if not command -q $cmd
        set_color yellow
        echo "  (skipped: '$cmd' is not installed)"
        set_color normal
        return 1
    end
    return 0
end

mkdir -p $state_dir

# Prime sudo once instead of prompting at five scattered points mid-run.
section "Elevating (sudo is needed for several checks)"
sudo -v; or exit 1


section "Errors and alerts from this boot"
journalctl -xb -p alert..err
systemctl --failed


section "Config files that could not be automerged"
if need pacdiff
    sudo pacdiff
end
# pacdiff should have handled these; anything still listed was skipped or left behind.
sudo find /etc \( -name '*.pacnew' -o -name '*.pacsave' \) -print


section "Package file integrity (pacman -Qkk warnings)"
# pacman writes these warnings to stderr, so stdout alone greps to nothing.
pacman -Qkk 2>&1 >/dev/null | grep warning
or echo "  none"


section "Unneeded packages (orphaned dependencies)"
# --print makes this a preview; nothing is removed here.
pacman -Qqd | pacman -Rsu --print - 2>/dev/null
or echo "  none"


section "Files not owned by any package"
if need lostfiles
    sudo lostfiles
end
if need pacreport
    echo
    echo "  -- pacreport --unowned-files --"
    sudo pacreport --unowned-files
end


section "setuid / setgid binaries"
# /usr/sbin and /bin are symlinks into /usr/bin, but /usr/lib holds real ones too.
# Sorted, because raw find order shifts as files are added and creates false diffs.
find /usr/bin /usr/lib -perm '/u=s,g=s' -type f 2>/dev/null | sort >$setuid_current

# Seed from the pre-merge baseline the first time, so existing drift is not lost.
if not test -e $setuid_baseline
    if test -e ~/.local/share/lastSetUidGuid.txt
        sort ~/.local/share/lastSetUidGuid.txt >$setuid_baseline
        echo "  (seeded baseline from ~/.local/share/lastSetUidGuid.txt)"
    else
        cp $setuid_current $setuid_baseline
        echo "  (no baseline yet — current set recorded as the baseline)"
    end
end

echo "  baseline: "(count (cat $setuid_baseline))" entries, last updated "(date -r $setuid_baseline '+%Y-%m-%d')
echo "  current:  "(count (cat $setuid_current))" entries"
echo

# Old first, new second: '>' means newly setuid, '<' means it went away.
if diff --label baseline --label current -u $setuid_baseline $setuid_current | tail -n +3 | grep -E '^[+-]'
    set_color --bold yellow
    echo
    echo "  Changed since the baseline. Review the lines above:"
    echo "    '+' = newly setuid/setgid   '-' = no longer setuid/setgid"
    echo "  Once reviewed, adopt them with:  systemMaintenance --accept-setuid"
    set_color normal

    if set -q _flag_accept_setuid
        cp $setuid_current $setuid_baseline
        set_color green
        echo "  Baseline updated."
        set_color normal
    end
else
    echo "  No change since the baseline."
end
rm -f $setuid_current


section "Service sandboxing / exposure"
sudo systemd-analyze security


section "Package cache"
if need paccache
    if set -q _flag_clean_cache
        sudo paccache -rk1
    else
        # Dry run. Pass --clean-cache to actually delete.
        paccache -dk1
        echo
        echo "  (dry run — re-run with --clean-cache to actually prune)"
    end
end

echo
