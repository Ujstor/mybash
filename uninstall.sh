#!/bin/sh
# mybash uninstaller. Mirrors setup.sh: removes only what setup.sh installs,
# restores the .bashrc backup it made, and never needs a display.
#
#   ./uninstall.sh              remove configs + starship/fzf/zoxide
#   ./uninstall.sh --packages   also remove the distro packages
#   ./uninstall.sh --font       also remove the opt-in Nerd Font

set -eu

RC=''
RED=''
YELLOW=''
GREEN=''
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ]; then
	RC=$(tput sgr0 2>/dev/null || printf '')
	RED=$(tput setaf 1 2>/dev/null || printf '')
	YELLOW=$(tput setaf 3 2>/dev/null || printf '')
	GREEN=$(tput setaf 2 2>/dev/null || printf '')
fi

LINUXTOOLBOXDIR="$HOME/linuxtoolbox"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mybash"
# Written by setup.sh: one "<replaced path><TAB><its backup>" line per backup.
STATE_FILE="$STATE_DIR/backups"
# The checkout the links point into: the one setup.sh recorded, else this
# script's own directory when it is a checkout, else where `curl | sh` clones.
REPO_PATH=$(cat "$STATE_DIR/checkout" 2>/dev/null || printf '')
if [ -z "$REPO_PATH" ]; then
	case "$0" in
	uninstall.sh | */uninstall.sh)
		here=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || printf '')
		[ -n "$here" ] && [ -f "$here/setup.sh" ] && [ -f "$here/.bashrc" ] && REPO_PATH="$here"
		;;
	esac
fi
REPO_PATH="${REPO_PATH:-$LINUXTOOLBOXDIR/mybash}"
PACKAGER=""
SUDO_CMD=""
REMOVE_PACKAGES=0
REMOVE_FONT=0

for arg in "$@"; do
	case "$arg" in
	--packages) REMOVE_PACKAGES=1 ;;
	--font) REMOVE_FONT=1 ;;
	-h | --help)
		sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		printf 'Unknown option: %s\n' "$arg" >&2
		exit 1
		;;
	esac
done

print_colored() { printf "%s%s%s\n" "$1" "$2" "$RC"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

determine_package_manager() {
	for pgm in nala apt-get dnf yum pacman zypper emerge xbps-install nix-env; do
		if command_exists "$pgm"; then
			PACKAGER="$pgm"
			break
		fi
	done
}

determine_sudo_command() {
	if [ "$(id -u)" -eq 0 ]; then
		SUDO_CMD=""
	elif command_exists sudo; then
		SUDO_CMD="sudo"
	elif command_exists doas && [ -f /etc/doas.conf ]; then
		SUDO_CMD="doas"
	fi
}

uninstall_dependencies() {
	[ "$REMOVE_PACKAGES" = "1" ] || {
		print_colored "$YELLOW" "Leaving distro packages installed (--packages to remove)"
		return 0
	}
	[ -n "$PACKAGER" ] || {
		print_colored "$RED" "No supported package manager found"
		return 0
	}

	DEPENDENCIES='bash-completion bat tree multitail trash-cli'
	print_colored "$YELLOW" "Removing: $DEPENDENCIES"
	# DEPENDENCIES is a package LIST and every branch below wants it split into
	# separate arguments, so the unquoted expansion is the point rather than an
	# oversight. The directive sits in front of the whole case because shellcheck
	# only accepts one before a complete command, not before a case branch
	# (SC1124).
	# shellcheck disable=SC2086
	case "$PACKAGER" in
	nala | apt-get) ${SUDO_CMD} "$PACKAGER" purge -y ${DEPENDENCIES} || true ;;
	dnf | yum) ${SUDO_CMD} "$PACKAGER" remove -y ${DEPENDENCIES} || true ;;
	zypper) ${SUDO_CMD} zypper --non-interactive remove ${DEPENDENCIES} || true ;;
	pacman) ${SUDO_CMD} pacman -Rns --noconfirm ${DEPENDENCIES} || true ;;
	xbps-install) ${SUDO_CMD} xbps-remove -Ry ${DEPENDENCIES} || true ;;
	emerge) ${SUDO_CMD} emerge --deselect app-shells/bash-completion sys-apps/bat app-text/tree app-text/multitail app-misc/trash-cli || true ;;
	nix-env) nix-env -e bash-completion bat tree multitail trash-cli || true ;;
	esac
}

uninstall_font() {
	[ "$REMOVE_FONT" = "1" ] || return 0
	FONT_DIR="$HOME/.local/share/fonts/MesloLGS Nerd Font Mono"
	if [ -d "$FONT_DIR" ]; then
		rm -rf "$FONT_DIR"
		command_exists fc-cache && fc-cache -f >/dev/null || true
		print_colored "$GREEN" "Font removed"
	else
		print_colored "$YELLOW" "Font not installed"
	fi
}

uninstall_starship_fzf_zoxide() {
	# Only the copies setup.sh installs, in ~/.local/bin. `command -v` found
	# whichever came first on PATH — /usr/bin/zoxide from apt (leaving dpkg with a
	# package whose binary is gone), or another installer's /usr/local/bin copy.
	for bin in starship zoxide; do
		path="$HOME/.local/bin/$bin"
		if [ -f "$path" ]; then
			rm -f "$path"
			print_colored "$GREEN" "$bin removed"
		fi
	done

	if [ -d "$HOME/.fzf" ]; then
		if [ -x "$HOME/.fzf/uninstall" ]; then
			"$HOME/.fzf/uninstall" >/dev/null 2>&1 || true
		fi
		rm -rf "$HOME/.fzf" "$HOME/.fzf.bash"
		print_colored "$GREEN" "fzf removed"
	fi
}

# backup_of DST — the backup setup.sh made when it replaced DST: the last one it
# recorded, else (an install from before the record existed) the newest
# timestamped DST.bak.*, else DST.bak. Prints nothing when there is none.
backup_of() {
	b=''
	if [ -f "$STATE_FILE" ]; then
		b=$(awk -F '\t' -v d="$1" '$1 == d { b = $2 } END { print b }' "$STATE_FILE")
	fi
	if [ -z "$b" ]; then
		for c in "$1".bak.[0-9]*; do
			[ -e "$c" ] || [ -L "$c" ] || continue
			b="$c"
		done
	fi
	if [ -z "$b" ] && { [ -e "$1.bak" ] || [ -L "$1.bak" ]; }; then
		b="$1.bak"
	fi
	if [ -n "$b" ] && { [ -e "$b" ] || [ -L "$b" ]; }; then
		printf '%s' "$b"
	fi
}

# unlink_config DST — remove DST only if it is a symlink into the mybash
# checkout, then put back what setup.sh replaced. A real file, or a link to
# anything else, is yours: it is left alone.
unlink_config() {
	dst="$1"
	[ -L "$dst" ] || return 0
	target=$(readlink -f "$dst" 2>/dev/null || printf '')
	case "$target" in
	"$REPO_REAL"/*) ;;
	*)
		print_colored "$YELLOW" "Leaving $dst: it does not point into $REPO_PATH"
		return 0
		;;
	esac
	rm -f "$dst"
	bak=$(backup_of "$dst")
	if [ -n "$bak" ]; then
		mv "$bak" "$dst"
		print_colored "$GREEN" "Restored $dst from $bak"
	elif [ "$dst" = "$HOME/.bashrc" ] && [ -f /etc/skel/.bashrc ]; then
		cp /etc/skel/.bashrc "$dst"
		print_colored "$GREEN" "Restored .bashrc from /etc/skel"
	fi
}

remove_configs() {
	print_colored "$YELLOW" "Removing configuration files"
	REPO_REAL=$(readlink -f "$REPO_PATH" 2>/dev/null || printf '%s' "$REPO_PATH")

	unlink_config "$HOME/.bashrc"
	unlink_config "$HOME/.config/starship.toml"
	unlink_config "$HOME/.config/fastfetch/config.jsonc"

	# The ~/.bash_profile setup.sh writes, and only when it is byte-for-byte that.
	for generated in '[ -f ~/.bashrc ] && . ~/.bashrc' \
		"$(printf '%s\n%s' '[ -f ~/.profile ] && . ~/.profile' '[ -f ~/.bashrc ] && . ~/.bashrc')"; do
		if [ -f "$HOME/.bash_profile" ] && [ "$(cat "$HOME/.bash_profile")" = "$generated" ]; then
			rm -f "$HOME/.bash_profile"
			print_colored "$GREEN" "Removed the .bash_profile setup.sh wrote"
		fi
	done
	rm -f "$STATE_FILE" "$STATE_DIR/checkout"
	rmdir "$STATE_DIR" 2>/dev/null || true

	print_colored "$GREEN" "Configuration files removed"
}

remove_linuxtoolbox() {
	if [ -d "$LINUXTOOLBOXDIR/mybash" ]; then
		rm -rf "$LINUXTOOLBOXDIR/mybash"
		rmdir "$LINUXTOOLBOXDIR" 2>/dev/null || true
		print_colored "$GREEN" "linuxtoolbox checkout removed"
	fi
}

determine_package_manager
determine_sudo_command
uninstall_dependencies
uninstall_font
uninstall_starship_fzf_zoxide
remove_configs
remove_linuxtoolbox

print_colored "$GREEN" "Uninstall complete. Restart your shell."
