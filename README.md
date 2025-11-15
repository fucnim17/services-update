# Services Update Script

This script automates the maintenance of multiple services running in Docker and Podman containers:

1. **Jellyfin**
2. **Paperless**
3. **PhotoPrism**
4. **Memos**
5. **Adguard Home**
6. **Homepage**
7. **qBittorrent**
8. **Dockpeek**
9. **OmniTools**

It simplifies maintenance by pulling the latest images, restarting containers, and performing routine tasks to ensure your services are always up-to-date and backed up.

## Usage

```bash
# Clone this repository
git clone https://github.com/fucnim17/services-update.git

# Change into the repository directory
cd services-update

# Create a .env file (see below for content)
nano .env

# Make the script executable
chmod +x services-update.sh

# Run the script
./services-update.sh
```

This script can be automated using Cron or run automatically at system reboot.

## Configuration

You can customize file paths and select which services to update by editing the .env file.

```bash
##################### - Jellyfin - ####################

UPDATE_JELLYFIN=false
JELLYFIN_COMPOSE_FILE=""

#-------------------------------------------------------
###################### - Memos - #######################

UPDATE_MEMOS=false
MEMOS_DIRECTORY=""
MEMOS_COMPOSE_FILE=""
MEMOS_BACKUP_DIRECTORY=""

#-------------------------------------------------------
################### - AdGuard Home - ###################

UPDATE_ADGUARDHOME=false
ADGUARDHOME_COMPOSE_FILE=""

#-------------------------------------------------------
################## - Paperless-ngx - ###################

UPDATE_PAPERLESS=false
PAPERLESS_DIRECTORY=""
PAPERLESS_COMPOSE_FILE=""

#-------------------------------------------------------
################ - PhotoPrism (omv) - ##################

UPDATE_PHOTOPRISM=false

#-------------------------------------------------------
################### - qBittorrent - ####################

UPDATE_QBITTORRENT=false
QBITTORRENT_COMPOSE_FILE=""

#-------------------------------------------------------
#################### - Dockpeek - ######################

UPDATE_DOCKPEEK=false
DOCKPEEK_COMPOSE_FILE=""

#-------------------------------------------------------
#################### - OmniTools - ######################

UPDATE_OMNITOOLS=false
OMNITOOLS_COMPOSE_FILE=""

#-------------------------------------------------------
##################### - Homepage - ######################

UPDATE_HOMEPAGE=false
HOMEPAGE_COMPOSE_FILE=""

#-------------------------------------------------------

LOG_FILE="./services-update.log"

```

## Log Management

The script maintains a detailed log file with timestamps and separators between each run, making it easy to track updates and troubleshoot issues if they occur.

## License

This script is licensed under the GNU General Public License Version 3. See the LICENSE file for details.
