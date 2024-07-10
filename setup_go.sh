#!/bin/bash

if ! which jq >/dev/null 2>&1; then
	echo "'jq' is required but not installed."
	echo "Please install 'jq' and try again..."
	exit 1
fi

DOWNLOAD_URL="https://go.dev/dl"
INSTALL_LOCATION="$HOME/.go"

if [ -f "$INSTALL_LOCATION/bin/go" ]; then
	current_version="$($INSTALL_LOCATION/bin/go version | awk '{print $3}')"
elif command -v go >/dev/null 2>&1; then
	current_version="$(go version | awk '{print $3}')"
else
	current_version="<not detected>"
fi

available_versions=()

while IFS= read -r line; do
	available_versions+=("$line")
done < <(curl -s "$DOWNLOAD_URL/?mode=json" | jq -r '.[].version')

echo "Current go version: $current_version"
echo "-------------------"
echo "Available versions:"
for i in "${!available_versions[@]}"; do
	echo "$((i+1))) ${available_versions[i]}"
done

read -p "Enter the option number or press ENTER to exit: " selected

max_valid_option=${#available_versions[@]}
if [[ "$selected" =~ ^[0-9]+$ ]] && \
   [ "$selected" -ge 1 ] && \
   [ "$selected" -le "$max_valid_option" ]; then
	selected_version="${available_versions[selected-1]}"
   	echo "Installing $selected_version..."
else
	echo "Exiting..."
	exit 1
fi

install_version() {
	local system="$1"
	local arch="$2"

	local package_name="${selected_version}.${system}-${arch}.tar.gz"
	local package_url="$DOWNLOAD_URL/$package_name"

	curl -so "/tmp/$package_name" -L "$package_url"
	rm -rf "$INSTALL_LOCATION"
	mkdir -p "$INSTALL_LOCATION"
	tar -C "$INSTALL_LOCATION" --strip-components=1 -xzf "/tmp/${package_name}"
	rm "/tmp/$package_name"

	echo "$selected_version installed to $INSTALL_LOCATION"
}

case "$(uname -s)" in
	Darwin)
		case "$(uname -m)" in
			arm64|aarch64)
				install_version "darwin" "arm64"
				;;
			x86_64)
				install_version "darwin" "amd64"
				;;
			*)
				echo "$(uname -m) not supported" >&2
				exit 1
				;;
		esac
		;;
	Linux)
		case "$(uname -m)" in
			arm64|aarch64|armv8)
				install_version "linux" "arm64"
				;;
			x86_64)
				install_version "linux" "amd64"
				;;
			i386|i686)
				install_version "linux" "386"
				;;
			*)
				echo "$(uname -m) not supported" >&2
				exit 1
				;;
		esac
		;;
	*)
		echo "$(uname -s) not supported" >&2
		exit 1
		;;
esac

case "$(basename $SHELL)" in
	zsh)
		shell_config="$HOME/.zshrc"
		;;
	bash)
		shell_config="$HOME/.bashrc"
		;;
	*)
		echo "$(basename $SHELL) not supported"
		exit 1
		;;
esac


read -p "Do you want to add Go bin directory to your PATH? (y/n): " add_path
if [[ "$add_path" =~ ^[Yy]$ ]]; then
	
	go_bin="$INSTALL_LOCATION/bin"

	if ! grep -q "export PATH=.*$go_bin" "$shell_config"; then
		echo -e "\n# Add Go binary to path" >> "$shell_config"
		echo "export PATH=\"$go_bin:\$PATH\"" >> "$shell_config"
		export PATH="$go_bin:$PATH"
		echo "added $go_bin to PATH in $shell_config"

		echo "Please restart your terminal or run 'source $shell_config' \
			to apply the PATH changes."

	else
		echo "$go_bin is already in PATH in $shell_config"
	fi
fi


read -p "Do you want to setup GOPATH and GOBIN env vars? (y/n): " add_env_vars
if [[ "$add_env_vars" =~ ^[Yy]$ ]]; then
	if ! grep -q "export GOPATH=.*" "$shell_config"; then
		echo "export GOPATH=\"$HOME/go\"" >> "$shell_config"
		export GOPATH="$HOME/go"
		echo "GOPATH is set to $GOPATH"
	else
		echo "GOPATH is already set in $shell_config"
	fi


	if ! grep -q "export GOBIN=.*" "$shell_config"; then
		echo "export GOBIN=\"$GOPATH/bin\"" >> "$shell_config"
		export GOBIN="$GOPATH/bin"
		echo "GOBIN is set to $GOBIN"
	else
		echo "GOBIN is already set in $shell_config"
	fi


	if ! grep -q "export PATH=.*\$GOBIN" "$shell_config"; then
		echo "export PATH=\"\$GOBIN:\$PATH\"" >> "$shell_config"
		export PATH="$GOBIN:$PATH"
		echo "Added \$GOBIN to \$PATH"
	fi
fi


install_dlv="no"

if ! command -v dlv >/dev/null 2>&1; then
	read -p "Delve is not installed. Do you want to install it? (y/n)" install_dlv
fi

if [[ "$install_dlv" =~ ^[Yy]$ ]]; then
	go install github.com/go-delve/delve/cmd/dlv@latest
fi

