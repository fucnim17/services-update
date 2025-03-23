# Services Update Script

This script automates the maintenance of multiple services running in Docker containers:

1. **Jellyfin**: Updates the media server instance
2. **Ghostfolio**: Updates the personal finance tracking application
3. **Docker**: Cleans up unused images
4. **Paperless**: Creates backup exports of your documents

It simplifies maintenance by pulling the latest images, restarting containers, and performing routine tasks to ensure your services are always up-to-date and backed up.

## Usage

```bash
# Clone this repository
git clone https://github.com/fucnim17/services-update.git

# Make the script executable
chmod +x services-update.sh

# Run the script
./services-update.sh
```

This script can be automated using Cron or run automatically at system reboot.

## Configuration

The script uses the following configuration by default:
- Ghostfolio docker-compose file: `/root/ghostfolio/docker/docker-compose.yml`
- Jellyfin docker-compose file: `/root/jellyfin/docker-compose.yml`
- Paperless directory: `/root/paperless-ngx/docker/compose`
- Log file location: `/root/update-ghostfolio/services-update.log`

You can modify the variables at the beginning of the script to customize file paths.

## Services Managed

- **Jellyfin**: Updates the media server containers
- **Ghostfolio**: Updates finance tracking containers and sets proper restart policies
- **Paperless**: Creates document backups with compression
- **Docker**: Prunes unused images to save disk space

## License

This script is licensed under the GNU General Public License Version 3. See the LICENSE file for details.
