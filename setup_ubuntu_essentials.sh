#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

export DEBIAN_FRONTEND=noninteractive

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOCK_FILE="/tmp/setup_ubuntu_essentials.lock"
readonly SUPPORTED_OS_ID="ubuntu"
readonly SUPPORTED_OS_VERSION="24.04"

DRY_RUN=0
FORCE=0
VERBOSE=0
APT_UPDATED=0
TMP_DIR=""

readonly ONEPASSWORD_KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
readonly ONEPASSWORD_POLICY_URL="https://downloads.1password.com/linux/debian/debsig/1password.pol"
readonly ONEPASSWORD_KEY_SHA256="f39e7dd9dedc581ced85732832f217e0de5860a3b80279b5af4bc7c6d8157bae"
readonly ONEPASSWORD_POLICY_SHA256="c0c148807d8dc588750a9cc512c7243ed10a9cfd5519a5a6f0a038ad66a19c39"
readonly ONEPASSWORD_SOURCE="deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main"
readonly ONEPASSWORD_KEYRING="/usr/share/keyrings/1password-archive-keyring.gpg"
readonly ONEPASSWORD_SOURCE_LIST="/etc/apt/sources.list.d/1password.list"
readonly ONEPASSWORD_DEBSIG_POLICY="/etc/debsig/policies/AC2D62742012EA22/1password.pol"
readonly ONEPASSWORD_DEBSIG_KEYRING="/usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg"

readonly OPENSNITCH_VERSION="1.8.0-1"
readonly OPENSNITCH_RELEASE_TAG="v1.8.0"
readonly OPENSNITCH_BASE_URL="https://github.com/evilsocket/opensnitch/releases/download/${OPENSNITCH_RELEASE_TAG}"
readonly OPENSNITCH_DAEMON_DEB="opensnitch_${OPENSNITCH_VERSION}_amd64.deb"
readonly OPENSNITCH_UI_DEB="python3-opensnitch-ui_${OPENSNITCH_VERSION}_all.deb"
readonly OPENSNITCH_DAEMON_SHA256="9f517926877f07761ca95ec43dc9daefecac582574f9856079e1064be3fa1c8a"
readonly OPENSNITCH_UI_SHA256="3597e6ae5eedbf706622cd64bddc9649acca165ac1f63a444585dfda5435003d"

readonly APT_INSTALL_OPTIONS=(
    -y
    --no-install-recommends
    -o Dpkg::Options::=--force-confdef
    -o Dpkg::Options::=--force-confold
)

readonly ESSENTIAL_PACKAGES=(
    ca-certificates
    curl
    fzf
    gcc
    git
    gnupg
    make
    ripgrep
    tmux
    vim
    vim-gtk3
    wireguard-tools
    wl-clipboard
)

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Options:
  --dry-run   Print planned changes without modifying the system.
  --force     Run even when the detected OS is not Ubuntu 24.04.
  --verbose   Enable shell tracing.
  -h, --help  Show this help.
EOF
}

log() {
    printf '[%s] %s\n' "$SCRIPT_NAME" "$*"
}

join_args() {
    local IFS=' '
    printf '%s' "$*"
}

die() {
    printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2
    exit 1
}

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '+'
        printf ' %q' "$@"
        printf '\n'
        return 0
    fi

    "$@"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                ;;
            --force)
                FORCE=1
                ;;
            --verbose)
                VERBOSE=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
        shift
    done

    if [[ "$VERBOSE" -eq 1 ]]; then
        set -x
    fi
}

acquire_lock() {
    require_cmd flock

    exec 9>"$LOCK_FILE"
    flock -n 9 || die "Another ${SCRIPT_NAME} run is already active."
}

check_os() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    fi

    if [[ "${ID:-}" == "$SUPPORTED_OS_ID" && "${VERSION_ID:-}" == "$SUPPORTED_OS_VERSION" ]]; then
        return 0
    fi

    if [[ "$FORCE" -eq 1 ]]; then
        log "Unsupported OS detected (${PRETTY_NAME:-unknown OS}); continuing because --force was passed."
        return 0
    fi

    die "This script is built for Ubuntu 24.04. Detected: ${PRETTY_NAME:-unknown OS}. Pass --force to override."
}

check_prerequisites() {
    require_cmd apt-get
    require_cmd dpkg
    require_cmd dpkg-query
    require_cmd install
    require_cmd sha256sum
    require_cmd sudo
}

apt_update() {
    local force="${1:-0}"

    if [[ "$force" -eq 1 || "$APT_UPDATED" -eq 0 ]]; then
        log "Updating apt package indexes."
        run sudo apt-get update
        APT_UPDATED=1
    fi
}

is_package_installed() {
    local package="$1"

    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$'
}

installed_package_version() {
    local package="$1"

    dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true
}

install_apt_packages() {
    local missing=()
    local package

    for package in "$@"; do
        if ! is_package_installed "$package"; then
            missing+=("$package")
        fi
    done

    if [[ "${#missing[@]}" -eq 0 ]]; then
        log "Apt packages already installed: $(join_args "$@")"
        return 0
    fi

    apt_update
    log "Installing apt packages: $(join_args "${missing[@]}")"
    run sudo apt-get install "${APT_INSTALL_OPTIONS[@]}" "${missing[@]}"
}

make_tmp_dir() {
    if [[ -z "$TMP_DIR" ]]; then
        TMP_DIR="$(mktemp -d)"
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    local sha256="$3"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would download and verify $url"
        return 0
    fi

    log "Downloading $url"
    curl -fsSL --retry 3 --retry-delay 2 -o "$output" "$url"
    printf '%s  %s\n' "$sha256" "$output" | sha256sum -c -
}

install_if_changed() {
    local source="$1"
    local destination="$2"
    local mode="$3"
    local destination_dir

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would install $destination if content differs."
        return 0
    fi

    destination_dir="$(dirname "$destination")"
    run sudo install -d -m 0755 "$destination_dir"

    if sudo test -f "$destination" && sudo cmp -s "$source" "$destination"; then
        log "$destination is already up to date."
        return 1
    fi

    run sudo install -m "$mode" "$source" "$destination"
    log "Updated $destination."
    return 0
}

configure_1password_repo() {
    local changed=0
    local key_ascii
    local keyring
    local policy
    local source_list

    make_tmp_dir
    key_ascii="${TMP_DIR}/1password.asc"
    keyring="${TMP_DIR}/1password-archive-keyring.gpg"
    policy="${TMP_DIR}/1password.pol"
    source_list="${TMP_DIR}/1password.list"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would ensure the 1Password apt repository, keyring, and debsig policy are configured."
        return 0
    fi

    download_file "$ONEPASSWORD_KEY_URL" "$key_ascii" "$ONEPASSWORD_KEY_SHA256"
    gpg --batch --yes --dearmor --output "$keyring" "$key_ascii"
    printf '%s\n' "$ONEPASSWORD_SOURCE" > "$source_list"
    download_file "$ONEPASSWORD_POLICY_URL" "$policy" "$ONEPASSWORD_POLICY_SHA256"

    if install_if_changed "$keyring" "$ONEPASSWORD_KEYRING" 0644; then
        changed=1
    fi
    if install_if_changed "$source_list" "$ONEPASSWORD_SOURCE_LIST" 0644; then
        changed=1
    fi
    if install_if_changed "$policy" "$ONEPASSWORD_DEBSIG_POLICY" 0644; then
        changed=1
    fi
    if install_if_changed "$keyring" "$ONEPASSWORD_DEBSIG_KEYRING" 0644; then
        changed=1
    fi

    if [[ "$changed" -eq 1 ]]; then
        apt_update 1
    fi
}

install_1password() {
    configure_1password_repo
    install_apt_packages 1password
}

check_opensnitch_architecture() {
    local arch

    arch="$(dpkg --print-architecture)"
    [[ "$arch" == "amd64" ]] || die "OpenSnitch package URLs are pinned for amd64, but this system is ${arch}."
}

install_opensnitch() {
    local daemon_version
    local ui_version
    local daemon_deb
    local ui_deb

    check_opensnitch_architecture

    daemon_version="$(installed_package_version opensnitch)"
    ui_version="$(installed_package_version python3-opensnitch-ui)"

    if [[ "$daemon_version" == "$OPENSNITCH_VERSION" && "$ui_version" == "$OPENSNITCH_VERSION" ]]; then
        log "OpenSnitch ${OPENSNITCH_VERSION} packages are already installed."
        return 0
    fi

    make_tmp_dir
    daemon_deb="${TMP_DIR}/${OPENSNITCH_DAEMON_DEB}"
    ui_deb="${TMP_DIR}/${OPENSNITCH_UI_DEB}"

    download_file "${OPENSNITCH_BASE_URL}/${OPENSNITCH_DAEMON_DEB}" "$daemon_deb" "$OPENSNITCH_DAEMON_SHA256"
    download_file "${OPENSNITCH_BASE_URL}/${OPENSNITCH_UI_DEB}" "$ui_deb" "$OPENSNITCH_UI_SHA256"

    apt_update
    log "Installing OpenSnitch ${OPENSNITCH_VERSION} packages."
    run sudo apt-get install "${APT_INSTALL_OPTIONS[@]}" "$daemon_deb" "$ui_deb"
}

main() {
    trap cleanup EXIT

    parse_args "$@"
    acquire_lock
    check_os
    check_prerequisites
    install_apt_packages "${ESSENTIAL_PACKAGES[@]}"
    install_1password
    install_opensnitch

    log "Done."
}

main "$@"
