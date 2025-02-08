# Ghostfolio Update Script

This script automates the process of updating your Ghostfolio instance and its related Docker containers. It simplifies maintenance by pulling the latest images, restarting the containers, and pruning unused images, ensuring your Ghostfolio setup is always up-to-date.

## Usage

1.  Clone this repository: `git clone git@github.com:fucnim17/update-ghostfolio.git`
2.  Make the script executable: `chmod +x update-ghostfolio.sh`
3.  Run the script: `./update-ghostfolio.sh`

## Configuration

*   The script uses the `docker-compose.yml` file located at `/root/ghostfolio/docker/docker-compose.yml` by default.  You can modify the `COMPOSE_FILE` variable in the script to use a different file.
*   The script logs all actions to `update-ghostfolio.log`.

## License

This script is licensed under the GNU General Public License Version 3. See the `LICENSE` file for details.
