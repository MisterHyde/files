#!/usr/bin/env bash
# Arch/Artix installer -- UEFI + LUKS + LVM, corrected version of archInstal.sh
# original reference: https://github.com/cnszde/arch_install/blob/main/functionen.sh
#
# Two paths, one script:
#   INIT=systemd  Arch Linux    pacstrap  / arch-chroot  / systemctl
#   INIT=dinit    Artix Linux   basestrap / artix-chroot / dinit boot.d
# Run from the matching live ISO (Arch ISO for systemd, Artix ISO for dinit),
# as root.
#
#   ./archInstal-fixed.sh                     # Arch + systemd (default)
#   INIT=dinit ./archInstal-fixed.sh          # Artix + dinit
#   INITRAMFS=udev ./archInstal-fixed.sh      # busybox initramfs on Arch
#   ./archInstal-fixed.sh config_security_settings   # a single stage
#
# Stages: install_base_system  install_additional_packages
#         config_security_settings  config_user_settings  verify_install

set -Eeuo pipefail
trap 'echo "!! failed at line $LINENO: $BASH_COMMAND" >&2' ERR

# ------------------------------------------------------------------ knobs ---
INIT="${INIT:-systemd}"                  # systemd (Arch) or dinit (Artix)
TIMEZONE="${TIMEZONE:-Europe/Berlin}"
LOCALE="${LOCALE:-de_DE.UTF-8}"          # the LANG the system ends up with
EXTRA_LOCALES="${EXTRA_LOCALES:-en_US.UTF-8}"
KEYMAP="${KEYMAP:-de-latin1}"            # console + LUKS passphrase prompt
SWAP_SIZE="${SWAP_SIZE:-8G}"
ROOT_SIZE="${ROOT_SIZE:-70G}"
CRYPT_NAME="${CRYPT_NAME:-cryptlvm}"     # name the initramfs unlocks the LUKS container as
VG_NAME="${VG_NAME:-main}"
ENABLE_SSHD="${ENABLE_SSHD:-1}"          # 0 = do not enable sshd on the target
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/MisterHyde/Files}"

# ------------------------------------------------------- init abstraction ---
# Everything that differs between Arch/systemd and Artix/dinit is decided here,
# once, so the two paths cannot drift apart further down.
case "$INIT" in
    systemd)
        STRAP=(pacstrap -K)
        FSTABGEN=(genfstab -U)
        CHROOT=arch-chroot
        INIT_PKGS=(networkmanager openssh)
        INIT_PKGS_OPTIONAL=()
        SERVICES=(NetworkManager)
        INITRAMFS="${INITRAMFS:-systemd}"     # systemd or udev hooks
        ;;
    dinit)
        # Artix: base carries no init, you pick one. artools provides
        # basestrap/fstabgen/artix-chroot on the live ISO.
        STRAP=(basestrap)
        FSTABGEN=(fstabgen -U)
        CHROOT=artix-chroot
        INIT_PKGS=(dinit elogind-dinit networkmanager networkmanager-dinit openssh openssh-dinit)
        # Nice to have, but a rename upstream must not abort the install.
        INIT_PKGS_OPTIONAL=(dbus-dinit lvm2-dinit device-mapper-dinit cryptsetup-dinit)
        SERVICES=(dbus elogind NetworkManager)
        # Artix has no systemd, so the systemd initramfs hooks do not exist.
        INITRAMFS="${INITRAMFS:-udev}"
        # Anything other than systemd falls through to the HOOKS case below,
        # which reports invalid values properly.
        [[ "$INITRAMFS" != systemd ]] \
            || { echo "!! INITRAMFS=systemd is not available on Artix -- use udev" >&2; exit 1; }
        ;;
    *) echo "!! INIT must be 'systemd' or 'dinit', not '$INIT'" >&2; exit 1 ;;
esac
[[ "$ENABLE_SSHD" == "1" ]] && SERVICES+=(sshd)

# The hook family and the kernel parameter are one decision, not two: the
# busybox initramfs unlocks from cryptdevice=, the systemd one from
# rd.luks.name=. Mixing them boots into an emergency shell with no root.
case "$INITRAMFS" in
    systemd)
        HOOKS_LINE='HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt lvm2 filesystems fsck)'
        HOOKS_GUARD='^HOOKS=.* sd-encrypt .*lvm2.*filesystems'
        ;;
    udev)
        HOOKS_LINE='HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)'
        HOOKS_GUARD='^HOOKS=.* encrypt .*lvm2.*filesystems'
        ;;
    *) echo "!! INITRAMFS must be 'systemd' or 'udev', not '$INITRAMFS'" >&2; exit 1 ;;
esac

# crypt_param <uuid> -> the kernel parameter matching $INITRAMFS
crypt_param() {
    if [[ "$INITRAMFS" == systemd ]]; then printf 'rd.luks.name=%s=%s' "$1" "$CRYPT_NAME"
    else printf 'cryptdevice=UUID=%s:%s' "$1" "$CRYPT_NAME"; fi
}

hostname=""
username=""
DISK=""; hd1=""; hd2=""
nvidia=0

die() { echo "!! $*" >&2; exit 1; }
note() { echo "== $*"; }

# /dev/sda -> /dev/sda1 , /dev/nvme0n1 -> /dev/nvme0n1p1  (the original bug)
part() {
    local disk="$1" num="$2"
    if [[ "$disk" == *[0-9] ]]; then printf '%sp%s' "$disk" "$num"
    else printf '%s%s' "$disk" "$num"; fi
}

confirm() {                              # confirm <prompt> <expected word>
    local reply=''
    read -r -p "$1" reply || true
    [[ "$reply" == "$2" ]]
}

# Drop packages the repos do not have, so one rename cannot abort an install.
filter_available() {
    local p; local -a out=()
    for p in "$@"; do
        if pacman -Si "$p" >/dev/null 2>&1; then out+=("$p")
        else echo "!! optional package not in the repos, skipping: $p" >&2; fi
    done
    printf '%s\n' ${out[@]+"${out[@]}"}
}

# enable_service <name> -- systemctl on Arch, boot.d symlink on Artix
enable_service() {
    local svc="$1"
    case "$INIT" in
        systemd)
            "$CHROOT" /mnt systemctl enable "$svc"
            ;;
        dinit)
            if [[ ! -e "/mnt/etc/dinit.d/$svc" ]]; then
                echo "!! no dinit service file for '$svc' -- not enabled" >&2
                return 0
            fi
            mkdir -p /mnt/etc/dinit.d/boot.d
            # --offline is the documented way, but it has shipped broken on
            # live ISOs; fall back to the symlink it would have created.
            "$CHROOT" /mnt dinitctl --offline enable "$svc" >/dev/null 2>&1 \
                || ln -sf "../$svc" "/mnt/etc/dinit.d/boot.d/$svc"
            [[ -e "/mnt/etc/dinit.d/boot.d/$svc" ]] || die "could not enable dinit service '$svc'"
            note "enabled $svc"
            ;;
    esac
}

# Stages other than the first need these; ask if run standalone.
require_target_vars() {
    [[ -n "$username" ]] || read -r -p "User name: " username
    [[ -n "$hostname" ]] || read -r -p "Host name: " hostname
    [[ -d /mnt/etc ]] || die "nothing mounted at /mnt -- run install_base_system first"
}

##################################################################################################
# Base system
##################################################################################################

install_base_system () {
    [[ $EUID -eq 0 ]] || die "run as root"
    command -v "${STRAP[0]}" >/dev/null \
        || die "${STRAP[0]} not found -- INIT=$INIT needs the $( [[ $INIT == dinit ]] && echo Artix || echo Arch ) live ISO"

    # Boot mode
    [[ -r /sys/firmware/efi/fw_platform_size ]] || die "No UEFI detected"
    case "$(cat /sys/firmware/efi/fw_platform_size)" in
        64) note "UEFI detected" ;;
        32) note "IA32 UEFI detected" ;;
         *) die "No UEFI detected" ;;
    esac
    note "init: $INIT   initramfs: $INITRAMFS"

    # The passphrase is typed on this layout now and at every boot, so load it
    # here too -- otherwise you set it in us and enter it in de-latin1.
    loadkeys "$KEYMAP"

    ping -c 1 -W 5 artixlinux.org >/dev/null 2>&1 \
        || ping -c 1 -W 5 archlinux.org >/dev/null 2>&1 \
        || die "No internet connection"
    command -v timedatectl >/dev/null && timedatectl set-ntp true || true

    # -------------------------------------------------------------- disk ---
    lsblk -dpno NAME,SIZE,MODEL
    read -r -p "On which device shall the system be installed? (e.g. sda or /dev/nvme0n1) " answer
    DISK="/dev/${answer#/dev/}"
    [[ -b "$DISK" ]] || die "$DISK is not a block device"

    confirm "Installing on $DISK -- ALL DATA IS LOST. (type 'OK') " "OK" || die "aborted"

    hd1="$(part "$DISK" 1)"
    hd2="$(part "$DISK" 2)"
    note "ESP: $hd1   LUKS: $hd2"

    # Disk big enough for the requested layout?
    local disk_bytes need_bytes
    disk_bytes=$(blockdev --getsize64 "$DISK")
    need_bytes=$(( $(numfmt --from=iec "$SWAP_SIZE") + $(numfmt --from=iec "$ROOT_SIZE") + 2*1024**3 ))
    (( disk_bytes > need_bytes )) || die "disk is too small for swap $SWAP_SIZE + root $ROOT_SIZE (+ESP+home)"

    if confirm "Wipe disk with random data first? This takes hours. (type 'YES') " "YES"; then
        cryptsetup open --type plain --key-file /dev/urandom --sector-size 4096 "$DISK" to_be_wiped
        # dd always exits non-zero on ENOSPC, which is the expected end here.
        dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress bs=1M || true
        cryptsetup close to_be_wiped
    fi

    # ESP + one big LUKS partition
    sgdisk --zap-all "$DISK"
    sgdisk --new 1:0:+1024M -t 1:EF00 -c 1:"EFI system partition" "$DISK"
    sgdisk --new 2:0:0     -t 2:8309 -c 2:"Linux LUKS"           "$DISK"
    partprobe "$DISK"
    udevadm settle
    [[ -b "$hd1" && -b "$hd2" ]] || die "expected partitions $hd1 / $hd2 do not exist"

    # ------------------------------------------------------- luks + lvm ---
    cryptsetup luksFormat --type luks2 -c aes-xts-plain64 -y -i 3000 -s 512 "$hd2"
    cryptsetup luksOpen "$hd2" "$CRYPT_NAME"

    pvcreate "/dev/mapper/$CRYPT_NAME"
    vgcreate "$VG_NAME" "/dev/mapper/$CRYPT_NAME"
    lvcreate -L "$SWAP_SIZE" -n swap "$VG_NAME"
    lvcreate -L "$ROOT_SIZE" -n root "$VG_NAME"
    lvcreate -l 100%FREE     -n home "$VG_NAME"

    mkswap "/dev/mapper/${VG_NAME}-swap"
    swapon "/dev/mapper/${VG_NAME}-swap"
    mkfs.fat -F32 "$hd1"                 # firmware wants FAT32, do not let mkfs guess
    mkfs.ext4 -F "/dev/mapper/${VG_NAME}-root"
    mkfs.ext4 -F "/dev/mapper/${VG_NAME}-home"

    mount "/dev/mapper/${VG_NAME}-root" /mnt
    mkdir -p /mnt/boot /mnt/home
    mount "$hd1" /mnt/boot
    mount "/dev/mapper/${VG_NAME}-home" /mnt/home

    read -r -p "Provide host name: " hostname
    read -r -p "Provide user name: " username

    # ------------------------------------------------------------ strap ---
    # cryptsetup is required in the target for the initramfs encrypt hook.
    # A network daemon is required or the machine boots without a network.
    local -a pkgs=(base base-devel linux linux-firmware amd-ucode intel-ucode
                   lvm2 cryptsetup git vim sudo)
    pkgs+=("${INIT_PKGS[@]}")
    if [[ ${#INIT_PKGS_OPTIONAL[@]} -gt 0 ]]; then
        mapfile -t extra < <(filter_available "${INIT_PKGS_OPTIONAL[@]}")
        pkgs+=(${extra[@]+"${extra[@]}"})
    fi
    note "installing: ${pkgs[*]}"
    "${STRAP[@]}" /mnt "${pkgs[@]}"
    "${FSTABGEN[@]}" /mnt >>/mnt/etc/fstab   # after swapon, so swap lands in fstab
    grep -q UUID /mnt/etc/fstab || die "fstab was not generated"

    # ------------------------------------------- locale / time / network ---
    echo "$hostname" >/mnt/etc/hostname
    cat >/mnt/etc/hosts <<HOSTS_EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$hostname.localdomain	$hostname
HOSTS_EOF

    echo "LANG=$LOCALE" >/mnt/etc/locale.conf
    # Read by the initramfs keymap hook, which is what the LUKS prompt uses.
    printf 'KEYMAP=%s\nFONT=lat9w-16\n' "$KEYMAP" >/mnt/etc/vconsole.conf

    # Uncomment the wanted locales *before* generating them.
    local loc
    for loc in "$LOCALE" $EXTRA_LOCALES; do
        sed -i "s/^#\s*\(${loc//./\\.} UTF-8\)/\1/" /mnt/etc/locale.gen
        grep -q "^${loc} UTF-8" /mnt/etc/locale.gen || echo "$loc UTF-8" >>/mnt/etc/locale.gen
    done
    "$CHROOT" /mnt locale-gen                # not "/bin/bash locale-gen"

    "$CHROOT" /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    "$CHROOT" /mnt hwclock --systohc

    local svc
    for svc in "${SERVICES[@]}"; do enable_service "$svc"; done

    # -------------------------------------------------------- mkinitcpio ---
    cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.back
    # encrypt + lvm2 before filesystems, autodetect before microcode.
    sed -i "s|^HOOKS=.*|$HOOKS_LINE|" /mnt/etc/mkinitcpio.conf
    grep -qE "$HOOKS_GUARD" /mnt/etc/mkinitcpio.conf || die "HOOKS line was not rewritten"
    note "HOOKS is now: $(grep '^HOOKS=' /mnt/etc/mkinitcpio.conf)"
    if confirm "Review mkinitcpio.conf in vim? (type 'y') " "y"; then
        vim /mnt/etc/mkinitcpio.conf
    fi
    "$CHROOT" /mnt mkinitcpio -P

    # ------------------------------------------------------------- grub ---
    "$CHROOT" /mnt pacman -S --noconfirm grub efibootmgr dosfstools
    "$CHROOT" /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    cp /mnt/etc/default/grub /mnt/etc/default/grub.back

    # Arch and Artix ship GRUB_CMDLINE_LINUX empty; if something put crypt
    # parameters there, two competing definitions would fight over the boot.
    if grep -qE '^GRUB_CMDLINE_LINUX=.*(cryptdevice=|rd\.luks\.name=)' /mnt/etc/default/grub; then
        die "GRUB_CMDLINE_LINUX already contains crypt parameters -- resolve by hand"
    fi

    local uuid cmdline
    uuid=$(blkid -s UUID -o value "$hd2")   # UUID of the LUKS container
    [[ -n "$uuid" ]] || die "could not read LUKS UUID of $hd2"
    cmdline="loglevel=3 $(crypt_param "$uuid") root=/dev/$VG_NAME/root"
    sed -i "s|^#\?GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$cmdline\"|" \
        /mnt/etc/default/grub
    grep -qF "$(crypt_param "$uuid")" /mnt/etc/default/grub || die "GRUB cmdline was not rewritten"
    note "GRUB cmdline: $(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /mnt/etc/default/grub)"
    if confirm "Review /etc/default/grub in vim? (type 'y') " "y"; then
        vim /mnt/etc/default/grub
    fi
    "$CHROOT" /mnt grub-mkconfig -o /boot/grub/grub.cfg

    # ------------------------------------------------------------ users ---
    note "Password for root:"
    "$CHROOT" /mnt passwd root
    "$CHROOT" /mnt useradd -m -s /usr/bin/bash "$username"
    "$CHROOT" /mnt usermod -a -G video,audio,games,power,wheel "$username"
    note "Password for $username:"
    "$CHROOT" /mnt passwd "$username"
}

##################################################################################################
# Desktop packages
##################################################################################################

install_additional_packages () {
    require_target_vars

    local pkgs=(xorg-server xorg-xinit i3-wm i3blocks rofi alacritty dunst)

    # Only pull the nvidia stack on machines that actually have one.
    if lspci -k 2>/dev/null | grep -qi 'VGA.*nvidia'; then
        nvidia=1
        pkgs+=(nvidia nvidia-utils)
        note "nvidia GPU detected"
    else
        note "no nvidia GPU detected -- skipping nvidia packages"
    fi

    "$CHROOT" /mnt pacman -Syu --noconfirm "${pkgs[@]}"

    if [[ $nvidia -eq 1 ]]; then
        # Wayland needs the modules in the initramfs, and fbdev=0 keeps the
        # graphical output from freezing at getty.
        sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' \
            /mnt/etc/mkinitcpio.conf
        sed -i 's|^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"|\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=0"|' \
            /mnt/etc/default/grub
        "$CHROOT" /mnt mkinitcpio -P
        "$CHROOT" /mnt grub-mkconfig -o /boot/grub/grub.cfg
    fi
}

##################################################################################################
# Hardening
##################################################################################################

config_security_settings() {
    require_target_vars

    if [[ "$INIT" == systemd ]]; then
        # Prevent systemd from clearing the boot messages from tty1.
        mkdir -p /mnt/etc/systemd/system/getty@tty1.service.d
        cat >/mnt/etc/systemd/system/getty@tty1.service.d/noclear.conf <<'NOCLEAR_EOF'
[Service]
TTYVTDisallocate=no
NOCLEAR_EOF
    else
        note "skipping the getty noclear override -- systemd only"
    fi

    # Enforce a 4 second delay after a failed login attempt (once).
    grep -q pam_faildelay /mnt/etc/pam.d/system-login \
        || echo "auth optional pam_faildelay.so delay=4000000" >>/mnt/etc/pam.d/system-login

    # Failed attempts before the account locks.
    sed -i 's/^#\?\s*deny\s*=.*/deny = 10/' /mnt/etc/security/faillock.conf
    note "faillock: $(grep -m1 '^deny' /mnt/etc/security/faillock.conf)"

    # Disable root ssh login -- the drop-in does not exist by default, write it.
    mkdir -p /mnt/etc/ssh/sshd_config.d
    echo "PermitRootLogin no" >/mnt/etc/ssh/sshd_config.d/20-deny_root.conf

    # Only members of wheel may su to root.
    local f
    for f in /mnt/etc/pam.d/su /mnt/etc/pam.d/su-l; do
        [[ -f "$f" ]] || continue
        sed -i 's/^#\s*\(auth\s*required\s*pam_wheel\.so use_uid\)/\1/' "$f"
        grep -q '^auth.*pam_wheel\.so use_uid' "$f" \
            || echo "auth required pam_wheel.so use_uid" >>"$f"
    done
}

config_user_settings() {
    require_target_vars

    # Let wheel use sudo, via a drop-in that is syntax-checked before it counts.
    echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/10-wheel
    chmod 0440 /mnt/etc/sudoers.d/10-wheel
    "$CHROOT" /mnt visudo -cf /etc/sudoers.d/10-wheel \
        || { rm -f /mnt/etc/sudoers.d/10-wheel; die "sudoers drop-in was invalid"; }

    # User configs from git.
    "$CHROOT" /mnt runuser -l "$username" -c \
        "git clone $DOTFILES_REPO /home/$username/.files"
    note "dotfiles cloned -- run ~/.files/scripts/init.sh after the first boot"
}

# X11 forwarding for container/headless use -- not part of the default run.
config_ssh_settings_container() {
    require_target_vars
    "$CHROOT" /mnt pacman -S --noconfirm xorg-xauth
    mkdir -p /mnt/etc/ssh/sshd_config.d
    cat >/mnt/etc/ssh/sshd_config.d/30-x11forwarding.conf <<'X11_EOF'
X11Forwarding yes
X11DisplayOffset 10
X11UseLocalhost yes
AllowTcpForwarding yes
X11_EOF
    "$CHROOT" /mnt sshd -t || die "sshd config is invalid"
}

##################################################################################################
# Final check -- catches the silent failures the old script scrolled past
##################################################################################################

verify_install() {
    local ok=1
    check() { if eval "$2" >/dev/null 2>&1; then echo "  ok    $1"; else echo "  FAIL  $1"; ok=0; fi; }

    note "verifying the installed system ($INIT / $INITRAMFS initramfs)"
    check "fstab is populated"        "grep -q UUID /mnt/etc/fstab"
    check "swap is in fstab"          "grep -q swap /mnt/etc/fstab"
    check "hooks in the right order"  "grep -qE '$HOOKS_GUARD' /mnt/etc/mkinitcpio.conf"
    check "initramfs built"           "ls /mnt/boot/initramfs-linux.img"

    if [[ "$INITRAMFS" == systemd ]]; then
        check "sd-encrypt hook"       "grep -q '^HOOKS=.* sd-encrypt ' /mnt/etc/mkinitcpio.conf"
        check "cmdline rd.luks.name"  "grep -qE '^GRUB_CMDLINE_LINUX(_DEFAULT)?=.*rd\.luks\.name=' /mnt/etc/default/grub"
        check "no stale cryptdevice=" "! grep -qE '^GRUB_CMDLINE_LINUX(_DEFAULT)?=.*cryptdevice=' /mnt/etc/default/grub"
    else
        check "encrypt hook"          "grep -q '^HOOKS=.* encrypt ' /mnt/etc/mkinitcpio.conf"
        check "cmdline cryptdevice="  "grep -qE '^GRUB_CMDLINE_LINUX(_DEFAULT)?=.*cryptdevice=UUID=' /mnt/etc/default/grub"
        check "no stale rd.luks.name" "! grep -qE '^GRUB_CMDLINE_LINUX(_DEFAULT)?=.*rd\.luks\.name=' /mnt/etc/default/grub"
    fi

    check "grub.cfg written"          "ls /mnt/boot/grub/grub.cfg"
    check "EFI binary installed"      "ls /mnt/boot/EFI/GRUB/grubx64.efi"
    check "locale generated"          "$CHROOT /mnt locale -a | grep -qi '${LOCALE%%.*}'"
    check "locale.conf single LANG"   "[ \$(grep -c '^LANG=' /mnt/etc/locale.conf) -eq 1 ]"
    check "keymap set"                "grep -q KEYMAP /mnt/etc/vconsole.conf"

    # Services, in whichever way this init expresses "enabled".
    local svc
    if [[ "$INIT" == systemd ]]; then
        for svc in "${SERVICES[@]}"; do
            check "service enabled: $svc" "$CHROOT /mnt systemctl is-enabled $svc"
        done
    else
        check "dinit installed"       "ls /mnt/etc/dinit.d"
        for svc in "${SERVICES[@]}"; do
            check "service enabled: $svc" "[ -e /mnt/etc/dinit.d/boot.d/$svc ]"
        done
        # A dangling boot.d symlink fails at boot, so catch it now.
        check "no dangling boot.d links" \
            "! find /mnt/etc/dinit.d/boot.d -xtype l -print -quit | grep -q ."
    fi

    check "user exists"               "$CHROOT /mnt id '$username'"
    check "wheel may sudo"            "ls /mnt/etc/sudoers.d/10-wheel"

    if [[ $ok -eq 1 ]]; then
        note "all checks passed -- umount -R /mnt && reboot"
    else
        die "some checks failed -- fix them before rebooting"
    fi
}

##################################################################################################

main() {
    local stages=("$@")
    if [[ ${#stages[@]} -eq 0 ]]; then
        stages=(install_base_system install_additional_packages
                config_security_settings config_user_settings verify_install)
    fi
    for stage in "${stages[@]}"; do
        declare -F "$stage" >/dev/null || die "no such stage: $stage"
        note "stage: $stage"
        "$stage"
    done
}

main "$@"
