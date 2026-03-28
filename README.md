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

## Usage

```bash
# save a server
meng add prod admin@192.168.1.100:/opt/app/

# or just SSH in normally, then save it after
ssh admin@192.168.1.100
meng ingest prod !!

# connect / copy / deploy
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

meng add <name> <user@host:/path>
meng remove <name>
meng ingest <name> [ssh] <user@host>
meng list

meng run <name>
meng script add <name> <path>
meng script remove <name>

```
> `-p` with a leading `/` replaces the alias path entirely, without one it appends to it.
> `deploy` assumes a Go project and runs `go build` first.