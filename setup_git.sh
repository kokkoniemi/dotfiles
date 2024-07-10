#!/bin/bash

echo -n "Checking if git is installed... "
if which git >/dev/null 2>&1; then
	echo "OK"
else
	echo "not installed. Exiting... "
	exit 1
fi

current_username=$(git config --global user.name)
current_email=$(git config --global user.email)

echo "Current Git Configuration:"
echo "Username: ${current_username:-<not set>}"
echo "Email: ${current_email:-<not set>}"
echo

update_git_config() {
    read -p "Enter new Git username: " new_username
    read -p "Enter new Git email: " new_email

    git config --global user.name "$new_username"
    git config --global user.email "$new_email"

    echo "Git configuration updated."
}

if [[ -z "$current_username" || -z "$current_email" ]]; then
    echo "Git username or email is not set."
    update_git_config
else
    # Prompt if user wants to update the configuration
    read -p "Do you want to update your Git configuration? (y/n): " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
        update_git_config
    else
        echo "Git configuration not updated."
    fi
fi

