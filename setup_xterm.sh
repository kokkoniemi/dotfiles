#!/bin/bash

echo -n "Checking if xterm is installed... "
if which xterm >/dev/null 2>&1; then
	echo "OK"
else
	echo "not installed. Exiting... "
	exit 1
fi

echo "Setting up .Xresources..."
echo

user_conf=$HOME"/.Xresources"
current_dir=$(pwd)

compile_file() {
	local profile="$1"
	new_file="$current_dir/.Xresources"

	echo "! ═════════════ IMPORTANT ══════════════" > "$new_file"
	echo "! This is auto-generated config. Make changes in $current_dir/.xterm" >> "$new_file"
	echo "! and use $current_dir/setup_xterm.sh to recompile" >> "$new_file"
	echo "!" >> "$new_file"
	echo "! profile=$profile" >> "$new_file"
	echo "! ══════════════════════════════════════" >> "$new_file"
	echo >> "$new_file"

	cat "$current_dir/.xterm/common.Xresources" | awk '!/^!/ && NF' >> "$new_file"
	cat "$current_dir/.xterm/profile-$profile.Xresources"| awk '!/^!/ && NF' >> "$new_file"
}

available_profiles=(
	"default"
	"monokai"
)

current_profile="<not detected>"
if [ -e "$user_conf" ]; then
	current_profile=$(awk -F'=| ' '/^! profile=/ {print $3}' "$user_conf")
fi

echo "Current profile: $current_profile"
echo "----------------"
echo "Available profiles:"
for i in "${!available_profiles[@]}"; do
	echo "$((i+1))) ${available_profiles[i]}"
done

read -p "Enter the option number or press ENTER to exit: " selected

max_valid_option=${#available_profiles[@]}
if [[ "$selected" =~ ^[0-9]+$ ]] && \
   [ "$selected" -ge 1 ] && \
   [ "$selected" -le "$max_valid_option" ]; then
	selected_profile="${available_profiles[selected-1]}"
   	echo "Setting up $selected_profile..."
	compile_file "$selected_profile"
else
	echo "Exiting..."
	exit 1
fi

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

xrdb -merge "$user_conf"
echo
echo "The changes will be applied to new xterm sessions"

