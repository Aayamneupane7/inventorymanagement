# Inventory Management Web Application

Web-based inventory and equipment-rental management application built with
Flutter Web, ERPNext/Frappe, and a custom inventory gateway. This repository
contains the web version of the application. The Android APK is not required.

## What is included

- Flutter Web frontend
- ERPNext and Frappe backend
- `lightbenders_warehouse`, the custom ERPNext app
- Inventory gateway used by the frontend
- Docker Compose deployment for the complete stack
- Initial inventory and barcode setup for a demonstration environment

## Requirements

Install these on the computer that will run the application:

- Docker Engine
- Docker Compose plugin (`docker compose`)
- Docker Desktop on Windows or macOS, or Docker Engine on Linux
- At least 8 GB RAM is recommended for the complete ERPNext stack

The first Docker build downloads required images and dependencies, so it may
take several minutes.

## Quick start: complete web application

Clone the repository:

```bash
git clone https://github.com/Aayamneupane7/inventorymanagement.git
cd inventorymanagement
```

Go to the client deployment directory and create the local environment file:

```bash
cd deploy/client
cp .env.example .env
```

Open `.env` and replace the three placeholder secrets:

```env
DB_ROOT_PASSWORD=choose-a-strong-database-password
ERPNEXT_ADMIN_PASSWORD=choose-a-strong-login-password
SESSION_SECRET=choose-a-random-secret-of-at-least-32-characters
```

Start the complete application:

```bash
docker compose up -d --build
```

Docker builds the Flutter Web frontend, gateway, and custom ERPNext image
automatically. Flutter, Node.js, and Python do not need to be installed on the
client computer.

Open the application at `http://localhost:8088`.

Log in with:

- Username: `Administrator`
- Password: the value of `ERPNEXT_ADMIN_PASSWORD` in `.env`

The first startup creates the ERPNext site, installs ERPNext and the custom
warehouse app, creates the configured company and warehouse, and imports
exactly 79 Items and 560 serialized equipment units from the client seed. The
first startup can take several minutes.

## Allow a colleague on the same network to test

Run the application on a computer that stays powered on. On Windows, find its
LAN address with `ipconfig`; on macOS/Linux, use `ifconfig` or `hostname -I`.
For example, if the address is `192.168.1.25`, another computer on the same
network can open:

```text
http://192.168.1.25:8088
```

The Docker computer and containers must remain online. Do not expose this
development URL directly to the public internet. Use HTTPS and proper access
control for a public deployment.

## Verify the installation

Run these commands from `deploy/client`:

```bash
docker compose ps
docker compose logs site-init
curl http://localhost:8088/gateway/health
```

`site-init` should finish with exit code `0`. The health endpoint should return
a successful response from the inventory gateway.

## Stopping and restarting

Stop the containers without deleting application data:

```bash
docker compose down
```

Start them again later:

```bash
docker compose up -d
```

Do not run `docker compose down -v` unless you intentionally want to delete
the ERPNext database, uploaded files, and inventory data.

## Data and security notes

- Never commit `.env` or real passwords to GitHub.
- Change all example passwords before using the system.
- Back up Docker volumes containing the database and ERPNext site files.
- The included inventory is demonstration data; review the import before using
  real business data.
- For an internet-facing deployment, use a domain, HTTPS, firewall rules, and
  a private server. Do not publish MariaDB, Redis, or internal ERPNext ports.

## Troubleshooting

View service status and recent logs:

```bash
cd deploy/client
docker compose ps
docker compose logs --tail=100
```

If first initialization fails, inspect:

```bash
docker compose logs site-init
```

## More deployment details

See [`deploy/client/README.md`](deploy/client/README.md) for the full
single-server handover procedure, scanner configuration, network behavior, and
backup guidance.

The 560-row source workbook is `docs/generated/GRIP_LIST_BARCODE_PAYLOADS.xlsx`.
The reproducible conversion is `scripts/generate_grip_client_seed.py`; the
generated ERPNext seed is committed under the custom app's setup data.

## Project status

This inventory management project is under active development. Confirm the
appropriate license and production-readiness requirements before using it with
business or customer data.
