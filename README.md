# MENG - Server Management Script

A unified bash script for deployment, SSH connections, and server management. Built to eliminate repetitive `scp` and `ssh` commands with a clean, reliable interface.

## Why MENG?

**The Problem:** Constantly typing long deployment commands like:
```
go build -o myapp
scp myapp user@192.168.1.100:/home/user/apps/
ssh user@192.168.1.100
```

**The Solution:** One simple command that handles building, copying, and connecting:

```
./meng.sh -alias myserver -action deploy
```

## Quick Start

1. **Clone and make executable:**
```
git clone https://github.com/Maty-0/Meng-Script.git
cd Meng-Script
chmod +x meng.sh
```

2. **Configure your servers** by editing the aliases section in `meng.sh`:
```
declare -A aliases=(
[myserver]="user@192.168.1.100:/path/to/deploy/"
[staging]="deploy@staging.company.com:/var/www/"
[production]="admin@prod.company.com:/opt/apps/"
)
```
You can also define scripts aliases here: 
```
declare -A scripts=(
[backup]="/home/user/scripts/rclone_backup.sh"
)
```

3. **Start using it:**
#### Show available servers and scripts
```
./meng.sh --list 
```
#### Show alias information
```
./meng.sh --alias myserver --action echo 
```
#### Connect to server
```
./meng.sh --alias myserver --action ssh  
```
#### Run script
```
./meng.sh --script backup --action run  
```
#### Send file to server
```
./meng.sh --alias myserver --action scp -file myapp
```
#### Send folder to server
```
./meng.sh --alias myserver --action scp -r -file myapp/
```
#### Build and deploy 
```
./meng.sh --alias myserver --action deploy
```
#### Overwrite alias path
```
./meng.sh --alias myserver --action scp --file myapp --path /home/myuser/
```
#### Append to the alias path
```
./meng.sh --alias myserver --action scp --file myapp --path folder/subfolder
```

> [!TIP]
> **Make meng.sh available globally**
> ```
> sudo cp meng.sh /usr/local/bin/meng
> sudo chmod +x /usr/local/bin/meng
> ```
> Now you can call eg; `meng -list` from anywhere :)