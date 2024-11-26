#!/usr/bin/fish

journalctl -xb -p err..alert
systemctl --failed
echo 'Handle new config files that could not be automerged'
sudo pacdiff
sudo find /etc -name '*.pacnew' -o -name '*.pacsave'
echo 'Get all warnings from pacman -Qkk'
pacman -Qkk | grep warning
echo 'Show all unneeded packages'
pacman -Qqd | pacman -Rsu --print -
echo 'Show files not owned by any package
sudo lostfiles
echo 'All files with setuid or setgid bit. These shall be monitored
find /usr/bin -perm "/u=s,g=s"
