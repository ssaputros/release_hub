#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." &> /dev/null && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
DRY_RUN=false
SPAWN_TERMINAL=false
APPLE_ID_ARG=""

show_help() {
    echo "Usage: scripts/login_fastlane.sh [--apple-id email] [--spawn-terminal] [--dry-run]"
    echo ""
    echo "Login/refresh session Fastlane untuk App Store Connect tanpa memilih project."
    echo "Gunakan --spawn-terminal untuk membuka Terminal macOS foreground agar prompt password/2FA dan Keychain bisa muncul."
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run|--no-execute)
            DRY_RUN=true
            ;;
        --spawn-terminal|--terminal|--open-terminal)
            SPAWN_TERMINAL=true
            ;;
        -u|--username|--apple-id)
            if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
                echo "❌ Option $1 wajib memiliki nilai Apple ID."
                exit 1
            fi
            APPLE_ID_ARG="$2"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Parameter tidak dikenal: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

APPLE_ID="${APPLE_ID_ARG:-${APPLE_ID_USERNAME:-${FASTLANE_USER:-}}}"
COOKIE_DIR="${HOME}/.fastlane/spaceship/${APPLE_ID:-<apple-id>}"

print_summary() {
    echo "============================================================"
    echo "🔐 LOGIN FASTLANE / APP STORE CONNECT"
    echo "============================================================"
    echo "Apple ID      : ${APPLE_ID:-[akan diminta di Terminal]}"
    if [ -n "${TEAM_ID:-}" ]; then
        echo "Team ID       : [SET]"
    else
        echo "Team ID       : [empty]"
    fi
    if [ -n "${ITC_TEAM_ID:-}" ]; then
        echo "ITC Team ID   : [SET]"
    else
        echo "ITC Team ID   : [empty]"
    fi
    echo "Session cache : ${COOKIE_DIR}/cookie"
    echo "------------------------------------------------------------"
    echo "Catatan:"
    echo "- Masukkan password/2FA langsung di Terminal. Jangan kirim password/session ke chat."
    echo "- Jika fastlane menampilkan FASTLANE_SESSION, jangan share nilainya."
    echo "============================================================"
}

spawn_terminal_login() {
    local project_root_q apple_id_q terminal_command

    if ! command -v osascript >/dev/null 2>&1; then
        echo "❌ osascript tidak ditemukan. Jalankan langsung dari Terminal macOS:"
        echo "   cd '$PROJECT_ROOT' && bash scripts/login_fastlane.sh"
        exit 1
    fi

    printf -v project_root_q '%q' "$PROJECT_ROOT"
    terminal_command="cd ${project_root_q} && clear && bash scripts/login_fastlane.sh"

    if [ -n "$APPLE_ID" ]; then
        printf -v apple_id_q '%q' "$APPLE_ID"
        terminal_command+=" --apple-id ${apple_id_q}"
    fi

    terminal_command+="; status=\$?; echo; if [ \$status -eq 0 ]; then echo '✅ Login Fastlane selesai.'; else echo '❌ Login Fastlane gagal atau dibatalkan.'; fi; echo; read -r -p 'Tekan Enter untuk menutup window ini...' _"

    print_summary

    if [ "$DRY_RUN" = true ]; then
        echo "🧪 Dry-run: akan membuka Terminal foreground dengan command:"
        printf '%s\n' "$terminal_command"
        exit 0
    fi

    osascript \
        -e 'on run argv' \
        -e 'set loginCommand to item 1 of argv' \
        -e 'tell application "Terminal"' \
        -e 'activate' \
        -e 'do script loginCommand' \
        -e 'delay 0.2' \
        -e 'activate' \
        -e 'end tell' \
        -e 'end run' \
        "$terminal_command"

    echo "✅ Terminal Fastlane login dibuka di foreground."
    echo "   Selesaikan password/2FA di window Terminal yang muncul."
    exit 0
}

if [ "$SPAWN_TERMINAL" = true ]; then
    spawn_terminal_login
fi

if [ -z "$APPLE_ID" ]; then
    if [ -t 0 ]; then
        read -r -p "Masukkan Apple ID username/email: " APPLE_ID
    else
        echo "❌ Apple ID belum tersedia. Isi APPLE_ID_USERNAME di .env atau jalankan dengan --apple-id <email>."
        exit 1
    fi
fi

if ! command -v fastlane >/dev/null 2>&1; then
    echo "❌ Command 'fastlane' tidak ditemukan. Install/aktifkan fastlane terlebih dahulu."
    exit 1
fi

export FASTLANE_USER="$APPLE_ID"
if [ -n "${TEAM_ID:-}" ]; then
    export FASTLANE_TEAM_ID="$TEAM_ID"
fi
if [ -n "${ITC_TEAM_ID:-}" ]; then
    export FASTLANE_ITC_TEAM_ID="$ITC_TEAM_ID"
fi

COOKIE_DIR="$HOME/.fastlane/spaceship/${APPLE_ID}"
print_summary

if [ "$DRY_RUN" = true ]; then
    echo "🧪 Dry-run: command yang akan dijalankan:"
    printf 'fastlane spaceauth -u %q\n' "$APPLE_ID"
    exit 0
fi

fastlane spaceauth -u "$APPLE_ID"

cat <<'MSG'
============================================================
✅ Proses login Fastlane selesai.
Jika berhasil, session/cookie Fastlane sudah direfresh.
Setelah ini retry action App Store di release_hub:
  - action 8  = Create Appstore
  - action 9  = Push Metadata (App Store)
============================================================
MSG
