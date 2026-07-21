#!/usr/bin/env bash
# Interactive tar.xz archive streamed directly to a chosen target.

# Critical commands are checked explicitly so failures can report context and
# clean up partial output predictably.
set -u

XZ_LEVEL="-6"
XZ_THREADS="-T0"
DEFAULT_SOURCE="$HOME"

# Exclusions are opt-in so a backup is never silently incomplete. A leading
# ./ anchors a pattern to the source root; other patterns match at any depth.
SUGGESTED_EXCLUDES=(
  "node_modules"
  ".cache"
  ".thumbnails"
  ".local"
  "./VMs"
  "./VirtualBox VMs"
  "*.qcow2"
  "*.vdi"
  "*.vmdk"
  "*.iso"
  "*.img"
  "*.raw"
  ".npm"
  ".cargo/registry"
  ".rustup"
  "*.sock"
)

c_bold=$'\e[1m'; c_dim=$'\e[2m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'
c_red=$'\e[31m'; c_cyn=$'\e[36m'; c_rst=$'\e[0m'
if [ ! -t 1 ]; then c_bold=; c_dim=; c_grn=; c_yel=; c_red=; c_cyn=; c_rst=; fi

info() { printf '%s\n' "$*"; }
warn() { printf '%s%s%s\n' "$c_yel" "$*" "$c_rst" >&2; }
err()  { printf '%s%s%s\n' "$c_red" "$*" "$c_rst" >&2; }
hdr()  { printf '\n%s%s%s\n' "$c_bold" "$*" "$c_rst"; }
die()  { err "Error: $*"; exit 1; }

human() {
  numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || printf '%sB' "${1:-0}"
}

fmt_time() {
  local t=$1 h m s
  h=$((t / 3600)); m=$(((t % 3600) / 60)); s=$((t % 60))
  if ((h > 0)); then
    printf '%dh%02dm%02ds' "$h" "$m" "$s"
  else
    printf '%02dm%02ds' "$m" "$s"
  fi
}

confirm() {
  local prompt=$1 ans
  IFS= read -r -p "$prompt [y/N] " ans || return 1
  [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]
}

PROGRESS_PID=""
PIPELINE_PID=""
PARTIAL_ARCHIVE=""
PARTIAL_CHECKSUM=""
STREAM_HASH_FILE=""
PIPELINE_STATUS_FILE=""

stop_active_pipeline() {
  if [ -n "$PIPELINE_PID" ]; then
    kill -s TERM -- "-$PIPELINE_PID" 2>/dev/null || true
    wait "$PIPELINE_PID" 2>/dev/null || true
    PIPELINE_PID=""
  fi
}

cleanup() {
  local partial temporary
  stop_active_pipeline
  if [ -n "$PROGRESS_PID" ]; then
    kill "$PROGRESS_PID" 2>/dev/null || true
    wait "$PROGRESS_PID" 2>/dev/null || true
    PROGRESS_PID=""
  fi

  for partial in "$PARTIAL_ARCHIVE" "$PARTIAL_CHECKSUM"; do
    if [ -n "$partial" ] && [ -e "$partial" ]; then
      if rm -f -- "$partial"; then
        warn "Removed partial output: $partial"
      else
        warn "Could not remove partial output: $partial"
      fi
    fi
  done

  for temporary in "$STREAM_HASH_FILE" "$PIPELINE_STATUS_FILE"; do
    if [ -n "$temporary" ] && [ -e "$temporary" ]; then
      rm -f -- "$temporary" || true
    fi
  done
}

on_signal() {
  local signal=$1 status=$2
  trap '' HUP INT TERM
  printf '\n'
  warn "Interrupted by $signal."
  stop_active_pipeline
  exit "$status"
}

preflight() {
  local missing=() tool tar_version
  for tool in tar xz tee sha256sum stat numfmt lsblk findmnt sync mktemp hostname date rm mv sleep; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  ((${#missing[@]} == 0)) || die "missing required tools: ${missing[*]}"

  tar_version="$(tar --version 2>/dev/null)" || die "cannot run tar"
  [[ "$tar_version" == *"GNU tar"* ]] || die "GNU tar is required for exclusion semantics"
}

expand_home_path() {
  case "$1" in
    "~") printf '%s' "$HOME" ;;
    "~/"*) printf '%s/%s' "$HOME" "${1:2}" ;;
    *) printf '%s' "$1" ;;
  esac
}

choose_source() {
  local answer
  hdr "Source directory to back up"
  IFS= read -r -p "Path [${DEFAULT_SOURCE}]: " answer || die "input closed"
  SOURCE="$(expand_home_path "${answer:-$DEFAULT_SOURCE}")"
  [ -d "$SOURCE" ] || die "not a directory: $SOURCE"
  [ -r "$SOURCE" ] || die "not readable: $SOURCE"
  SOURCE="$(cd -- "$SOURCE" && pwd -P)" || die "cannot resolve source: $SOURCE"
}

EXCLUDES=()
TAR_EXCLUDE_ARGS=()

is_broad() {
  [[ "$1" == *"*"* || "$1" == ".local" ]]
}

choose_excludes() {
  local i pattern flag picks choice custom
  local -a choices=()

  hdr "Exclusions"
  info "Nothing is excluded unless you pick it. Suggestions (all OFF):"
  for i in "${!SUGGESTED_EXCLUDES[@]}"; do
    pattern="${SUGGESTED_EXCLUDES[$i]}"
    flag=""
    is_broad "$pattern" && flag=" ${c_yel}(broad — can drop wanted files)${c_rst}"
    printf '  %2d) %-22s%s\n' "$((i + 1))" "$pattern" "$flag"
  done
  info "${c_dim}  Leading ./ = source root; otherwise the pattern matches at any depth.${c_rst}"

  IFS= read -r -p "Numbers to exclude (space-separated), blank for none: " picks || die "input closed"
  read -r -a choices <<< "$picks"
  for choice in "${choices[@]}"; do
    if [[ "$choice" =~ ^[0-9]+$ ]] &&
       ((choice >= 1 && choice <= ${#SUGGESTED_EXCLUDES[@]})); then
      EXCLUDES+=("${SUGGESTED_EXCLUDES[$((choice - 1))]}")
    else
      warn "  ignoring invalid choice: $choice"
    fi
  done

  info "Add custom patterns (one per line, blank to finish):"
  while IFS= read -r -p "  + " custom; do
    [ -n "$custom" ] || break
    EXCLUDES+=("$custom")
  done

  hdr "Final exclusion list"
  if ((${#EXCLUDES[@]} == 0)); then
    info "  (none — full contents will be archived)"
  else
    for pattern in "${EXCLUDES[@]}"; do
      if [[ "$pattern" == ./* ]]; then
        printf '  anchored  %s\n' "$pattern"
      else
        printf '  any-depth %s\n' "$pattern"
      fi
    done
  fi
  confirm "Proceed with this exclusion list?" || die "aborted by user"
}

build_tar_excludes() {
  local pattern
  TAR_EXCLUDE_ARGS=()
  for pattern in "${EXCLUDES[@]}"; do
    if [[ "$pattern" == ./* ]]; then
      TAR_EXCLUDE_ARGS+=(--anchored "--exclude=$pattern")
    else
      TAR_EXCLUDE_ARGS+=(--no-anchored "--exclude=$pattern")
    fi
  done
}

# Decode findmnt's \xNN fields so mount paths containing spaces remain usable.
decode_findmnt_field() {
  printf '%b' "$1"
}

dev_is_removable() {
  local dev="${1%%\[*}" rm_flag hotplug transport
  [ -b "$dev" ] || return 1

  while read -r rm_flag hotplug transport; do
    if [ "$rm_flag" = "1" ] || [ "$hotplug" = "1" ] || [ "$transport" = "usb" ]; then
      return 0
    fi
  done < <(lsblk -srno RM,HOTPLUG,TRAN "$dev" 2>/dev/null)
  return 1
}

choose_target() {
  local encoded_target encoded_source target source fstype total avail flag label
  local selection base mountpoint subdirectory chosen_mount=""
  MNT_PATHS=()
  MNT_LABELS=()

  hdr "Target location"
  while IFS= read -r encoded_target; do
    target="$(decode_findmnt_field "$encoded_target")"
    [ -d "$target" ] || continue
    findmnt -frn --target "$target" -O rw >/dev/null 2>&1 || continue

    encoded_source="$(findmnt -frn --real --target "$target" -o SOURCE 2>/dev/null)" || continue
    source="$(decode_findmnt_field "$encoded_source")"
    case "$source" in /dev/*) ;; *) continue ;; esac

    fstype="$(findmnt -frn --real --target "$target" -o FSTYPE 2>/dev/null)" || continue
    total=0
    avail=0
    read -r total avail < <(findmnt -fbn --target "$target" -o SIZE,AVAIL 2>/dev/null) || true

    flag=""
    dev_is_removable "$source" && flag="${c_grn}[USB/removable]${c_rst}"
    printf -v label '%-24s %-15s %8s free / %8s  %-6s %s' \
      "$target" "$flag" "$(human "$avail")" "$(human "$total")" "$fstype" "$source"
    MNT_PATHS+=("$target")
    MNT_LABELS+=("$label")
  done < <(findmnt -rnU --real -o TARGET 2>/dev/null)

  info "Mounted writable block filesystems:"
  if ((${#MNT_PATHS[@]} == 0)); then
    info "  (none detected)"
  else
    local i
    for i in "${!MNT_PATHS[@]}"; do
      printf '  %2d) %s\n' "$((i + 1))" "${MNT_LABELS[$i]}"
    done
  fi
  printf '   t) Type a custom path\n'

  while true; do
    IFS= read -r -p "Choose a number or 't': " selection || die "input closed"
    if [ "$selection" = "t" ]; then
      IFS= read -r -p "Absolute target directory path: " base || die "input closed"
      base="$(expand_home_path "$base")"
      if [[ "$base" != /* ]]; then
        warn "target path must be absolute"
        continue
      fi
      [ -n "$base" ] || { warn "empty path"; continue; }
      break
    elif [[ "$selection" =~ ^[0-9]+$ ]] &&
         ((selection >= 1 && selection <= ${#MNT_PATHS[@]})); then
      mountpoint="${MNT_PATHS[$((selection - 1))]}"
      IFS= read -r -p "Existing subdirectory under $mountpoint (blank = root): " subdirectory || die "input closed"
      base="$mountpoint${subdirectory:+/$subdirectory}"
      chosen_mount="$mountpoint"
      break
    else
      warn "invalid selection"
    fi
  done

  [ -d "$base" ] || die "not a directory: $base"
  [ -w "$base" ] || die "not writable: $base"
  TARGET_DIR="$(cd -- "$base" && pwd -P)" || die "cannot resolve target: $base"

  if [ -n "$chosen_mount" ]; then
    chosen_mount="$(cd -- "$chosen_mount" && pwd -P)" || die "cannot resolve mountpoint: $chosen_mount"
    if [ "$chosen_mount" != "/" ] &&
       [ "$TARGET_DIR" != "$chosen_mount" ] &&
       [[ "$TARGET_DIR" != "$chosen_mount/"* ]]; then
      die "selected subdirectory resolves outside its mountpoint: $TARGET_DIR"
    fi
  fi
}

target_is_within_source() {
  [ "$SOURCE" = "/" ] ||
    [ "$TARGET_DIR" = "$SOURCE" ] ||
    [[ "$TARGET_DIR" == "$SOURCE/"* ]]
}

safe_name_component() {
  local LC_ALL=C input=$1 max_length=$2 output="" character i

  for ((i = 0; i < ${#input}; i++)); do
    character="${input:i:1}"
    case "$character" in
      [A-Za-z0-9._-]) output+="$character" ;;
      *) output+="_" ;;
    esac
  done
  while [[ "$output" == .* ]]; do output="${output#.}"; done
  [ -n "$output" ] || output="backup"
  printf '%s' "${output:0:max_length}"
}

confirm_plan() {
  local base host safe_base safe_host timestamp avail=0

  target_is_within_source && die "target must be outside the source tree to avoid archiving the output"

  base="${SOURCE##*/}"
  [ -n "$base" ] || base="root"
  host="$(hostname -s 2>/dev/null)" || die "cannot determine hostname"
  # Conservative ASCII components prevent late publication failures on common
  # removable filesystems and keep room for the checksum suffix.
  safe_base="$(safe_name_component "$base" 80)"
  safe_host="$(safe_name_component "$host" 63)"
  timestamp="$(date +%Y%m%d-%H%M%S)" || die "cannot determine timestamp"
  ARCHIVE_NAME="${safe_base}-${safe_host}-${timestamp}.tar.xz"
  ARCHIVE_PATH="$TARGET_DIR/$ARCHIVE_NAME"
  CHECKSUM_PATH="$ARCHIVE_PATH.sha256"
  read -r avail < <(findmnt -fbn --target "$TARGET_DIR" -o AVAIL 2>/dev/null) || true

  hdr "Summary"
  printf '  Source     : %s\n' "$SOURCE"
  printf '  Exclusions : %d pattern(s)\n' "${#EXCLUDES[@]}"
  printf '  Target     : %s\n' "$ARCHIVE_PATH"
  printf '  Free there : %s\n' "$(human "$avail")"
  printf '  Compression: xz %s %s\n' "$XZ_LEVEL" "$XZ_THREADS"
  info "${c_dim}  Compressed size is unknown until the archive is written.${c_rst}"

  if [ -e "$ARCHIVE_PATH" ] || [ -L "$ARCHIVE_PATH" ] ||
     [ -e "$CHECKSUM_PATH" ] || [ -L "$CHECKSUM_PATH" ]; then
    die "archive or checksum already exists; refusing to overwrite"
  fi
  confirm "Start backup now?" || die "aborted by user"
}

progress_loop() {
  local file=$1 start=$SECONDS size elapsed rate
  while true; do
    size="$(stat -c %s "$file" 2>/dev/null || printf 0)"
    elapsed=$((SECONDS - start))
    if ((elapsed > 0)); then rate=$((size / elapsed)); else rate=0; fi
    printf '\r  %s · %s written · %s/s   ' \
      "$(fmt_time "$elapsed")" "$(human "$size")" "$(human "$rate")"
    sleep 2
  done
}

stop_progress() {
  if [ -n "$PROGRESS_PID" ]; then
    kill "$PROGRESS_PID" 2>/dev/null || true
    wait "$PROGRESS_PID" 2>/dev/null || true
    PROGRESS_PID=""
    printf '\n'
  fi
}

run_backup() {
  local -a pipeline_status
  local stream_hash ignored hash_line target_hash size pipeline_runner_status
  local monitor_was_set=0

  build_tar_excludes
  PARTIAL_ARCHIVE="$(mktemp --tmpdir="$TARGET_DIR" '.backup.partial.XXXXXX')" || die "cannot create partial archive on target"
  STREAM_HASH_FILE="$(mktemp)" || die "cannot create temporary checksum file"
  PIPELINE_STATUS_FILE="$(mktemp)" || die "cannot create temporary pipeline status file"

  hdr "Creating archive"
  info "  -> $ARCHIVE_PATH"
  if [ -t 1 ]; then
    progress_loop "$PARTIAL_ARCHIVE" &
    PROGRESS_PID=$!
  fi

  [[ "$-" == *m* ]] && monitor_was_set=1
  set -m || die "cannot enable archive process-group management"
  (
    local -a child_status
    trap - EXIT HUP INT TERM
    # Members use ./ so source-root exclusion patterns have a stable anchor.
    tar "${TAR_EXCLUDE_ARGS[@]}" -cf - -C "$SOURCE" . \
      | xz "$XZ_LEVEL" "$XZ_THREADS" -c \
      | tee -- "$PARTIAL_ARCHIVE" \
      | sha256sum > "$STREAM_HASH_FILE"
    child_status=("${PIPESTATUS[@]}")
    printf '%s %s %s %s\n' \
      "${child_status[0]}" "${child_status[1]}" \
      "${child_status[2]}" "${child_status[3]}" > "$PIPELINE_STATUS_FILE"
  ) &
  PIPELINE_PID=$!
  ((monitor_was_set == 1)) || set +m

  wait "$PIPELINE_PID"
  pipeline_runner_status=$?
  PIPELINE_PID=""
  stop_progress

  ((pipeline_runner_status == 0)) || die "archive pipeline runner failed (exit $pipeline_runner_status)"
  read -r -a pipeline_status < "$PIPELINE_STATUS_FILE" || die "cannot read archive pipeline status"
  ((${#pipeline_status[@]} == 4)) || die "invalid archive pipeline status"
  if ((pipeline_status[0] != 0 || pipeline_status[1] != 0 ||
       pipeline_status[2] != 0 || pipeline_status[3] != 0)); then
    die "backup pipeline failed (tar=${pipeline_status[0]}, xz=${pipeline_status[1]}, tee=${pipeline_status[2]}, sha256sum=${pipeline_status[3]})"
  fi
  info "${c_grn}Archive stream completed cleanly.${c_rst}"

  hdr "Checking target write"
  info "  forcing writeback, then comparing target bytes with the streaming checksum…"
  sync -f "$PARTIAL_ARCHIVE" || die "target writeback failed"

  IFS=' ' read -r stream_hash ignored < "$STREAM_HASH_FILE" || die "cannot read streaming checksum"
  [[ "$stream_hash" =~ ^[0-9a-f]{64}$ ]] || die "invalid streaming checksum"
  hash_line="$(sha256sum -- "$PARTIAL_ARCHIVE")" || die "cannot read archive back from target"
  target_hash="${hash_line%% *}"
  [ "$target_hash" = "$stream_hash" ] || die "written archive differs from the compressed stream"

  PARTIAL_CHECKSUM="$(mktemp --tmpdir="$TARGET_DIR" '.backup.sha256.partial.XXXXXX')" || die "cannot create partial checksum on target"
  printf '%s  %s\n' "$target_hash" "$ARCHIVE_NAME" > "$PARTIAL_CHECKSUM" || die "cannot write checksum"
  sync -f "$PARTIAL_CHECKSUM" || die "checksum writeback failed"

  # No-clobber publication prevents a long backup from replacing a path that
  # appeared after confirmation; -T prevents directories becoming containers.
  mv -Tn -- "$PARTIAL_ARCHIVE" "$ARCHIVE_PATH" || die "cannot publish archive"
  [ ! -e "$PARTIAL_ARCHIVE" ] || die "archive path appeared during backup; refusing to overwrite"
  PARTIAL_ARCHIVE=""

  mv -Tn -- "$PARTIAL_CHECKSUM" "$CHECKSUM_PATH" || die "archive published but checksum could not be published"
  [ ! -e "$PARTIAL_CHECKSUM" ] || die "archive published but checksum path appeared; refusing to overwrite"
  PARTIAL_CHECKSUM=""
  sync -f "$TARGET_DIR" || die "archive was published but directory writeback failed"

  size="$(stat -c %s "$ARCHIVE_PATH")" || die "cannot read final archive size"
  hdr "${c_grn}Backup complete; stream and target hashes match.${c_rst}"
  printf '  Archive : %s\n' "$ARCHIVE_PATH"
  printf '  Checksum: %s\n' "$CHECKSUM_PATH"
  printf '  Size    : %s\n' "$(human "$size")"
}

main() {
  trap cleanup EXIT
  trap 'on_signal HUP 129' HUP
  trap 'on_signal INT 130' INT
  trap 'on_signal TERM 143' TERM

  hdr "${c_cyn}backup.sh — interactive tar.xz backup${c_rst}"
  preflight
  choose_source
  choose_excludes
  choose_target
  confirm_plan
  run_backup
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
