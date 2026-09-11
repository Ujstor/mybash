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
  deleting it, never clobbers an existing `.bashrc.bak`, and never prompts.
* **No machine-specific values.** No hardcoded usernames, hostnames or LAN
  addresses. Put those in `~/.bashrc.local`, which is sourced last if present.

## What the installer installs

CLI only: `bash-completion`, `tar`, `unzip`, `bat`, `tree`, `multitail`,
`wget`, `trash-cli`, `fzf`, `eza` (best effort), `neovim`, `fastfetch`,
plus `starship` and `zoxide` from their upstream installers.

`eza` is not in the repositories of older Debian/Ubuntu releases. If it can't
be installed the shell falls back to plain `ls` — every `l*` alias still works.

## Uninstall

```sh
./uninstall.sh              # configs + starship/fzf/zoxide
./uninstall.sh --packages   # also remove the distro packages
./uninstall.sh --font       # also remove the opt-in Nerd Font
```
