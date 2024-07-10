#!/bin/bash

if ! which git >/dev/null 2>&1; then
	echo "Git is required but not installed."
	echo "Please install Git and try again."
	exit 1
fi

echo "Installing monaspace fonts..."

CURRENT_DIR="$(pwd)"
CLONE_DIR="/tmp/monaspace"

rm -rf "$CLONE_DIR"
git clone https://github.com/githubnext/monaspace.git "$CLONE_DIR"
cd "$CLONE_DIR/util/"

case "$(uname -s)" in
	Darwin)
		./install_macos.sh
		;;
	Linux)
		./install_linux.sh
		;;
	*)
		echo "$(uname -s) is not supported"
		;;
esac

cd "$CURRENT_DIR"
echo "Removing $CLONE_DIR"
rm -rf "$CLONE_DIR"

echo "DONE"

