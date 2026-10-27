#!/usr/bin/env bash
# One-step setup for pcbstitch: installs everything it needs and the `pcbstitch` command.
#
#   curl -fsSL https://raw.githubusercontent.com/kage-engineering/pcbstitch/main/setup.sh | bash
#
# What it does:
#   1. installs missing tools with your package manager (asks for your password once):
#      git, curl, Hugin, enblend, RawTherapee, uv
#   2. downloads pcbstitch into ~/pcbstitch (or updates it if it is already there)
#   3. runs ./install.sh so `pcbstitch` works from any folder
#   4. does a test run
#
# Set PCBSTITCH_DIR to install somewhere other than ~/pcbstitch.
# Supported: Arch / CachyOS / Manjaro, Ubuntu / Debian / Mint, Fedora, openSUSE.

# everything is inside main() so a partially downloaded script never runs
main() {
set -euo pipefail

REPO_URL="https://github.com/kage-engineering/pcbstitch.git"
DEST="${PCBSTITCH_DIR:-$HOME/pcbstitch}"
NEEDED_TOOLS=(git curl pto_gen cpfind cpclean pto_var autooptimiser vig_optimize pano_modify nona
              pano_trafo checkpto enblend rawtherapee-cli)

if [[ "${LANG:-}${LC_ALL:-}${LC_MESSAGES:-}" == *ja* ]]; then JA=1; else JA=0; fi
say()  { if [[ $JA == 1 ]]; then echo "$2"; else echo "$1"; fi; }
step() { echo; if [[ $JA == 1 ]]; then echo "==> $2"; else echo "==> $1"; fi; }
fail() { echo; if [[ $JA == 1 ]]; then echo "エラー: $2" >&2; else echo "Error: $1" >&2; fi; exit 1; }

if [[ $EUID == 0 ]]; then
    fail "run this as your normal user, not as root (it will ask for your password when needed)." \
         "root ではなく普段のユーザーで実行してください(必要なときにパスワードを聞きます)。"
fi
[[ "$(uname -s)" == Linux ]] || fail "this setup script is for Linux." "このセットアップは Linux 用です。"

say "pcbstitch setup" "pcbstitch セットアップ"

# --------------------------------------------------------------------------- 1. system tools
step "Checking required tools" "必要なツールを確認しています"
missing=()
for t in "${NEEDED_TOOLS[@]}"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done

if (( ${#missing[@]} )); then
    say "Missing: ${missing[*]}" "不足しているもの: ${missing[*]}"
    . /etc/os-release 2>/dev/null || true
    family=" ${ID:-} ${ID_LIKE:-} "
    if   [[ $family == *" arch "* ]] || command -v pacman >/dev/null 2>&1; then
        cmd=(sudo pacman -S --needed --noconfirm git curl hugin enblend-enfuse rawtherapee)
    elif [[ $family == *" debian "* || $family == *" ubuntu "* ]] || command -v apt-get >/dev/null 2>&1; then
        cmd=(bash -c "sudo apt-get update && sudo apt-get install -y git curl hugin-tools enblend rawtherapee")
    elif [[ $family == *" fedora "* ]] || command -v dnf >/dev/null 2>&1; then
        cmd=(sudo dnf install -y git curl hugin-base enblend rawtherapee)
    elif [[ $family == *suse* ]] || command -v zypper >/dev/null 2>&1; then
        cmd=(sudo zypper --non-interactive install git curl hugin enblend-enfuse rawtherapee)
    else
        fail "unknown Linux distribution. Please install these yourself, then run this again: git curl hugin enblend rawtherapee" \
             "対応していない Linux ディストリビューションです。git curl hugin enblend rawtherapee を手動でインストールしてから、もう一度実行してください。"
    fi
    say "Installing them now. Your password may be asked (it is not shown while you type)." \
        "これからインストールします。パスワードを聞かれることがあります(入力中は表示されません)。"
    echo "  ${cmd[*]}"
    "${cmd[@]}" </dev/tty || fail "installing the tools failed (see the messages above)." \
                                  "ツールのインストールに失敗しました(上のメッセージを確認してください)。"
    still=()
    for t in "${NEEDED_TOOLS[@]}"; do command -v "$t" >/dev/null 2>&1 || still+=("$t"); done
    (( ${#still[@]} == 0 )) || fail "still missing after installing: ${still[*]}" \
                                    "インストール後も見つかりません: ${still[*]}"
else
    say "All tools are installed." "必要なツールはすべてインストール済みです。"
fi

# --------------------------------------------------------------------------- uv
if ! command -v uv >/dev/null 2>&1; then
    step "Installing uv" "uv をインストールしています"
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm uv </dev/tty
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    command -v uv >/dev/null 2>&1 || fail "uv was not installed." "uv をインストールできませんでした。"
fi

# --------------------------------------------------------------------------- 2. download / update
if [[ -d "$DEST/.git" ]]; then
    step "Updating pcbstitch in $DEST" "$DEST の pcbstitch を更新しています"
    git -C "$DEST" pull --ff-only || fail "could not update $DEST (were files in it changed?)." \
                                         "$DEST を更新できませんでした(中のファイルを変更していませんか?)。"
elif [[ -e "$DEST" ]]; then
    fail "$DEST already exists and is not a pcbstitch download. Move it away or set PCBSTITCH_DIR." \
         "$DEST が既に存在しますが、pcbstitch ではありません。移動するか PCBSTITCH_DIR を指定してください。"
else
    step "Downloading pcbstitch to $DEST" "pcbstitch を $DEST にダウンロードしています"
    git clone --quiet "$REPO_URL" "$DEST"
fi

# --------------------------------------------------------------------------- 3. command
step "Installing the pcbstitch command" "pcbstitch コマンドをインストールしています"
bash "$DEST/install.sh"

# --------------------------------------------------------------------------- 4. test run
step "Test run (the first time downloads a few Python packages)" "テスト実行(初回は Python パッケージをダウンロードします)"
if "$DEST/pcbstitch" --help >/dev/null 2>&1; then
    say "pcbstitch works." "pcbstitch は正常に動作しています。"
else
    fail "the test run failed. Run '$DEST/pcbstitch --help' to see why." \
         "テスト実行に失敗しました。'$DEST/pcbstitch --help' を実行して原因を確認してください。"
fi

echo
say "All done! Close this terminal and open a new one, then try:" \
    "完了しました!このターミナルを閉じて新しいターミナルを開き、次を試してください:"
echo "    pcbstitch --help"
say "Guide: $DEST/QUICKSTART.md" "使い方: $DEST/QUICKSTART.ja.md"
}

main "$@"
