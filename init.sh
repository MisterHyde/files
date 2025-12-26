#!/usr/bin/bash

base_dir=$(pwd)

read -p "This will replace existing configs in .config/. Are you shure?" -n 1 -r
echo 
if [[ $REPLY =~ ^[Yy]$ ]] then
    # To lazy to create backups of already existing configs
    cp -as "$(pwd)/.config/" ~/
fi

read -p "Install packages for i3 installation?" -n 1 -r
echo 
if [[ $REPLY =~ ^[Yy]$ ]] then
    sudo pacman -Syu - < i3packages
fi

cd $HOME
echo "Create links to tmux and vim config\n"
ln -s "$base_dir/.tmux.conf" ~/
ln -s "$base_dir/.tmux.conf.local" ~/
ln -s "$base_dir/.vimrc" ~/
mkdir -p ~/.vim/tmp

echo "Create local bin folder"
mkdir -p $HOME/.local/bin/
echo "PATH=$HOME/.local/bin/:$PATH" >> ~/.bashrc
cp $base_dir/systemMaintenance.fish $HOME/.local/bin/systemMaintenance


# Start fish if bash is started but not if started from fish
echo 'if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z ${BASH_EXECUTION_STRING} && ${SHLVL} == 1 ]]
then
shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=''
exec fish $LOGIN_OPTION
fi' >> ~/.bashrc


echo "Enable numlock after logged in"
echo "setleds -D +num" >> ~/.bash_profile

echo "Download themes for rofi"
mkdir -p ~/.local/share/rofi/themes
curl https://raw.githubusercontent.com/Rinfella/rofi-themes/refs/heads/master/arc_dark_transparent_colors.rasi -o ~/.local/share/rofi/themes/arc_dark_transparent_colors.rasi

echo "Download plugin manager for vim"
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

mkdir ~/.vim/tmp
