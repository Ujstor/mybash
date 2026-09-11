#!/usr/bin/env bash
#######################################################
# mybash — bash config for headless DevOps / k8s boxes
#
# Rules this file follows:
#   * nothing here may require a display (no X11, no desktop, no GUI tools)
#   * every optional tool is guarded — a missing tool must never print an
#     error at shell start, and must never break a core command (ls, cd,
#     grep, rm, cat, kubectl)
#   * no hardcoded usernames, hostnames or LAN addresses
#######################################################

#######################################################
# HELPERS
#######################################################

# Is a command available?
_have() { command -v "$1" >/dev/null 2>&1; }

# Source a file only if it exists.
_source_if() { [ -r "$1" ] && . "$1"; }

# Append to PATH only if the dir exists and is not already there.
_path_add() {
	[ -d "$1" ] || return 0
	case ":$PATH:" in
	*":$1:"*) ;;
	*) PATH="$1:$PATH" ;;
	esac
}

#######################################################
# PATH
#######################################################

_path_add "/usr/local/go/bin"
_path_add "$HOME/go/bin"
_path_add "/usr/local/bin"
_path_add "$HOME/.local/bin"
_path_add "$HOME/bin"
_path_add "$HOME/.cargo/bin"
_path_add "${KREW_ROOT:-$HOME/.krew}/bin"
_path_add "$HOME/.pulumi/bin"
_path_add "$HOME/.sst/bin"
_path_add "/opt/nvim-linux64/bin"
export PATH

export GOPATH="$HOME/go"

export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export LINUXTOOLBOXDIR="$HOME/linuxtoolbox"

#######################################################
# Everything below this point is interactive-only.
# PATH and exports stay above it so that `ssh host '<command>'` still
# finds go/krew/local binaries.
#######################################################
case $- in
	*i*) ;;
	*) return ;;
esac

#######################################################
# SOURCED DEFINITIONS
#######################################################

_source_if /etc/bashrc

# Programmable completion
if [ -r /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
else
	_source_if /etc/bash_completion
fi

#######################################################
# HISTORY / SHELL OPTIONS
#######################################################

export HISTFILESIZE=1000000
export HISTSIZE=50000
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL=erasedups:ignoredups:ignorespace

shopt -s checkwinsize
shopt -s histappend
PROMPT_COMMAND='history -a'

# Free ctrl-S for forward history search
stty -ixon 2>/dev/null

# Readline behaviour
bind "set bell-style visible" 2>/dev/null
bind "set completion-ignore-case on" 2>/dev/null
bind "set show-all-if-ambiguous On" 2>/dev/null

#######################################################
# EDITOR
#######################################################

if _have nvim; then
	export EDITOR=nvim
	export VISUAL=nvim
	alias vi='nvim'
	alias vis='nvim "+set si"'
elif _have vim; then
	export EDITOR=vim
	export VISUAL=vim
else
	export EDITOR=vi
	export VISUAL=vi
fi

# Open a file as root with the editor you actually configured.
sedit() { sudo -E "${EDITOR:-vi}" "$@"; }

#######################################################
# COLOURS
#######################################################

export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.zip=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.log=00;32:*.yaml=00;33:*.yml=00;33:*.json=00;33:*.tf=00;35:*.xml=00;31:'

alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'

# Colourised man pages
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# bat is "bat" everywhere except Debian/Ubuntu, where it is "batcat".
# Detect the binary, do not guess from the distro.
if _have batcat; then
	alias cat='batcat'
	alias bat='batcat'
elif _have bat; then
	alias cat='bat'
fi

#######################################################
# LISTING
#######################################################

# Runtime dispatch, NOT an alias: aliases are expanded when a function is
# *parsed*, so `alias ls=eza` would bake eza into cd() and break every cd
# on a box without eza.
if _have eza; then
	_ls_long_all() { eza -la --color=always --icons "$@"; }
	alias ls='eza -aF --color=always --icons'
	alias ll='eza -la --color=always --icons'
	alias la='eza -Alh --color=always'
	alias lx='eza -la --sort=extension --color=always'
	alias lk='eza -la --sort=size --color=always'
	alias lc='eza -la --sort=changed --color=always'
	alias lu='eza -la --sort=accessed --color=always'
	alias lr='eza -laR --color=always'
	alias lt='eza -la --sort=modified --color=always'
	alias lm='eza -alh --color=always | more'
	alias lw='eza -x --color=always'
	alias labc='eza -la --sort=name --color=always'
	alias ldir='eza -laD --color=always'
	alias lla='eza -Al --color=always'
	alias las='eza -A --color=always'
	alias lls='eza -l --color=always'
	alias tree='eza --tree --color=always'
else
	_ls_long_all() { command ls -la --color=auto "$@"; }
	alias ls='ls --color=auto -F'
	alias ll='ls -la --color=auto'
	alias la='ls -Alh --color=auto'
	alias lx='ls -laX --color=auto'
	alias lk='ls -laS --color=auto'
	alias lc='ls -lac --color=auto'
	alias lu='ls -lau --color=auto'
	alias lr='ls -laR --color=auto'
	alias lt='ls -lat --color=auto'
	alias lm='ls -alh --color=auto | more'
	alias lw='ls -x --color=auto'
	alias labc='ls -la --color=auto'
	alias ldir='ls -la --color=auto -d */'
	alias lla='ls -Al --color=auto'
	alias las='ls -A --color=auto'
	alias lls='ls -l --color=auto'
	_have tree && alias tree='tree -CAhF --dirsfirst'
fi
# `command tree`, not `tree`: when eza is present the alias above makes `tree`
# mean `eza --tree --color=always`, and bash re-expands an alias's first word,
# so a bare `tree -CAFd` here became `eza … -CAFd` -> 'Unknown argument -C'.
_have tree && alias treed='command tree -CAFd'

#######################################################
# GENERAL ALIASES
#######################################################

alias ebrc='${EDITOR:-vi} ~/.bashrc'
alias da='date "+%Y-%m-%d %A %T %Z"'
alias cls='clear'
alias c='clear'

alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias ps='ps auxf'
alias ping='ping -c 10'
alias less='less -R'

# rm -> trash only when trash-cli is actually installed, otherwise rm stays rm.
if _have trash; then
	alias rm='trash -v'
fi
# Always-real recursive delete, regardless of the trash alias.
alias rmd='/bin/rm --recursive --force --verbose'

_have multitail && alias multitail='multitail --no-repeat -c'

# Directory navigation
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias bd='cd "$OLDPWD"'

alias mx='chmod a+x'
alias 644='chmod -R 644'
alias 755='chmod -R 755'

alias h='history | grep '
alias p='ps aux | grep '
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"
alias f='find . | grep '
alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"
alias checkcommand="type -t"

alias diskspace="du -S | sort -n -r | more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias mountedinfo='df -hT'

alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:\$//g' | grep -v '[0-9]\$' | xargs tail -f"
alias sha1='openssl sha1'

# Ports: ss is present on every modern systemd box; netstat often is not.
alias ports='ss -tulpn'
alias openports='ss -tulpn'

alias rebootsafe='sudo shutdown -r now'

alias ssh='ssh -o ServerAliveInterval=120 -o ServerAliveCountMax=9999'

alias docker-clean=' \
  docker container prune -f ; \
  docker image prune -f ; \
  docker network prune -f ; \
  docker volume prune -f '

#######################################################
# FUNCTIONS
#######################################################

# Extract any archive
extract() {
	for archive in "$@"; do
		if [ -f "$archive" ]; then
			case $archive in
			*.tar.bz2) tar xvjf "$archive" ;;
			*.tar.gz) tar xvzf "$archive" ;;
			*.tar.xz) tar xvJf "$archive" ;;
			*.tar.zst) tar --zstd -xvf "$archive" ;;
			*.bz2) bunzip2 "$archive" ;;
			*.rar) unrar x "$archive" ;;
			*.gz) gunzip "$archive" ;;
			*.tar) tar xvf "$archive" ;;
			*.tbz2) tar xvjf "$archive" ;;
			*.tgz) tar xvzf "$archive" ;;
			*.zip) unzip "$archive" ;;
			*.Z) uncompress "$archive" ;;
			*.7z) 7z x "$archive" ;;
			*.zst) unzstd "$archive" ;;
			*) echo "don't know how to extract '$archive'..." ;;
			esac
		else
			echo "'$archive' is not a valid file!"
		fi
	done
}

# Search for text in every file under the current directory.
# `command grep` is deliberate: it must not pick up an alias, and it must
# never become ripgrep — `rg -r` means --replace, which silently rewrites
# the matched text instead of recursing.
ftext() {
	command grep -iIHrn --color=always "$1" . | command less -r
}

# Create a directory and cd into it
mkdirg() {
	mkdir -p "$1" && cd "$1" || return
}

# Go up N directories: up 4
up() {
	local limit=${1:-1} d=""
	local i
	for ((i = 1; i <= limit; i++)); do
		d="../$d"
	done
	cd "${d:-..}" || return
}

# ls after every cd. Uses _ls_long_all, so it works with or without eza.
cd() {
	if [ -n "$1" ]; then
		builtin cd "$@" && _ls_long_all
	else
		builtin cd ~ && _ls_long_all
	fi
}

# Internal + external IP. Interface is discovered from the default route
# instead of being hardcoded to wlan0 — servers have eth0/ens*/enp*.
whatsmyip() {
	local iface
	iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
	if [ -n "$iface" ]; then
		echo -n "Internal IP ($iface): "
		ip -4 addr show "$iface" | awk '/inet /{print $2}' | cut -d/ -f1
	else
		echo "Internal IP: no default route"
	fi
	echo -n "External IP: "
	curl -s --max-time 5 ifconfig.me
	echo
}
alias whatismyip='whatsmyip'

# NVMe temperatures (physical hosts)
check_nvme_temps() {
	if ! _have nvme; then
		echo "nvme-cli not installed" >&2
		return 1
	fi
	local dev
	for dev in /dev/nvme[0-9]n[0-9]; do
		[ -e "$dev" ] || continue
		echo "$dev: $(sudo nvme smart-log "$dev" | grep -i temperature)"
	done
}
alias nvmetemp='check_nvme_temps'

# Run a command in every immediate subdirectory
run_in_all_dirs() {
	if [ $# -eq 0 ]; then
		echo "Usage: run_in_all_dirs <command> [args...]"
		echo "Example: run_in_all_dirs git status"
		return 1
	fi
	local dir
	for dir in */; do
		[ -d "$dir" ] || continue
		echo "Executing in: $dir"
		(cd "$dir" && "$@")
		echo "---"
	done
}

#######################################################
# DEVOPS TOOLING — every block guarded
#######################################################

# Prompt
_have starship && eval "$(starship init bash)"

# zoxide. `zoxide init bash` installs its own PROMPT_COMMAND hook and
# defines z/zi, so no hand-rolled hook here (it double-counted every dir).
if _have zoxide; then
	eval "$(zoxide init bash)"

	# Defined AFTER the init so these win — zoxide's own zi() would
	# otherwise overwrite them.
	_z_cd() { cd "$@" || return "$?"; }
	zi() {
		local r
		r="$(zoxide query -i -- "$@")" && _z_cd "$r"
	}
	zri() {
		local r
		r="$(zoxide query -i -- "$@")" && zoxide remove "$r"
	}
	alias za='zoxide add'
	alias zq='zoxide query'
	alias zqi='zoxide query -i'
	alias zr='zoxide remove'

	# Ctrl-f -> interactive jump
	bind '"\C-f":"zi\n"' 2>/dev/null
fi

# fzf
_source_if "$HOME/.fzf.bash"

# kubectl / kubecolor
if _have kubectl; then
	source <(kubectl completion bash)
	alias k='kubectl'
	complete -o default -F __start_kubectl k
	if _have kubecolor; then
		alias kubectl='kubecolor'
		complete -o default -F __start_kubectl kubecolor
	fi
fi

_have helm && source <(helm completion bash)
_have k3d && source <(k3d completion bash)
_have go-blueprint && source <(go-blueprint completion bash)

if _have terraform; then
	alias tf='terraform'
	alias t='terraform'
	complete -C "$(command -v terraform)" terraform
	complete -C "$(command -v terraform)" tf
	complete -C "$(command -v terraform)" t
fi

# Homebrew on Linux, if present
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
	eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
	eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

# nvm
export NVM_DIR="${NVM_DIR:-$HOME/.config/nvm}"
_source_if "$NVM_DIR/nvm.sh"
_source_if "$NVM_DIR/bash_completion"

# nala opt-in
_source_if "$HOME/.use-nala"

#######################################################
# LOCAL OVERRIDES
#######################################################
# Machine-specific settings (host IPs, per-box tool paths, cloud creds)
# belong here, not in the tracked file.
_source_if "$HOME/.bashrc.local"
