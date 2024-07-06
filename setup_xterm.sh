#!/bin/bash

echo -n "Checking if xterm is installed... "
if which xterm >/dev/null 2>&1; then
	echo "OK"
else
	echo "not installed. Exiting... "
	exit 1
fi

echo "Setting up .Xresources..."
user_conf=$HOME"/.Xresources"
current_dir=$(pwd)

if [ -e "$user_conf" ]; then
	echo ".Xresources already exists in home directory."
	read -p "Do you want to replace it? (y/n) " choice
	case "$choice" in
		y|Y )
			echo "Replacing existing .Xresources"
			rm -f "$user_conf"
			ln -s "$current_dir/.Xresources" "$user_conf"
			;;
		* )
			echo "Keeping existing .Xresources"
	esac
else
	echo "Creating symlink for .Xresources..."
	ln -s "$current_dir/.Xresources" "$user_conf"
 	echo "Symlink created from $current_dir/.Xresources to $user_conf"
fi

