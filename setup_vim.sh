#!/bin/bash

BACKUP_DIR=$HOME"/.vim/backup"
UNDO_DIR=$HOME"/.vim/undo"
SWP_DIR=$HOME"/.vim/swp"
PLUGIN_DIR=$HOME"/.vim/pack/plugins/start"

echo -n "Checking if git is installed... "
if which git >/dev/null 2>&1; then
	echo "OK"
else
	echo "not installed. Exiting... "
	exit 1
fi

echo -n "Checking if backup directory exists... "
if [ ! -d "$BACKUP_DIR" ]; then
	mkdir -p "$BACKUP_DIR"
	echo "created $BACKUP_DIR"
else
	echo "$BACKUP_DIR already exists"
fi

echo -n "Checking if swap file directory exists... "
if [ ! -d "$SWP_DIR" ]; then
	mkdir -p "$SWP_DIR"
	echo "created $SWP_DIR"
else
	echo "$SWP_DIR already exists"
fi

echo -n "Checking if undo directory exists... "
if [ ! -d "$UNDO_DIR" ]; then
	mkdir -p "$UNDO_DIR"
	echo "created $UNDO_DIR"
else
	echo "$UNDO_DIR already exists"
fi

echo -n "Checking if plugin directory exists... "
if [ ! -d "$PLUGIN_DIR" ]; then
	mkdir -p "$PLUGIN_DIR"
	echo "created $PLUGIN_DIR"
else
	echo "$PLUGIN_DIR already exists"
fi

echo "Setting up plugins..."

plugin_repos=(
	"https://github.com/prabirshrestha/vim-lsp.git"
	"https://github.com/prabirshrestha/asyncomplete-lsp.vim.git"
	"https://github.com/prabirshrestha/asyncomplete.vim.git"
	"https://github.com/mattn/vim-lsp-settings.git"
	"https://github.com/junegunn/fzf.git"
	"https://github.com/junegunn/fzf.vim.git"
)

current_dir=$(pwd)

for repo in "${plugin_repos[@]}"; do
	repo_name=$(basename -s .git "$repo")
	repo_dir="$PLUGIN_DIR/$repo_name"

	if [ -d "$repo_dir" ]; then
		echo -n "Plugin $repo_name already exists. Pulling latest changes... "
		cd "$repo_dir" && git pull >/dev/null 2>&1 && cd "$current_dir"
		echo "OK"
	else
		echo -n "Cloning plugin $repo_name... "
		git clone "$repo" "$repo_dir" >/dev/null 2>&1
		echo "OK"
	fi
done

echo "Setting up fzf..."
$PLUGIN_DIR/fzf/install
echo -e "\r\n"

echo "Setting up .vimrc..."
user_vimrc=$HOME"/.vimrc"

if [ -e "$user_vimrc" ]; then
	echo ".vimrc already exists in home directory."
	read -p "Do you want to replace it? (y/n) " choice
	case "$choice" in
		y|Y )
			echo "Replacing existing .vimrc"
			rm -f "$user_vimrc"
			ln -s "$current_dir/.vimrc" "$user_vimrc"
			;;
		* )
			echo "Keeping existing .vimrc"
	esac
else
	echo "Creating symlink for .vimrc..."
	ln -s "$current_dir/.vimrc" "$user_vimrc"
 	echo "Symlink created from $current_dir/.vimrc to $user_vimrc"
fi

