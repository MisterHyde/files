# https://github.com/cnszde/arch_install/blob/main/functionen.sh
# Check which boot options we have

install_base_system () {
    BOOT_MODE=$(cat /sys/firmware/efi/fw_platform_size)
    if [[ $BOOT_MODE -eq 64 ]]; then
        echo UEFI detected
    elif [[ $BOOT_MODE -eq 32 ]]; then
        echo IA32 UEFI detected
    else
        echo No UEFI detected
        exit
    fi

    # Check the Blockdevice are sdX or nvme0
    if ! [ -d "/sys/block/nvme0n1" ]; then

        hd="sda"
        hd1="sda1"
        hd2="sda2"
        hd3="sda3"
    else
        hd="nvme0n1"
        hd1="nvme0n1p1"
        hd2="nvme0n1p2"
        hd3="nvme0n1p3"
    fi

    # Ensure that internet is connected
    if [ -z "$(ping -c 1 archlinux.org | sed -ne '/.*ttl=/{;s///;s/\..*//;p;}')" ]; then
        echo "No internet connection"
        exit
    fi

    # Sync hardware clock
    timedatectrl set-ntp true

    # Prepare disk
    lsblk
    read -p "On which device shall the system be installed? (/dev/sdX)" SDX
    read -p "Installing on /dev/$SDX? (type in 'OK') " VERIFY

    if [[ "$VERIFY" != "OK" ]];then
        exit
    fi

    DISK="/dev/$SDX"
    hd1=$DISK"1"
    hd2=$DISK"2"
    hd3=$DISK"3"

    echo "hd1: $hd1 hd2: $hd2"

    # Wipe disk
    VERIFY=""
    read -p "Wipe disk? (type in 'YES') " VERIFY

    if [[ "$VERIFY" == "YES" ]];then
        cryptsetup open --type plain --key-file /dev/urandom --sector-size 4096 $DISK to_be_wiped
        dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress bs=1M
        cryptsetup close to_be_wiped
    fi

    # Make UEFI partition and a main partition for lvm partitons
    sgdisk --clear $DISK
    sgdisk --new 1:0:+1024M -t 1:EF00 $DISK
    sgdisk --new 2::0 $DISK

    # Make the kernel use the new partition table
    partprobe

    # Encrypt disk
    cryptsetup -c aes-xts-plain64 -y -i 3000 -s 512 luksFormat  $hd2
    cryptsetup luksOpen $hd2 lvm

    # Create lvm mapping and file systems
    pvcreate /dev/mapper/lvm
    vgcreate main /dev/mapper/lvm
    lvcreate -L 8G -n swap main
    lvcreate -L 70G -n root main
    lvcreate -l 100%FREE -n home main
    #Swap
    mkswap /dev/mapper/main-swap
    swapon /dev/mapper/main-swap
    # Formatieren und mounten
    mkfs.vfat $hd1
    mkfs.ext4 /dev/mapper/main-root
    mkfs.ext4 /dev/mapper/main-home
    mount /dev/mapper/main-root /mnt
    mkdir /mnt/boot
    mkdir /mnt/home
    mount $hd1 /mnt/boot
    mount /dev/mapper/main-home /mnt/home

    read -p "Provide host name: " hostname
    read -p "Provide user name: " username

    pacstrap /mnt base base-devel linux linux-firmware amd-ucode intel-ucode lvm2 dhclient vim
    genfstab -U /mnt >/mnt/etc/fstab

    # Set locale and keymap and hostname and timezone
    echo $hostname >/mnt/etc/hostname
    echo "LANG=de_DE.UTF-8" >/mnt/etc/locale.conf
    echo "LANG=en_US.UTF-8" >>/mnt/etc/locale.conf
    #echo "KEYMAP=de-latin1" >/mnt/etc/vconsole.conf
    #echo "FONT=lat9w-16" >>/mnt/etc/vconsole.conf
    #echo "de_DE.UTF-8 UTF-8" >/mnt/etc/locale.gen
    #echo "de_DE ISO-8859-1" >>/mnt/etc/locale.gen
    #echo "de_DE@euro ISO-8859-15" >>/mnt/etc/locale.gen
    arch-chroot /mnt /bin/bash locale-gen
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

    # Configure mkinitcpio
    #HOOKS_CONTENT=$(grep -e "HOOKS=(.*)" /mnt/etc/mkinitcpio.conf | cut -d "(" -f2 | cut -d ")" -f1)
    #sed -i "s/HOOKS=(.*)/HOOKS=(base udev block autodetect modconf keyboard keymap encrypt lvm2 filesystems fsck shutdown)/g" 
    echo "#Add 'encrypt lvm2 ' to HOOKS=(..) before the entry 'filesystems' also ensure that 'autodetect' stands before 'microcode'" >> /mnt/etc/mkinitcpio.conf
    echo "#Add to modules if u like to use nvdia and Wayland MODULES=(... nvidia nvidia_modeset nvidia_uvm nvidia_drm ...)" >> /mnt/etc/mkinitcpio.conf
    vim "+normal G$" /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -p linux

    # Bootloader
    # grup bootloader
    arch-chroot /mnt pacman -S grub efibootmgr
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    cp /mnt/etc/default/grub /mnt/etc/default/grub.back
    uuid=$(blkid -s UUID -o value $hd2)
    echo "# GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 cryptdevice=UUID=$uuid:cryptlvm root=/dev/main/root\"" >> /mnt/etc/default/grub
    # Needed because without it the graphical output freezes at getty
    echo "# GRUB_CMDLINE_LINUX_DEFAULT ='nvidia_drm.fbdev=0'" >> /mnt/etc/default/grub
    echo "Please check the line GRUB_CMDLINE_LINUX_DEFAULT and correct it if necessary"
    vim /mnt/etc/default/grub
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

    # Password for root
    echo "Passwort for root: "
    arch-chroot /mnt passwd root

    arch-chroot /mnt useradd -m -s /usr/bin/bash "$username"
    arch-chroot /mnt usermod -a -G video,audio,games,power,wheel $username
    echo "Passwort for $username"
    arch-chroot /mnt passwd $username

}

install_additional_packages () {
    # Install i3
    arch-chroot /mnt pacman -Syu --noconfirm nvidia nvidia-utils xorg-server xorg-xinit \
            i3-wm dmenu rofi alacritty
    }

#arch-chroot /mnt pacman -Sy --noconfirm alsa-utils \
        #firefox chromium \
        #ttf-bitstream-vera ttf-dejavu alsa-utils pulseaudio pulseaudio-mc openssh \
        #bluez bluez-utils bluez-hid2hci noto-fonts \
        #pulseaudio-bluetooth opendesktop-fonts \
        #alacritty gnome-keyring grim otf-font-awesome \
        #p7zip unrar pavucontrol clipman mutt blueman \
        #dmenu blueman transmission-gtk base-devel

# Add to login shell
#if [ -z "$WAYLAND_DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ] ; then
#    exec sway
#fi

#arch-chroot /mnt pacman -Sy --noconfirm i3-wm rofi i3blocks wmfocus

#echo "bindsym $mod+x [urgent=latest] focus" >> "/mnt/home/$username/.config/i3/config

config_security_settings() {
    echo "# Prevent systemd from clearing the boot messages from tty1
    [Service]
    TTYVTDisallocate=no" > /mnt//etc/systemd/system/getty@tty1.service.d/noclear.conf

    # Enforce a 4 second delay after a failed login attempt
    echo "auth optional pam_faildelay.so delay=4000000" >> /mnt/etc/pam.d/system-login

    # Increase failed login attempt till login will be locked
    linenumber=$(grep -rIne "deny = " /mnt/etc/security/faillock.conf | cut -f 1 -d ":")
    vim +$linenumber /mnt/etc/security/faillock.conf -c 'normal zt'

    # Disable root ssh login by setting PermitRootLogin no
    linenumber=$(grep -rIne "PermitRootLogin" /mnt/etc/ssh/sshd_config.d/20-deny_root.conf | cut -f 1 -d ":")
    vim +$linenumber /mnt/etc/ssh/sshd_config.d/20-deny_root.conf -c 'normal zt'

    # Just allow user in the group wheel to login as root with su
    # uncomment 'auth required pam_wheel.so use_uid' in the both files below
    vim /mnt/etc/pam.d/su
    vim /mnt/etc/pam.d/su-l
}

##################################################################################################
# Change user files
##################################################################################################

config_user_settings() {
    # Enable wheel group user to use sudo
    arch-chroot /mnt visudo

    arch-chroot /mnt chown $username:$username /home/$username/systemMaintenance.fish

    # User configs from git
    arch-chroot /mnt runuser -l $username -c "git clone https://github.com/MisterHyde/Files /mnt/home/$username/.files"
}

config_ssh_settings_container() {
    arch-chroot /mnt pacman -S --noconfirm xorg-xauth 
    filename=/mnt/etc/ssh/sshd_config
    linenumber=$(grep -rIne "X11Forwarding" $filename | cut -f 1 -d ":")
    vim +$linenumber $filename -c 'normal zt'
    linenumber=$(grep -rIne "X11DisplayOffset" $filename | cut -f 1 -d ":")
    vim +$linenumber $filename -c 'normal zt'
    linenumber=$(grep -rIne "AllowTcpForwarding" $filename | cut -f 1 -d ":")
    vim +$linenumber $filename -c 'normal zt'
    linenumber=$(grep -rIne "X11UseLocalhost" $filename | cut -f 1 -d ":")
    vim +$linenumber $filename -c 'normal zt'
}

install_base_system
install_additional_packages
config_security_settings
config_user_settings
