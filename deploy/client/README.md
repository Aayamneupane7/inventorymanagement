# Client delivery package

This is the single-server client deployment. It runs ERPNext, the custom
Lightbenders Warehouse app, the inventory gateway, and the web app on one
Docker network. Only the web application is exposed to the office network.

## Before handover

Build the web bundle once on the delivery machine and include
`inventory_web/build/web` in the client delivery folder/archive:

```sh
cd inventory_web
/home/hckeer/flutter/bin/flutter build web --release --dart-define=GATEWAY_URL=/gateway
```

Build the custom ERPNext image once to verify the package:

```sh
cd deploy/client
cp .env.example .env
# Set unique values for all three passwords/secrets in .env.
docker compose build
```

## Client installation

1. Install Docker Engine and the Docker Compose plugin on a dedicated,
   always-on Linux PC or server.
2. Copy this repository with the prebuilt `inventory_web/build/web` files to
   that server.
3. Copy `.env.example` to `.env` and replace every placeholder with a unique
   secret. This step is mandatory; Compose stops before creating containers if
   a required value is missing. Keep `ERPNEXT_SITE_NAME` unchanged after first
   startup. Set the Company values before the first start; changing the Company
   name or abbreviation after inventory has been imported is intentionally
   rejected.
4. Start the complete stack:

   ```sh
   cd deploy/client
   docker compose up -d --build
   ```

5. Wait for the first-time ERPNext site creation to finish, then open
   `http://SERVER-LAN-IP:8088`. Change `WEB_PORT` to `80` if that port is
   available and the server is configured for it.

## Checks

```sh
docker compose ps
docker compose logs site-init
curl http://localhost:8088/gateway/health
```

`site-init` must exit with code `0`. It creates the ERPNext site and installs
both `erpnext` and `lightbenders_warehouse` on the first start. It then creates
the configured Company and rental warehouse, and imports the included initial
barcode inventory once. On future starts the import is idempotent and does not
add stock again.

## Data and backups

The `db-data` and `sites` volumes contain business data. Back them up daily to
a different physical device or cloud location. Do not run `docker compose down
-v` on the client server: that deletes all ERPNext and inventory data.

## Network and scanner use

Staff open only the web address. ERPNext, MariaDB, Redis, and the gateway have
no published ports, so they cannot be reached directly from the LAN. USB or
Bluetooth barcode scanners must be configured as keyboard wedges with an
Enter/CR suffix; they type into the focused browser scan field.
