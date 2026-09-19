# Client delivery package

This is the single-server client deployment. It runs ERPNext, the custom
Lightbenders Warehouse app, the inventory gateway, and the web app on one
Docker network. Only the web application is exposed to the office network.

## Before handover

This package is source-build only. The client needs Docker Desktop on Windows
or macOS, or Docker Engine plus Docker Compose on Linux. The client does not
need Flutter, Node.js, Python, or a separate ERPNext installation.

Verify the complete Docker build:

```sh
cd deploy/client
cp .env.example .env
# Set unique values for all three passwords/secrets in .env.
docker compose build
```

## Client installation

1. Install Docker Desktop on the Windows or macOS client computer.
2. Clone this private repository and open a terminal in the repository.
3. Copy `.env.example` to `.env` and replace every placeholder with a unique
   secret. This step is mandatory; Compose stops before creating containers if
   a required value is missing. Keep `ERPNEXT_SITE_NAME` unchanged after first
   startup. Set the Company values before the first start; changing the Company
   name or abbreviation after inventory has been imported is intentionally
   rejected.
4. Start the complete stack. The first build downloads Flutter and other
   dependencies inside Docker and may take several minutes:

   ```sh
   cd deploy/client
   docker compose up -d --build
   ```

5. Wait for the first-time ERPNext site creation to finish, then open
   `http://localhost:8088`. Other office computers can use the client
   computer's LAN IP, for example `http://192.168.1.25:8088`.

## Checks

```sh
docker compose ps
docker compose logs site-init
curl http://localhost:8088/gateway/health
```

`site-init` must exit with code `0`. It creates the ERPNext site and installs
both `erpnext` and `lightbenders_warehouse` on the first start. It then creates
the configured Company and rental warehouse and imports exactly 79 Items and
560 serialized equipment units. On future starts the import is idempotent and
does not add stock again.

## Data and backups

The `db-data` and `sites` volumes contain business data. Back them up daily to
a different physical device or cloud location. Do not run `docker compose down
-v` on the client server: that deletes all ERPNext and inventory data.

For a database backup, run:

```sh
docker compose exec backend bench --site inventory.local backup --with-files
```

Keep the generated backup outside Docker volumes.

## Network and scanner use

Staff open only the web address. ERPNext, MariaDB, Redis, and the gateway have
no published ports, so they cannot be reached directly from the LAN. USB or
Bluetooth barcode scanners must be configured as keyboard wedges with an
Enter/CR suffix; they type into the focused browser scan field.
