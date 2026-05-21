#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename "$0")"

# Fira Mono Nerd Font from Nerd Fonts v3.4.0.
# Release: https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.4.0
# Checksum source: https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/SHA-256.txt
readonly FONT_VERSION="v3.4.0"
readonly FONT_ARCHIVE="FiraMono.zip"
readonly FONT_SHA256="ef37b99164614ad518721a8f3b1a1f654bac060dba820e73fa3b3e4cce8841e4"
readonly FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${FONT_ARCHIVE}"
readonly INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
readonly INSTALL_DIR="${INSTALL_ROOT}/FiraMonoNerdFont"
readonly METADATA_FILE="${INSTALL_DIR}/.install-info"
readonly MANIFEST_FILE="${INSTALL_DIR}/.manifest.sha256"

DRY_RUN=0
FORCE=0
VERBOSE=0
TMP_DIR=""

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Options:
  --dry-run   Print planned changes without modifying the system.
  --force     Reinstall even when the pinned font version is already present.
  --verbose   Enable shell tracing.
  -h, --help  Show this help.
EOF
}

log() {
    printf '[%s] %s\n' "$SCRIPT_NAME" "$*"
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

check_prerequisites() {
    require_cmd curl
    require_cmd fc-cache
    require_cmd find
    require_cmd sha256sum
    require_cmd unzip
}

make_tmp_dir() {
    if [[ -z "$TMP_DIR" ]]; then
        TMP_DIR="$(mktemp -d)"
    fi
}

metadata_matches() {
    [[ -f "$METADATA_FILE" ]] || return 1

    grep -qx "version=${FONT_VERSION}" "$METADATA_FILE" &&
        grep -qx "url=${FONT_URL}" "$METADATA_FILE" &&
        grep -qx "archive_sha256=${FONT_SHA256}" "$METADATA_FILE"
}

manifest_matches() {
    [[ -f "$MANIFEST_FILE" ]] || return 1

    (cd "$INSTALL_DIR" && sha256sum -c "$(basename "$MANIFEST_FILE")" >/dev/null 2>&1)
}

font_files_exist() {
    local first_font

    [[ -d "$INSTALL_DIR" ]] || return 1
    first_font="$(find "$INSTALL_DIR" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) -print -quit)"
    [[ -n "$first_font" ]]
}

already_installed() {
    metadata_matches && manifest_matches && font_files_exist
}

download_archive() {
    local archive="$1"

    log "Downloading ${FONT_URL}"
    curl -fsSL --retry 3 --retry-delay 2 -o "$archive" "$FONT_URL"
    printf '%s  %s\n' "$FONT_SHA256" "$archive" | sha256sum -c -
}

extract_font_files() {
    local archive="$1"
    local extract_dir="$2"
    local entry
    local font_entries=()

    mkdir -p "$extract_dir"

    while IFS= read -r entry; do
        case "$entry" in
            *.ttf|*.otf)
                font_entries+=("$entry")
                ;;
        esac
    done < <(unzip -Z1 "$archive")

    [[ "${#font_entries[@]}" -gt 0 ]] || die "No font files found in ${FONT_ARCHIVE}."

    unzip -q "$archive" "${font_entries[@]}" -d "$extract_dir"
}

replace_installed_fonts() {
    local extract_dir="$1"
    local font_file

    run mkdir -p "$INSTALL_ROOT"
    run rm -rf "$INSTALL_DIR"
    run mkdir -p "$INSTALL_DIR"

    while IFS= read -r font_file; do
        run install -m 0644 "$font_file" "$INSTALL_DIR/"
    done < <(find "$extract_dir" -type f \( -name '*.ttf' -o -name '*.otf' \) | sort)

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would write install metadata and font manifest."
        return 0
    fi

    {
        printf 'version=%s\n' "$FONT_VERSION"
        printf 'url=%s\n' "$FONT_URL"
        printf 'archive_sha256=%s\n' "$FONT_SHA256"
    } > "$METADATA_FILE"

    (
        cd "$INSTALL_DIR"
        find . -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) -printf '%P\n' |
            sort |
            xargs -r sha256sum > "$(basename "$MANIFEST_FILE")"
    )
}

install_fonts() {
    local archive
    local extract_dir

    if [[ "$FORCE" -eq 0 ]] && already_installed; then
        log "Fira Mono Nerd Font ${FONT_VERSION} is already installed at ${INSTALL_DIR}."
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would install Fira Mono Nerd Font ${FONT_VERSION} into ${INSTALL_DIR}."
        log "Would download and verify ${FONT_ARCHIVE} with SHA256 ${FONT_SHA256}."
        log "Would replace only ${INSTALL_DIR} and refresh the user font cache."
        return 0
    fi

    make_tmp_dir
    archive="${TMP_DIR}/${FONT_ARCHIVE}"
    extract_dir="${TMP_DIR}/extracted"

    download_archive "$archive"
    extract_font_files "$archive" "$extract_dir"
    replace_installed_fonts "$extract_dir"

    log "Refreshing user font cache."
    fc-cache -f "$INSTALL_ROOT"
}

main() {
    trap cleanup EXIT

    parse_args "$@"
    check_prerequisites
    install_fonts

    log "Done."
}

main "$@"
