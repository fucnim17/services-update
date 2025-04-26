# Services Update Script

This script automates the maintenance of multiple services running in Docker and Podman containers:

1. **Jellyfin**
2. **Paperless**
3. **PhotoPrism**
4. **Memos**
5. **Adguard Home**
6. **Docker & Podman**

It simplifies maintenance by pulling the latest images, restarting containers, and performing routine tasks to ensure your services are always up-to-date and backed up.

## Usage

```bash
# Clone this repository
git clone https://github.com/fucnim17/services-update.git

# Change into the repository directory
cd services-update

# Make the script executable
chmod +x services-update.sh

# Run the script
./services-update.sh
```

This script can be automated using Cron or run automatically at system reboot.

## Configuration

The script uses the following configuration by default:
- Jellyfin docker-compose file: `/root/jellyfin/docker-compose.yml`
- Memos docker-compose file: `/root/memos/docker-compose.yml`
- Paperless directory: `/root/paperless-ngx/docker/compose`
- Log file location: `/root/services-update/services-update.log`

You can modify the variables at the beginning of the script to customize file paths.

## Log Management

The script maintains a detailed log file with timestamps and separators between each run, making it easy to track updates and troubleshoot issues if they occur.

## License

This script is licensed under the GNU General Public License Version 3. See the LICENSE file for details.
