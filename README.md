# mybash

Bash configuration for headless DevOps / Kubernetes boxes.

```sh
curl -sSL https://raw.githubusercontent.com/Ujstor/mybash/main/setup.sh | sh
```

or, from a checkout:

```sh
git clone https://github.com/Ujstor/mybash && cd mybash && ./setup.sh
```

## Design rules

* **No display required.** Nothing here installs or calls an X server,
  a desktop, or a GUI tool. Safe on a bare Ubuntu/Debian server or in a
  container.
* **No font on the server.** A Nerd Font has to be installed where the
  *terminal emulator* runs, not on the machine you ssh into. The installer
  skips it by default; on a workstation opt in with `./setup.sh --with-font`.
* **Everything optional is guarded.** A missing tool never prints an error at
  shell start and never breaks a core command — `ls`, `cd`, `grep`, `rm`,
  `cat` and `kubectl` all work on a box with nothing installed.
* **Idempotent.** Re-running `setup.sh` updates the checkout instead of
  deleting it, never clobbers an existing backup, and never prompts. Whatever it
  replaces — a real file or someone else's symlink — is backed up first and
  recorded in `~/.local/state/mybash/backups`, so `uninstall.sh` puts back
  exactly that.
* **`~/.profile` stays in charge of login shells.** A login bash reads only the
  first of `~/.bash_profile` and `~/.profile`, so `setup.sh` writes a
  `~/.bash_profile` only when nothing would load `~/.bashrc` otherwise.
* **No machine-specific values.** No hardcoded usernames, hostnames or LAN
  addresses. Put those in `~/.bashrc.local`, which is sourced last if present.

## What the installer installs

CLI only: `bash-completion`, `tar`, `unzip`, `bat`, `tree`, `multitail`,
`wget`, `trash-cli`, `fzf`, `eza` (best effort), `neovim`, `fastfetch`,
plus `starship` and `zoxide` from their upstream installers into `~/.local/bin`.
Without root, sudo or doas it skips the distro packages and does the rest.

`./setup.sh --config-only` installs nothing at all: it links the configs and
stops. That is how [linux-devops-tools](https://github.com/Ujstor/linux-devops-tools)
runs it, because it installs every one of those tools itself — pinned and
checksum-verified — and a second, unpinned copy in `~/.local/bin` would shadow
them (and pull a distro neovim next to its upstream one).

`eza` is not in the repositories of older Debian/Ubuntu releases. If it can't
be installed the shell falls back to plain `ls` — every `l*` alias still works.

## Uninstall

```sh
./uninstall.sh              # configs + starship/fzf/zoxide
./uninstall.sh --packages   # also remove the distro packages
./uninstall.sh --font       # also remove the opt-in Nerd Font
```

It removes only links that point into the mybash checkout, puts back the backup
`setup.sh` made of each, and deletes only the `starship` and `zoxide` it put in
`~/.local/bin` — never a copy some package or other installer owns.
