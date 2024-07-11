#!/bin/bash

BACKUP_DIR=$HOME"/.vim/backup"
UNDO_DIR=$HOME"/.vim/undo"
SWP_DIR=$HOME"/.vim/swp"
PLUGIN_DIR=$HOME"/.vim/pack/plugins/start"
COLORS_DIR=$HOME"/.vim/colors"

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
)

read -p "Do you want to setup fzf for vim? (y/n) " setup_fzf
case "$setup_fzf" in
	y|Y )
		plugin_repos+=("https://github.com/junegunn/fzf.git")
		plugin_repos+=("https://github.com/junegunn/fzf.vim.git")
		;;
	* )
		echo "fzf will not be configured for vim"
esac


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

case "$setup_fzf" in
    y|Y )
	    echo "Setting up fzf..."
	    $PLUGIN_DIR/fzf/install
	    echo -e "\r\n"
	    ;;
esac

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
			;;
	esac
else
	echo "Creating symlink for .vimrc..."
	ln -s "$current_dir/.vimrc" "$user_vimrc"
 	echo "Symlink created to $current_dir/.vimrc from $user_vimrc"
fi

setup_acme="n"
read -p "Do you want to install Plan-9 inspired Acme colorscheme? (y/n) " setup_acme

if [[ "$setup_acme" =~ ^[Yy]$ ]]; then
	mkdir -p "$COLORS_DIR"
	user_acme="$COLORS_DIR/acme.vim"

	if [ -e "$user_acme" ]; then
		echo "A colorscheme called 'acme.vim' already exists in '$user_acme'."
		read -p "Do you want to replace it? (y/n) " choice
		case "$choice" in
			y|Y )
				echo "Replacing existing acme.vim"
				rm -f "$user_acme"
				ln -s "$current_dir/.vim/colors/acme.vim" "$user_acme"
				;;
			* )
				echo "Keeping existing 'acme.vim'"
				;;
		esac
	else
		ln -s "$current_dir/.vim/colors/acme.vim" "$user_acme"
		echo "Symlink created to $current_dir/.vim/colors/acme.vim from $user_acme"
	fi
fi

