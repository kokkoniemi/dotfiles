#!/bin/bash

echo -n "Checking if tmux is installed... "
if which tmux >/dev/null 2>&1; then
	echo "OK"
else
	echo "not installed. Exiting... "
	exit 1
fi

echo "Setting up .tmux.conf..."
user_conf=$HOME"/.tmux.conf"
current_dir=$(pwd)

if [ -e "$user_conf" ]; then
	echo ".tmux.conf already exists in home directory."
	read -p "Do you want to replace it? (y/n) " choice
	case "$choice" in
		y|Y )
			echo "Replacing existing .tmux.conf"
			rm -f "$user_conf"
			ln -s "$current_dir/.tmux.conf" "$user_conf"
			;;
		* )
			echo "Keeping existing .tmux.conf"
	esac
else
	echo "Creating symlink for .tmux.conf..."
	ln -s "$current_dir/.tmux.conf" "$user_conf"
 	echo "Symlink created from $current_dir/.tmux.conf to $user_conf"
fi

