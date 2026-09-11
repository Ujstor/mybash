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
	for bin in starship zoxide; do
		path=$(command -v "$bin" 2>/dev/null || printf '')
		if [ -n "$path" ]; then
			if [ -w "$path" ]; then
				rm -f "$path"
			else
				${SUDO_CMD} rm -f "$path"
			fi
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

remove_configs() {
	print_colored "$YELLOW" "Removing configuration files"

	if [ -L "$HOME/.bashrc" ]; then
		rm -f "$HOME/.bashrc"
		if [ -f "$HOME/.bashrc.bak" ]; then
			mv "$HOME/.bashrc.bak" "$HOME/.bashrc"
			print_colored "$GREEN" "Restored original .bashrc"
		elif [ -f /etc/skel/.bashrc ]; then
			cp /etc/skel/.bashrc "$HOME/.bashrc"
			print_colored "$GREEN" "Restored .bashrc from /etc/skel"
		fi
	fi

	rm -f "$HOME/.config/starship.toml" "$HOME/.config/fastfetch/config.jsonc"

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
