#!/usr/bin/env bash
# Install (or remove) the `pcbstitch` command so it can be run from any directory.
#
#   ./install.sh              link pcbstitch into uv's bin directory (usually ~/.local/bin)
#                             and make sure that directory is on your PATH
#   ./install.sh --uninstall  remove the link
#
# The link points at this checkout, so `git pull` here updates the command.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
script="$repo/pcbstitch"

if ! command -v uv >/dev/null 2>&1; then
    echo "uv is not installed. Install it first:"
    echo "  Arch / CachyOS:  sudo pacman -S uv"
    echo "  other Linux:     curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "then open a new terminal and run ./install.sh again."
    exit 1
fi

bindir="$(uv tool dir --bin)"
bindir="$(mkdir -p "$bindir" && cd "$bindir" && pwd -P)"
target="$bindir/pcbstitch"
marker="# added by pcbstitch install.sh"
fishconf="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/pcbstitch.fish"
zshrc="${ZDOTDIR:-$HOME}/.zshrc"

# shell startup files that should put $bindir on PATH
rc_files() {
    echo "$HOME/.bashrc"
    # bash login shells read only the first of these that exists
    local f login=""
    for f in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
        [[ -e "$f" ]] && { login="$f"; break; }
    done
    echo "${login:-$HOME/.profile}"
    if command -v zsh >/dev/null 2>&1 || [[ -e "$zshrc" ]]; then echo "$zshrc"; fi
}

if [[ "${1:-}" == "--uninstall" ]]; then
    if [[ -L "$target" && "$(readlink -f "$target")" == "$script" ]]; then
        rm "$target"; echo "removed $target"
    else
        echo "nothing to remove ($target is not a link to this checkout)"
    fi
    for f in $(rc_files); do
        if [[ -f "$f" ]] && grep -qF "$marker" "$f"; then
            sed -i "/$marker/d" "$f"; echo "removed PATH line from $f"
        fi
    done
    [[ -f "$fishconf" ]] && rm "$fishconf" && echo "removed $fishconf"
    exit 0
fi

chmod +x "$script"
if [[ -e "$target" && ! -L "$target" ]]; then
    echo "error: $target exists and is not a link; move it away and run again" >&2
    exit 1
fi
ln -sfn "$script" "$target"
echo "linked $target -> $script"

# make sure the bin directory is on PATH for future shells (bash, zsh, fish)
case ":$PATH:" in
    *":$bindir:"*) on_path=1 ;;
    *) on_path=0 ;;
esac
if [[ $on_path == 0 ]]; then
    line="case \":\$PATH:\" in *\":$bindir:\"*) ;; *) export PATH=\"$bindir:\$PATH\" ;; esac  $marker"
    for f in $(rc_files); do
        if ! { [[ -f "$f" ]] && grep -qF "$marker" "$f"; }; then
            mkdir -p "$(dirname "$f")"; echo "$line" >> "$f"; echo "added $bindir to PATH in $f"
        fi
    done
    if command -v fish >/dev/null 2>&1 && [[ ! -f "$fishconf" ]]; then
        mkdir -p "$(dirname "$fishconf")"
        echo "fish_add_path --path $bindir  $marker" > "$fishconf"
        echo "added $bindir to PATH in $fishconf"
    fi
fi

missing=()
for t in pto_gen cpfind cpclean pto_var autooptimiser vig_optimize pano_modify nona pano_trafo checkpto enblend rawtherapee-cli; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
done
if (( ${#missing[@]} )); then
    echo
    echo "warning: these tools are not installed yet: ${missing[*]}"
    echo "  Arch / CachyOS:  sudo pacman -S hugin enblend-enfuse rawtherapee"
    echo "  Ubuntu / Debian: sudo apt install hugin-tools enblend rawtherapee"
fi

echo
if [[ $on_path == 1 ]]; then
    echo "done. Run: pcbstitch --help"
else
    echo "done. Open a NEW terminal, then run: pcbstitch --help"
fi
