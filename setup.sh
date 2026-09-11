#!/bin/sh
# mybash installer — headless-safe, idempotent.
#
#   * installs no X server, no desktop, no GUI toolkit
#   * installs no font by default (a Nerd Font must live on the machine
#     running the TERMINAL EMULATOR, not on the server you ssh into).
#     Opt in on a workstation with:  ./setup.sh --with-font
#   * safe to re-run: updates an existing checkout instead of deleting it,
#     never overwrites an existing backup, never prompts
#
# Usage:
#   ./setup.sh                 install / update
#   ./setup.sh --with-font     also install the MesloLGS Nerd Font (desktop only)
#   MYBASH_INSTALL_FONT=1 ./setup.sh    same, via environment

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
REPO_URL="https://github.com/Ujstor/mybash"
REPO_PATH=""
PACKAGER=""
SUDO_CMD=""
INSTALL_FONT="${MYBASH_INSTALL_FONT:-0}"

for arg in "$@"; do
	case "$arg" in
	--with-font) INSTALL_FONT=1 ;;
	-h | --help)
		sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
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

#######################################################
# Environment
#######################################################

detect_privilege_escalation() {
	if [ "$(id -u)" -eq 0 ]; then
		SUDO_CMD=""
		printf "Running as root, no privilege escalation needed\n"
		return 0
	fi
	if command_exists sudo; then
		SUDO_CMD="sudo"
	elif command_exists doas && [ -f /etc/doas.conf ]; then
		SUDO_CMD="doas"
	else
		print_colored "$RED" "Need root, sudo or doas to install packages."
		exit 1
	fi
	printf "Using %s for privilege escalation\n" "$SUDO_CMD"
}

check_environment() {
	for req in curl git; do
		if ! command_exists "$req"; then
			print_colored "$RED" "Missing required command: $req"
			exit 1
		fi
	done

	for pgm in nala apt-get dnf yum pacman zypper emerge xbps-install nix-env; do
		if command_exists "$pgm"; then
			PACKAGER="$pgm"
			printf "Using %s\n" "$pgm"
			break
		fi
	done

	if [ -z "$PACKAGER" ]; then
		print_colored "$RED" "Can't find a supported package manager"
		exit 1
	fi

	detect_privilege_escalation
}

#######################################################
# Repository — update in place, never rm -rf
#######################################################

setup_repo() {
	script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || printf '')

	# Run from inside a checkout (git clone + ./setup.sh): use it as-is.
	if [ -n "$script_dir" ] && [ -f "$script_dir/.bashrc" ] && [ -d "$script_dir/.git" ]; then
		REPO_PATH="$script_dir"
		print_colored "$GREEN" "Using existing checkout: $REPO_PATH"
		return 0
	fi

	# Run via `curl | sh`: clone or update under linuxtoolbox.
	REPO_PATH="$LINUXTOOLBOXDIR/mybash"
	mkdir -p "$LINUXTOOLBOXDIR"

	if [ -d "$REPO_PATH/.git" ]; then
		print_colored "$YELLOW" "Updating existing checkout: $REPO_PATH"
		git -C "$REPO_PATH" fetch --quiet origin
		git -C "$REPO_PATH" pull --quiet --ff-only || \
			print_colored "$YELLOW" "Could not fast-forward, keeping local state"
	else
		print_colored "$YELLOW" "Cloning into: $REPO_PATH"
		git clone --quiet "$REPO_URL" "$REPO_PATH"
	fi
	print_colored "$GREEN" "Repository ready: $REPO_PATH"
}

#######################################################
# Packages — CLI only, nothing that needs a display
#######################################################

pkg_install() {
	# Best effort: a package missing from this distro's repos must not
	# abort the whole install.
	case "$PACKAGER" in
	nala | apt-get)
		# --no-install-recommends is load-bearing on a headless box. Without it
		# `neovim` Recommends "xclip | xsel | wl-clipboard" and apt pulls xclip,
		# which drags in libx11-6, libxcb1, x11-common, libice6, libsm6, libxmu6
		# and libxt6t64 — 8 X11 packages onto a server with no display, and it
		# contradicts this script's own promise not to install x11/xorg.
		DEBIAN_FRONTEND=noninteractive ${SUDO_CMD} "$PACKAGER" install -y --no-install-recommends "$@" || return 1
		;;
	dnf | yum)
		${SUDO_CMD} "$PACKAGER" install -y "$@" || return 1
		;;
	zypper)
		${SUDO_CMD} zypper --non-interactive install "$@" || return 1
		;;
	pacman)
		${SUDO_CMD} pacman -S --needed --noconfirm "$@" || return 1
		;;
	xbps-install)
		${SUDO_CMD} xbps-install -y "$@" || return 1
		;;
	emerge)
		${SUDO_CMD} emerge -v "$@" || return 1
		;;
	nix-env)
		nix-env -iA "$@" || return 1
		;;
	esac
}

install_dependencies() {
	# bash-completion : shell completion
	# tar / unzip     : archives (extract())
	# bat             : cat replacement
	# tree            : directory tree
	# multitail       : the `logs` alias
	# wget            : fastfetch .deb download
	# trash-cli       : rm -> trash
	# fzf             : fuzzy finder
	# eza             : ls replacement (may be absent on older Debian/Ubuntu)
	#
	# NOT installed: fontconfig, any x11/xorg package, any desktop font.
	case "$PACKAGER" in
	emerge)
		DEPENDENCIES='app-shells/bash-completion app-arch/tar app-arch/unzip sys-apps/bat app-text/tree app-text/multitail net-misc/wget app-misc/trash-cli app-shells/fzf sys-apps/eza'
		;;
	nix-env)
		DEPENDENCIES='nixos.bash-completion nixos.gnutar nixos.unzip nixos.bat nixos.tree nixos.multitail nixos.wget nixos.trash-cli nixos.fzf nixos.eza'
		;;
	*)
		DEPENDENCIES='bash-completion tar unzip bat tree multitail wget trash-cli fzf'
		;;
	esac

	print_colored "$YELLOW" "Installing: $DEPENDENCIES"
	# shellcheck disable=SC2086
	pkg_install $DEPENDENCIES || \
		print_colored "$YELLOW" "Some packages failed; retrying individually"

	# eza is not in the repos of older Debian/Ubuntu. Try it on its own so a
	# failure does not take the rest down; .bashrc falls back to plain ls.
	case "$PACKAGER" in
	emerge | nix-env) ;;
	*)
		if ! command_exists eza; then
			pkg_install eza >/dev/null 2>&1 || \
				print_colored "$YELLOW" "eza not available from $PACKAGER — .bashrc will use plain ls"
		fi
		;;
	esac

	if ! command_exists nvim; then
		pkg_install neovim || print_colored "$YELLOW" "neovim not installed"
	fi

	install_fastfetch
}

install_fastfetch() {
	if command_exists fastfetch; then
		printf "fastfetch already installed\n"
		return 0
	fi

	case "$PACKAGER" in
	nala | apt-get) ;;
	*)
		pkg_install fastfetch || print_colored "$YELLOW" "fastfetch not installed"
		return 0
		;;
	esac

	# Debian/Ubuntu: not in the repos before 24.10, take the release .deb.
	arch=$(uname -m)
	case "$arch" in
	x86_64) deb_arch="amd64" ;;
	aarch64) deb_arch="arm64" ;;
	armv7l) deb_arch="armhf" ;;
	i686) deb_arch="i386" ;;
	*)
		print_colored "$YELLOW" "No fastfetch build for $arch, skipping"
		return 0
		;;
	esac

	url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${deb_arch}.deb"
	tmp_deb=$(mktemp -t fastfetch.XXXXXX.deb)
	if curl -fsSL "$url" -o "$tmp_deb" && ${SUDO_CMD} dpkg -i "$tmp_deb" >/dev/null 2>&1; then
		print_colored "$GREEN" "fastfetch installed"
	else
		${SUDO_CMD} apt-get install -f -y >/dev/null 2>&1 || true
		command_exists fastfetch || print_colored "$YELLOW" "fastfetch not installed"
	fi
	rm -f "$tmp_deb"
}

install_starship() {
	if command_exists starship; then
		printf "starship already installed\n"
		return 0
	fi
	print_colored "$YELLOW" "Installing starship"
	# -y: never prompt. Installs into ~/.local/bin so no root is needed.
	mkdir -p "$HOME/.local/bin"
	if ! curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"; then
		print_colored "$RED" "starship install failed"
		return 1
	fi
}

install_fzf() {
	if command_exists fzf; then
		printf "fzf already installed\n"
		return 0
	fi
	if [ ! -d "$HOME/.fzf" ]; then
		git clone --quiet --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
	fi
	# Non-interactive: .bashrc sources ~/.fzf.bash itself, so --no-update-rc.
	"$HOME/.fzf/install" --key-bindings --completion --no-update-rc >/dev/null || return 1
}

install_zoxide() {
	if command_exists zoxide; then
		printf "zoxide already installed\n"
		return 0
	fi
	print_colored "$YELLOW" "Installing zoxide"
	if ! curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
		print_colored "$RED" "zoxide install failed"
		return 1
	fi
}

#######################################################
# Optional: Nerd Font (workstations only)
#######################################################

install_font() {
	if [ "$INSTALL_FONT" != "1" ]; then
		print_colored "$YELLOW" "Skipping Nerd Font (headless default)."
		printf "  A font is only useful on the machine running your terminal\n"
		printf "  emulator. On a workstation run: %s --with-font\n" "$0"
		return 0
	fi

	FONT_NAME="MesloLGS Nerd Font Mono"
	FONT_DIR="$HOME/.local/share/fonts/$FONT_NAME"

	if ! command_exists fc-cache; then
		pkg_install fontconfig || {
			print_colored "$RED" "fontconfig unavailable, cannot install font"
			return 1
		}
	fi

	if fc-list :family 2>/dev/null | grep -iq "MesloLGS"; then
		printf "Font '%s' already installed\n" "$FONT_NAME"
		return 0
	fi

	print_colored "$YELLOW" "Installing font '$FONT_NAME'"
	tmp_dir=$(mktemp -d)
	if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip" \
		-o "$tmp_dir/meslo.zip"; then
		unzip -qo "$tmp_dir/meslo.zip" -d "$tmp_dir"
		mkdir -p "$FONT_DIR"
		find "$tmp_dir" -name '*.ttf' -exec mv -f {} "$FONT_DIR/" \;
		fc-cache -f >/dev/null
		print_colored "$GREEN" "Font installed"
	else
		print_colored "$RED" "Font download failed"
	fi
	rm -rf "$tmp_dir"
}

#######################################################
# Config links
#######################################################

# Back up a real file once, then symlink. Re-running is a no-op.
link_file() {
	src="$1"
	dst="$2"

	if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
		printf "Already linked: %s\n" "$dst"
		return 0
	fi

	if [ -e "$dst" ] && [ ! -L "$dst" ]; then
		bak="$dst.bak"
		if [ -e "$bak" ]; then
			bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
		fi
		print_colored "$YELLOW" "Backing up $dst -> $bak"
		mv "$dst" "$bak"
	fi

	mkdir -p "$(dirname "$dst")"
	ln -sfn "$src" "$dst"
	print_colored "$GREEN" "Linked $dst -> $src"
}

link_config() {
	if [ ! -f "$REPO_PATH/.bashrc" ]; then
		print_colored "$RED" "Cannot find .bashrc in $REPO_PATH"
		exit 1
	fi

	link_file "$REPO_PATH/.bashrc" "$HOME/.bashrc"
	link_file "$REPO_PATH/starship.toml" "$HOME/.config/starship.toml"
	link_file "$REPO_PATH/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

	if [ ! -f "$HOME/.bash_profile" ]; then
		printf '[ -f ~/.bashrc ] && . ~/.bashrc\n' > "$HOME/.bash_profile"
		print_colored "$GREEN" "Created .bash_profile"
	elif ! grep -q '\.bashrc' "$HOME/.bash_profile"; then
		print_colored "$YELLOW" ".bash_profile exists but does not source .bashrc"
	fi
}

#######################################################

check_environment
setup_repo
install_dependencies
# A network failure on one of these must not leave the configs unlinked.
install_starship || print_colored "$YELLOW" "continuing without starship"
install_fzf || print_colored "$YELLOW" "continuing without fzf"
install_zoxide || print_colored "$YELLOW" "continuing without zoxide"
install_font || print_colored "$YELLOW" "continuing without font"
link_config

print_colored "$GREEN" "Done. Restart your shell (or: exec bash) to pick up the changes."
