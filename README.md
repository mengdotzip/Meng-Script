# meng

A small script I built to stop retyping the same ssh/scp commands all day.

## Setup

```bash
git clone https://github.com/mengdotzip/Meng-Script.git
cd Meng-Script
```

To use it from anywhere without the `./`:

```bash
mkdir -p ~/.local/bin
cp meng.sh ~/.local/bin/meng
```

If `~/.local/bin` isn't in your PATH yet, add this to your `.bashrc` or `.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Tab completion**

* bash

```bash
mkdir -p ~/.local/share/bash-completion/completions
cp meng-completion.bash ~/.local/share/bash-completion/completions/meng
source ~/.local/share/bash-completion/completions/meng
```

* zsh

```bash
mkdir -p ~/.local/share/zsh/site-functions
cp _meng ~/.local/share/zsh/site-functions/_meng
```

Add to `~/.zshrc` if not already there:

```bash
fpath=(~/.local/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit
```

Reload without restarting your shell:

```bash
unfunction _meng 2>/dev/null; autoload -Uz _meng
```

## Usage

```bash
# save a server
meng add prod admin@192.168.1.100:/opt/app/

# save a server with a custom SSH port
meng add staging admin@192.168.1.100:/opt/app/ -p 2222

# or just SSH in normally, then save it after
ssh admin@192.168.1.100
meng ingest prod !!

# ingest an SSH command that uses a custom port
ssh -p 2222 admin@192.168.1.100
meng ingest staging !!

# connect / copy / deploy (port is used automatically)
meng ssh    prod
meng scp    prod build/myapp
meng scp    prod dist/ -r
meng deploy prod myapp

# scripts
meng script add backup ~/scripts/rclone_backup.sh
meng run backup

# see everything
meng list
```

## Config

Everything lives in `~/.config/meng/` — created automatically on first run.
```
~/.config/meng/
├── aliases # your servers
└── scripts # your script shortcuts
```
Plain text, one entry per line. Worth backing up or sticking in a dotfiles repo.


## All commands
```
meng ssh <alias>
meng scp <alias> <file> [-r] [-p <path>]
meng deploy <alias> <file>
meng info <alias>

meng add <name> <user@host:/path> [-p <port>]
meng remove <name>
meng ingest <name> [ssh] <user@host>
meng list

meng run <name>
meng script add <name> <path>
meng script remove <name>

```
> `-p` on `scp` with a leading `/` replaces the alias path entirely, without one it appends to it.
> `-p <port>` on `add` sets a custom SSH/SCP port, stored in the alias and applied automatically.
> `deploy` assumes a Go project and runs `go build` first.