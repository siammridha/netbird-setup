# 🌐 NetBird VPN Deployer

> Complete self-hosted VPN solution — Step CA · Traefik · Embedded OIDC · Management · Signal · Relay

A single shell script that handles the full lifecycle of a [NetBird](https://netbird.io) self-hosted deployment: fresh installs, backup and full system restore, image updates, and domain changes — all from an interactive prompt with no manual config editing required.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Deployment Modes](#deployment-modes)
- [Backup & Full System Restore](#backup--full-system-restore)
- [Updating Images](#updating-images)
- [Changing Your Domain](#changing-your-domain)
- [Configuration Files](#configuration-files)
- [File Structure](#file-structure)
- [Trusting the Root CA](#trusting-the-root-ca)
- [Viewing Logs](#viewing-logs)
- [Day-to-Day Management](#day-to-day-management)

---

## Overview

`netbird-deployer.sh` automates everything needed to stand up a production-grade NetBird VPN on your own server. On each run it:

1. Stops and removes all existing Docker containers
2. Offers to restore from one of your 5 most recent backups, or starts completely fresh
3. Generates cryptographically secure secrets (or restores them from backup)
4. Initialises a private Step CA with an ACME provisioner for automated TLS
5. Writes all service configuration files from templates
6. Brings up all services via Docker Compose
7. Prints a full access summary and management command reference

---

## Architecture

| Service | Image | Role |
|---|---|---|
| **Step CA** | `smallstep/step-ca:latest` | Internal certificate authority + ACME endpoint |
| **Traefik** | `traefik:latest` | Reverse proxy, TLS termination, routing |
| **Management** | `netbirdio/management:latest` | Peer coordination and policy engine |
| **Signal** | `netbirdio/signal:latest` | WebRTC signalling for peer connections |
| **Relay** | `netbirdio/relay:latest` | TURN relay for peers behind strict NAT |
| **Dashboard** | `netbirdio/dashboard:latest` | Web UI + embedded OIDC identity provider |

---

## Prerequisites

- **Docker** and **Docker Compose v2+**
- **Alpine Linux** (or any POSIX `sh`-compatible system)
- Root / sudo access
- A domain name with a DNS **A record** pointing to this server
- The following template files in the same directory as the script:
  - `relay-template.env`
  - `dashboard-template.env`
  - `management-template.json`
  - `docker-compose-template-dev.yml`
  - `docker-compose-template-prod.yml`

> If a template file is not found locally the script will automatically fetch it from the remote repository.

---

## Quick Start

```sh
chmod +x netbird-deployer.sh
./netbird-deployer.sh
```

You will be prompted for your domain and setup directory, then the script handles everything else.

---

## Usage

```sh
./netbird-deployer.sh              # Interactive deployment (default: dev mode)
./netbird-deployer.sh --dev        # Deploy using the development template
./netbird-deployer.sh --prod       # Deploy using the production template
./netbird-deployer.sh --update     # Pull latest images and restart all services
./netbird-deployer.sh --backup     # Backup current configuration only
./netbird-deployer.sh --help       # Show usage information
```

---

## Deployment Modes

| Flag | Template Used | Intended For |
|---|---|---|
| _(none)_ / `--dev` | `docker-compose-template-dev.yml` | Local testing, includes Traefik dashboard |
| `--prod` | `docker-compose-template-prod.yml` | Production servers |

In `--dev` mode the Traefik dashboard is exposed at `https://traefik.<your-domain>` for debugging. This is disabled in `--prod` mode.

---

## Backup & Full System Restore

### Creating a Backup

Run the backup command at any time to snapshot your current installation:

```sh
./netbird-deployer.sh --backup
```

A timestamped archive is saved to `/backups/`:

```
/backups/netbird-backup-20250220-143022.tar.gz
```

Each backup contains:

| Directory | Contents |
|---|---|
| `secrets/` | `nb_auth_secret`, `datastore_encryption_key`, `step_ca_password` |
| `step-ca-data/` | CA root & intermediate certificates, CA configuration |
| `management/data` | Management service persistent peer and policy data |

> The ephemeral Step CA `db/` and `templates/` directories are excluded to keep archive sizes small — they are regenerated automatically on restore.

You can verify the contents of any backup without extracting it:

```sh
tar -tzf /backups/netbird-backup-20250220-143022.tar.gz
```

### Full System Restore

The deployer keeps your **5 most recent backups** and presents them as a numbered menu every time you run a deployment. To restore a previous system in full — including all secrets, the certificate authority, and all management data — simply re-run the script and select the backup you want:

```sh
./netbird-deployer.sh --prod
```

```
📦 Available backups (5 most recent):
  [1] netbird-backup-20250220-143022.tar.gz
  [2] netbird-backup-20250219-090011.tar.gz
  [3] netbird-backup-20250218-060500.tar.gz
  [0] Skip restore — generate fresh secrets and CA

Select backup to restore [0-3]:
```

Selecting a backup restores your secrets, Step CA, and management data before any new containers are started. All existing peers and policies will be intact once the services come back up.

> **Important:** Because the Step CA and its root certificate are restored from the backup, clients that previously trusted the CA do not need to re-import any certificates after a restore.

---

## Updating Images

To pull the latest versions of all NetBird service images and restart everything without touching your configuration or data:

```sh
./netbird-deployer.sh --update
```

This will:

1. Stop and remove all running containers
2. Pull the latest version of each image:
   - `smallstep/step-ca:latest`
   - `traefik:latest`
   - `netbirdio/dashboard:latest`
   - `netbirdio/signal:latest`
   - `netbirdio/relay:latest`
   - `netbirdio/management:latest`
3. Start all services again using your existing `docker-compose.yml`

Your secrets, CA data, and management data are untouched. If any individual image pull fails, the script will warn you and fall back to the existing local image rather than aborting.

---

## Changing Your Domain

The domain name is baked into several configuration files during deployment (`relay.env`, `dashboard.env`, `management/config.json`, and `docker-compose.yml`). To move your installation to a new domain, run a fresh deployment — and restore from backup to preserve all your peers and policies:

```sh
./netbird-deployer.sh --prod
```

When prompted:

1. **Enter your new domain** — all config files will be regenerated with the new value
2. **Select your most recent backup** — this restores your secrets, CA, and management data

Because the Step CA is restored from the same backup, its root certificate fingerprint does not change. Clients already trusting the old CA will continue to work. The only client-side change needed is updating the Management server URL to the new domain.

> If you are also changing your server (new IP), update your DNS A record to the new server before running the deployment so that Traefik can obtain certificates without interruption.

---

## Configuration Files

After deployment the following files are written to your setup directory:

| File | Description |
|---|---|
| `docker-compose.yml` | Full service orchestration |
| `relay.env` | Relay service environment (domain, auth secret) |
| `dashboard.env` | Dashboard OIDC configuration |
| `management/config.json` | Management service config (domain, secrets, datastore key) |
| `secrets/nb_auth_secret` | Shared authentication secret |
| `secrets/datastore_encryption_key` | Encryption key for the management datastore |
| `secrets/step_ca_password` | Password protecting the Step CA private key |
| `step-ca-data/certs/root_ca.crt` | Root CA certificate (distribute to clients) |

---

## File Structure

```
<setup-directory>/
├── docker-compose.yml
├── relay.env
├── dashboard.env
├── management/
│   ├── config.json
│   └── data/               ← peer and policy database
├── secrets/
│   ├── nb_auth_secret
│   ├── datastore_encryption_key
│   └── step_ca_password
└── step-ca-data/
    ├── certs/
    │   ├── root_ca.crt     ← distribute to clients
    │   └── intermediate_ca.crt
    └── config/
        └── ca.json

/backups/
└── netbird-backup-YYYYMMDD-HHMMSS.tar.gz
```

---

## Trusting the Root CA

NetBird uses your private Step CA for internal TLS. Every client device that connects to the Management or Dashboard must trust the root CA certificate, otherwise connections will be refused.

The root CA is located at:

```
<setup-directory>/step-ca-data/certs/root_ca.crt
```

**Linux:**
```sh
cp root_ca.crt /usr/local/share/ca-certificates/netbird-root-ca.crt
update-ca-certificates
```

**macOS:**
```sh
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain root_ca.crt
```

**Windows (PowerShell as Administrator):**
```powershell
Import-Certificate -FilePath "root_ca.crt" `
  -CertStoreLocation Cert:\LocalMachine\Root
```

---

## Viewing Logs

```sh
# Follow all services in real time
docker compose logs -f

# Follow a specific service
docker compose logs -f management
docker compose logs -f step-ca
docker compose logs -f traefik
docker compose logs -f relay
docker compose logs -f signal
docker compose logs -f dashboard
```

---

## Day-to-Day Management

| Task | Command |
|---|---|
| Check service status | `docker compose ps` |
| Follow all logs | `docker compose logs -f` |
| Stop all services | `docker compose down` |
| Start stopped services | `docker compose up -d` |
| Restart a single service | `docker compose restart <service>` |
| Update all images | `./netbird-deployer.sh --update` |
| Backup configuration | `./netbird-deployer.sh --backup` |
| Full redeploy (keep data) | `./netbird-deployer.sh --prod` → select backup |
| Fresh install (no data) | `./netbird-deployer.sh --prod` → select 0 |
| Change domain | `./netbird-deployer.sh --prod` → enter new domain → select backup |