#!/usr/bin/env bash
set -Eeuo pipefail

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: IBM Bob Quantum Computing Agent (QCA) bob-version dynamic version patch
# @Version: v2.1.5.Q28
#===============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bob-version.sh"
PATCH_ID="upgrade_patch"
APPLIANCE_CODE="QCA"
APPLIANCE_ROOT_NAME="quantum"
APPLIANCE_NAME="IBM Bob Quantum Computing Agent (QCA)"
CURRENT_BOB_VERSION="1.0.6"
MAIN_LAUNCHER_BASENAME="bob-quantum-v${CURRENT_BOB_VERSION}.sh"
MAIN_LAUNCHER_GLOB="${MAIN_LAUNCHER_BASENAME/v${CURRENT_BOB_VERSION}/v*}"

log() { printf '[%s] %s\n' "$APPLIANCE_CODE" "$*"; }
fail() { printf '[%s] ERROR: %s\n' "$APPLIANCE_CODE" "$*" >&2; exit 1; }

launcher_exists() {
  local dir="$1"
  [[ -f "$dir/$MAIN_LAUNCHER_BASENAME" ]] && return 0
  compgen -G "$dir/$MAIN_LAUNCHER_GLOB" >/dev/null 2>&1
}

resolve_target_root() {
  local here base parent candidate
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  base="$(basename "$here")"
  parent="$(basename "$(dirname "$here")")"

  if launcher_exists "$here" && [[ -d "$here/.bob" ]]; then
    printf '%s\n' "$here"
    return 0
  fi

  if [[ "$base" == "$APPLIANCE_CODE" ]] && [[ "$parent" == "patches" ]]; then
    candidate="$(cd "$here/../../use-cases/$APPLIANCE_ROOT_NAME" 2>/dev/null && pwd || true)"
    if [[ -n "$candidate" ]] && launcher_exists "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  candidate="$(cd "$here/../../use-cases/$APPLIANCE_ROOT_NAME" 2>/dev/null && pwd || true)"
  if [[ -n "$candidate" ]] && launcher_exists "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  fail "Unable to resolve appliance root. Run from patches/$APPLIANCE_CODE or use-cases/$APPLIANCE_ROOT_NAME."
}

is_text_file() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -Iq . "$f" 2>/dev/null
}

write_bob_version_script() {
  local target="$1"
  cat > "$target/bob-version.sh" <<'BOV'
#!/usr/bin/env bash
#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description: Bob Shell version detector for IBM Bob appliance launchers
# @Version: v${BOB_VERSION}
#===============================================================================

_bob_version_command="${BOB_BIN:-bob}"
_bob_version_raw=""

if [[ -n "${BOB_VERSION:-}" && "${BOB_VERSION}" != "unknown" ]]; then
  export BOB_VERSION
  return 0 2>/dev/null || exit 0
fi

if ! command -v "${_bob_version_command}" >/dev/null 2>&1; then
  printf '[bob-version] ERROR: Bob executable not found: %s\n' "${_bob_version_command}" >&2
  return 1 2>/dev/null || exit 1
fi

_bob_version_raw="$(${_bob_version_command} --version 2>/dev/null | head -n 1 | tr -d '\r' || true)"
BOB_VERSION="$(printf '%s\n' "${_bob_version_raw}" | grep -Eo '[0-9]+([.][0-9]+){1,3}([-.][A-Za-z0-9]+)?' | head -n 1 || true)"

if [[ -z "${BOB_VERSION}" ]]; then
  BOB_VERSION="$(printf '%s\n' "${_bob_version_raw}" | awk '{print $NF}' | tr -cd 'A-Za-z0-9._-')"
fi

if [[ -z "${BOB_VERSION}" ]]; then
  printf '[bob-version] ERROR: Unable to determine Bob version from: %s\n' "${_bob_version_raw:-<empty>}" >&2
  return 1 2>/dev/null || exit 1
fi

export BOB_VERSION
unset _bob_version_command _bob_version_raw
BOV
  chmod 755 "$target/bob-version.sh"
}

insert_source_block() {
  local file="$1"
  [[ "$(basename "$file")" == "bob-version.sh" ]] && return 0
  grep -q 'source .*bob-version\.sh' "$file" 2>/dev/null && return 0

  local tmp
  tmp="$(mktemp)"
  awk '
    BEGIN { inserted=0 }
    {
      print
      if (!inserted && /^set -[A-Za-z]*.*e.*u.*o pipefail/) {
        print ""
        print "# Load persistent Bob Shell version for appliance version-aware paths."
        print "if [[ -z \"${BOB_VERSION:-}\" ]]; then"
        print "  _BOB_VERSION_SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\""
        print "  if [[ -f \"${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh\" ]]; then"
        print "    # shellcheck source=/dev/null"
        print "    source \"${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh\""
        print "  fi"
        print "  unset _BOB_VERSION_SCRIPT_DIR"
        print "fi"
        inserted=1
      }
    }
    END {
      if (!inserted) {
        print ""
        print "# Load persistent Bob Shell version for appliance version-aware paths."
        print "if [[ -z \"${BOB_VERSION:-}\" ]]; then"
        print "  _BOB_VERSION_SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\""
        print "  if [[ -f \"${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh\" ]]; then"
        print "    # shellcheck source=/dev/null"
        print "    source \"${_BOB_VERSION_SCRIPT_DIR}/bob-version.sh\""
        print "  fi"
        print "  unset _BOB_VERSION_SCRIPT_DIR"
        print "fi"
      }
    }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

sanitize_content_versions() {
  local target="$1"
  while IFS= read -r -d '' f; do
    is_text_file "$f" || continue
    perl -0pi -e 's/v2\.1\.5/v\$\{BOB_VERSION\}/g' "$f"
  done < <(find "$target" -type f \
    -not -path '*/.git/*' \
    -not -path '*/.bob/patch-backups/*' \
    -not -path '*/.bob/backups/*' \
    -not -path '*/patches/*' \
    -not -name 'patch-*.sh' \
    -not -name 'patch-*.sha256' \
    -print0)
}

rename_versioned_filenames() {
  local target="$1"
  local current_version="$2"
  [[ -n "$current_version" && "$current_version" != "unknown" ]] || fail "Cannot rename v2.1.5 filenames without a resolved BOB_VERSION."

  while IFS= read -r -d '' f; do
    local dir base newbase newpath
    dir="$(dirname "$f")"
    base="$(basename "$f")"
    newbase="${base//v2.1.5/v${current_version}}"
    [[ "$newbase" != "$base" ]] || continue
    newpath="$dir/$newbase"
    if [[ -e "$newpath" ]]; then
      log "Skipping rename because target already exists: $newpath"
      continue
    fi
    mv "$f" "$newpath"
    log "Renamed ${f#$target/} -> ${newpath#$target/}"
  done < <(find "$target" -depth -type f -name '*v2.1.5*' \
    -not -path '*/.git/*' \
    -not -path '*/.bob/patch-backups/*' \
    -not -path '*/.bob/backups/*' \
    -not -path '*/patches/*' \
    -not -name 'patch-*.sh' \
    -not -name 'patch-*.sha256' \
    -print0)
}

main() {
  local target backup_dir resolved_version
  target="$(resolve_target_root)"
  log "Target root: $target"

  backup_dir="$target/.bob/patch-backups/$PATCH_ID"
  mkdir -p "$backup_dir" "$target/.bob/patches-applied"
  if [[ ! -f "$backup_dir/.snapshot-created" ]]; then
    cp -p "$target"/*.sh "$backup_dir"/ 2>/dev/null || true
    cp -p "$target/.bob/custom_modes.yaml" "$backup_dir"/custom_modes.yaml 2>/dev/null || true
    touch "$backup_dir/.snapshot-created"
  fi

  write_bob_version_script "$target"
  # shellcheck source=/dev/null
  source "$target/bob-version.sh"
  resolved_version="${BOB_VERSION:?BOB_VERSION not resolved}"
  log "Detected Bob version: $resolved_version"

  while IFS= read -r -d '' shfile; do
    insert_source_block "$shfile"
  done < <(find "$target" -maxdepth 1 -type f -name '*.sh' \
    -not -name 'bob-version.sh' \
    -not -name 'patch-*.sh' \
    -print0)

  sanitize_content_versions "$target"
  rename_versioned_filenames "$target" "$resolved_version"

  cat > "$target/.bob/patches-applied/bob-version-Q28.txt" <<MARKER
Patch: bob-version-Q28
Appliance: $APPLIANCE_NAME
Action: Added bob-version.sh, sourced Bob version in root shell scripts, replaced fixed release-string references with dynamic Bob version syntax, and renamed active fixed-version filenames to the resolved Bob version.
Resolved BOB_VERSION: $resolved_version
MARKER

  log "Applied $PATCH_ID successfully."
}

main "$@"
