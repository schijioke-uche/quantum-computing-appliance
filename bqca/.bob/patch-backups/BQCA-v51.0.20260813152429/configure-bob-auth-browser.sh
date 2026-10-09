#!/usr/bin/env bash

#===============================================================================
# @Author: Dr. Jeffrey Chijioke-Uche, IBM Computer Scientist
# @Description:
#   Configures automatic browser opening for IBM Bob authentication on:
#     - Ubuntu running under WSL
#     - Native Ubuntu
#     - macOS
#     - Fedora Linux
#     - CentOS Linux / CentOS Stream
#     - Red Hat Enterprise Linux (RHEL)
#     - SUSE Linux Enterprise Server (SLES)
#     - openSUSE Leap / Tumbleweed
#
# Unsupported operating systems:
#   - No browser, PATH, or proxy configuration is changed.
#   - Only the detected operating-system name is written to the log.
#
# Usage:
#   ./browser-integration.sh
#   ./browser-integration.sh --test
#   ./browser-integration.sh --run bob
#
# From another Bash launcher:
#   source "/path/to/browser-integration.sh"
#===============================================================================

# Apply strict mode only when this file is executed directly.
# Do not alter the caller's shell options when this file is sourced.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -Eeuo pipefail
fi

###############################################################################
# Runtime status
###############################################################################

# These variables are intentionally not exported.
BOB_BROWSER_OS_SUPPORTED=0
BOB_BROWSER_ENVIRONMENT=""

###############################################################################
# Logging
###############################################################################
echo "Please wait..."
browser_log() {
    printf 'OK: %s\n' "$*"
}

browser_warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

browser_fail() {
    printf 'ERROR: %s\n' "$*" >&2
    return 1
}

###############################################################################
# Add a host to NO_PROXY without creating duplicate entries
###############################################################################

add_to_no_proxy() {
    local host="$1"

    case ",${NO_PROXY:-}," in
        *",${host},"*)
            ;;
        *)
            NO_PROXY="${NO_PROXY:+${NO_PROXY},}${host}"
            ;;
    esac
}

###############################################################################
# Add ~/.local/bin to PATH once
###############################################################################

add_local_bin_to_path() {
    case ":${PATH}:" in
        *":${HOME}/.local/bin:"*)
            ;;
        *)
            export PATH="${HOME}/.local/bin:${PATH}"
            ;;
    esac
}

###############################################################################
# Install the WSL-to-Windows browser bridge
###############################################################################

install_wsl_browser_bridge() {
    local local_bin="${HOME}/.local/bin"
    local bridge="${local_bin}/wsl-browser"

    mkdir -p "$local_bin"

    cat > "$bridge" <<'WSL_BROWSER_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

url="${1:-}"

if [[ -z "$url" ]]; then
    printf 'Usage: %s <URL>\n' "${0##*/}" >&2
    exit 64
fi

###############################################################################
# Locate Windows PowerShell
###############################################################################

powershell_path="$(command -v powershell.exe 2>/dev/null || true)"

if [[ -z "$powershell_path" ]]; then
    candidate="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

    if [[ -x "$candidate" ]]; then
        powershell_path="$candidate"
    fi
fi

###############################################################################
# Open the URL with the Windows default browser
#
# Base64 encoding protects OAuth URLs containing &, ?, =, %, :, and callback
# parameters from Bash and PowerShell quoting problems.
###############################################################################

if [[ -n "$powershell_path" ]]; then
    encoded_url="$(
        printf '%s' "$url" |
            base64 |
            tr -d '\r\n'
    )"

    if "$powershell_path" \
        -NoLogo \
        -NoProfile \
        -NonInteractive \
        -Command \
        "\$url=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${encoded_url}')); Start-Process -FilePath \$url" \
        </dev/null \
        >/dev/null 2>&1
    then
        exit 0
    fi
fi

###############################################################################
# Fallback: Windows Explorer URL handler
###############################################################################

explorer_path="$(command -v explorer.exe 2>/dev/null || true)"

if [[ -z "$explorer_path" ]]; then
    candidate="/mnt/c/Windows/explorer.exe"

    if [[ -x "$candidate" ]]; then
        explorer_path="$candidate"
    fi
fi

if [[ -n "$explorer_path" ]]; then
    "$explorer_path" "$url" \
        </dev/null \
        >/dev/null 2>&1

    exit 0
fi

printf '%s\n' \
    "ERROR: Unable to locate powershell.exe or explorer.exe." \
    "Verify that Windows interoperability is enabled in WSL." >&2

exit 127
WSL_BROWSER_EOF

    chmod 755 "$bridge"

    # Some applications honor BROWSER, while others invoke xdg-open directly.
    # These wrappers ensure both mechanisms open the Windows default browser.
    ln -sfn "$bridge" "${local_bin}/xdg-open"
    ln -sfn "$bridge" "${local_bin}/sensible-browser"
    ln -sfn "$bridge" "${local_bin}/x-www-browser"
}

###############################################################################
# Install a portable native-Linux browser bridge
###############################################################################

install_linux_browser_bridge() {
    local local_bin="${HOME}/.local/bin"
    local bridge="${local_bin}/linux-browser"

    mkdir -p "$local_bin"

    cat > "$bridge" <<'LINUX_BROWSER_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

url="${1:-}"

if [[ -z "$url" ]]; then
    printf 'Usage: %s <URL>\n' "${0##*/}" >&2
    exit 64
fi

for browser_command in \
    xdg-open \
    sensible-browser \
    x-www-browser \
    gnome-open \
    kde-open5 \
    kde-open
 do
    if command -v "$browser_command" >/dev/null 2>&1; then
        exec "$browser_command" "$url"
    fi
 done

if command -v gio >/dev/null 2>&1; then
    exec gio open "$url"
fi

printf '%s\n' \
    "ERROR: No supported graphical browser launcher was found." \
    "Install xdg-utils or configure the BROWSER environment variable." >&2

exit 127
LINUX_BROWSER_EOF

    chmod 755 "$bridge"
}

###############################################################################
# Detect the operating system and configure IBM Bob browser authentication
###############################################################################

configure_bob_auth_browser() {
    local kernel_name=""
    local os_id=""
    local os_like=""
    local os_name=""
    local os_pretty_name="Unknown operating system"
    local os_version=""
    local is_wsl="false"
    local is_supported="false"
    local browser_command=""

    # Variables potentially populated by /etc/os-release are local so sourcing
    # the file does not pollute the caller's environment.
    local ID=""
    local ID_LIKE=""
    local NAME=""
    local PRETTY_NAME=""
    local VERSION_ID=""

    kernel_name="$(uname -s 2>/dev/null || printf 'Unknown')"

    ###########################################################################
    # Detect macOS
    ###########################################################################

    if [[ "$kernel_name" == "Darwin" ]]; then
        os_id="macos"
        os_name="macOS"

        if command -v sw_vers >/dev/null 2>&1; then
            os_version="$(sw_vers -productVersion 2>/dev/null || true)"
        fi

        if [[ -n "$os_version" ]]; then
            os_pretty_name="macOS ${os_version}"
        else
            os_pretty_name="macOS"
        fi

        is_supported="true"

    ###########################################################################
    # Detect Linux distribution
    ###########################################################################

    elif [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release

        os_id="$(printf '%s' "${ID:-}" | tr '[:upper:]' '[:lower:]')"
        os_like="$(printf '%s' "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]')"
        os_name="${NAME:-Linux}"
        os_pretty_name="${PRETTY_NAME:-${NAME:-Linux}}"

        case "$os_id" in
            ubuntu)
                is_supported="true"
                ;;
            fedora)
                is_supported="true"
                ;;
            centos)
                is_supported="true"
                ;;
            rhel)
                is_supported="true"
                ;;
            suse|sles|opensuse|opensuse-leap|opensuse-tumbleweed)
                is_supported="true"
                ;;
            *)
                # Recognize compatible family derivatives when their ID_LIKE
                # value identifies one of the explicitly supported families.
                case " ${os_like} " in
                    *" ubuntu "*|*" fedora "*|*" centos "*|*" rhel "*|*" suse "*|*" sles "*|*" opensuse "*)
                        is_supported="true"
                        ;;
                esac
                ;;
        esac
    else
        os_pretty_name="$kernel_name"
    fi

    ###########################################################################
    # Unsupported OS: make no configuration changes
    ###########################################################################

    if [[ "$is_supported" != "true" ]]; then
        browser_log "Detected OS: ${os_pretty_name}"
        return 0
    fi

    BOB_BROWSER_OS_SUPPORTED=1

    ###########################################################################
    # Detect WSL
    ###########################################################################

    if [[ -n "${WSL_INTEROP:-}" ]] ||
       [[ -n "${WSL_DISTRO_NAME:-}" ]] ||
       grep -qiE '(microsoft|wsl)' \
           /proc/sys/kernel/osrelease 2>/dev/null; then
        is_wsl="true"
    fi

    ###########################################################################
    # WSL Linux: use the Windows default browser
    ###########################################################################

    if [[ "$is_wsl" == "true" ]]; then
        install_wsl_browser_bridge
        add_local_bin_to_path

        browser_command="${HOME}/.local/bin/wsl-browser"

        if [[ ! -x "$browser_command" ]]; then
            browser_fail "The WSL browser bridge could not be installed at ${browser_command}."
            return 1
        fi

        export BROWSER="$browser_command"
        BOB_BROWSER_ENVIRONMENT="WSL ${os_name:-Linux}"

    ###########################################################################
    # macOS: use the native open command
    ###########################################################################

    elif [[ "$os_id" == "macos" ]]; then
        if [[ ! -x /usr/bin/open ]]; then
            browser_fail "macOS was detected, but /usr/bin/open is unavailable."
            return 1
        fi

        export BROWSER="/usr/bin/open"
        BOB_BROWSER_ENVIRONMENT="macOS"

    ###########################################################################
    # Supported native Linux: use a portable Linux browser bridge
    ###########################################################################

    else
        install_linux_browser_bridge
        add_local_bin_to_path

        browser_command="${HOME}/.local/bin/linux-browser"

        if [[ ! -x "$browser_command" ]]; then
            browser_fail "The Linux browser bridge could not be installed at ${browser_command}."
            return 1
        fi

        export BROWSER="$browser_command"
        BOB_BROWSER_ENVIRONMENT="${os_pretty_name}"
    fi

    ###########################################################################
    # Keep IBM Bob's localhost authentication callback outside HTTP proxies
    ###########################################################################

    add_to_no_proxy "localhost"
    add_to_no_proxy "127.0.0.1"
    add_to_no_proxy "::1"

    export NO_PROXY
    export no_proxy="$NO_PROXY"

    browser_log "Detected environment: ${BOB_BROWSER_ENVIRONMENT}"
    browser_log "Configured browser: ${BROWSER}"
    browser_log "Configured localhost proxy bypass"
}

###############################################################################
# Configure browser integration
###############################################################################

configure_bob_auth_browser

###############################################################################
# Direct-execution options
###############################################################################

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${1:-}" in
        --test)
            # Unsupported operating systems intentionally do nothing beyond
            # the single detected-OS log message emitted above.
            if [[ "$BOB_BROWSER_OS_SUPPORTED" -ne 1 ]]; then
                exit 0
            fi

            if [[ -z "${BROWSER:-}" ]]; then
                browser_fail "No browser command was configured."
                exit 1
            fi

            browser_log "Opening the IBM Bob login page for testing"
            "$BROWSER" "https://bob.ibm.com/login"
            ;;

        --run)
            shift

            if (($# == 0)); then
                printf 'Usage: %s --run <command> [arguments...]\n' \
                    "${0##*/}" >&2
                exit 64
            fi

            exec "$@"
            ;;

        "")
            # Configuration and logging have already completed.
            ;;

        *)
            printf 'Unknown option: %s\n' "$1" >&2
            printf 'Usage: %s [--test | --run <command>]\n' \
                "${0##*/}" >&2
            exit 64
            ;;
    esac
fi
