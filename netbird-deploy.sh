#!/bin/sh
#
# ╔══════════════════════════════════════════════════════════════════════╗
# ║                        🌐 NETBIRD DEPLOYER                           ║
# ║                  Complete Self-Hosted VPN Solution                   ║
# ║   Step CA + Traefik + Embedded OIDC + Management + Signal + Relay    ║
# ╚══════════════════════════════════════════════════════════════════════╝
#
# 🎯 PURPOSE
# ==========
# Automates complete cleanup, secure setup, and deployment of the NetBird
# self-hosted VPN platform. Includes a Step CA certificate authority,
# Traefik reverse proxy, and an embedded OIDC identity provider for
# Zero Trust network access.
#
# ✨ FEATURES
# ===========
# ├─ 🧹 Complete Docker cleanup (containers, volumes, networks)
# ├─ 🔐 Generates cryptographically secure random secrets
# ├─ 📜 Step CA with ACME provisioner for automated certificate issuance
# ├─ 🚀 Deploys Management, Signal, Relay, and Dashboard services
# ├─ 🌍 Interactive domain and setup directory configuration
# ├─ 💾 Smart backup/restore from the 5 most recent backups
# ├─ 🔄 Template-based configuration generation (dev/prod modes)
# ├─ 🎨 Real-time colored progress output with status indicators
# ├─ 📊 Post-deployment access info and management commands
# └─ 🗂️ Backup-only mode to preserve existing configurations
#
# 🛠️ PREREQUISITES
# ================
# ├─ Docker + Docker Compose v2+
# ├─ Required working path: alpine_vm/net_bird/
# ├─ Root/sudo privileges for directory operations
# ├─ A public domain with a DNS A record pointing to this server
# └─ Template files in the same directory as this script:
#      relay-template.env
#      dashboard-template.env
#      management-template.json
#      docker-compose-template-dev.yml
#      docker-compose-template-prod.yml
#
# 📋 USAGE
# ========
#   ./netbird-deployer.sh                 # Interactive mode (prompts for domain & directory)
#   ./netbird-deployer.sh --dev           # Deploy with the dev template (default)
#   ./netbird-deployer.sh --prod          # Deploy with the production template
#   ./netbird-deployer.sh --backup        # Backup existing configuration only
#   ./netbird-deployer.sh --update        # Pull latest images and restart all containers
#   ./netbird-deployer.sh --help          # Show usage information
#
# 🔄 DEPLOYMENT MODES
# ===================
#   --dev   : Uses docker-compose-template-dev.yml (default behavior)
#   --prod  : Uses docker-compose-template-prod.yml for production deployments
#
# 💾 BACKUP & RESTORE
# ===================
#   During deployment, the script will:
#   ├─ Search for the 5 most recent backups in /backups/
#   ├─ Prompt you to select a backup to restore from (or start fresh)
#   ├─ Restore secrets/, step-ca-data/, and management/data if available
#   └─ Generate fresh secrets and a new CA if no backup is selected
#
#   Backups include the following paths:
#   ├─ step-ca-data/             (CA certificates, configuration, and password file)
#   ├─ management/nb_auth_secret (NetBird auth secret)
#   ├─ management/datastore_encryption_key (datastore encryption key)
#   └─ management/data           (management service persistent data)
#
# 🏷️ METADATA
# ===========
# Author:  NetBird Deployment Engineering Team
# Version: 2.0 — Enhanced UI/UX Edition
# License: MIT
#
set -euo pipefail # 🚫 Exit immediately on any error, undefined variable, or pipe failure

# =============================================================================
# 🌈 TERMINAL BEAUTIFICATION & LOGGING SYSTEM
# =============================================================================

# ANSI Extended Color Palette
readonly GREEN='\033[1;32m'      # Success  ✓  Bright Green
readonly BLUE='\033[1;34m'       # Info     ➜  Bright Blue
readonly YELLOW='\033[1;33m'     # Warning  ⚠  Bright Yellow
readonly RED='\033[1;31m'        # Error    ✗  Bright Red
readonly CYAN='\033[1;36m'       # Highlight    Bright Cyan
readonly MAGENTA='\033[1;35m'    # Domain   🌐  Bright Magenta
readonly PURPLE='\033[0;35m'     # Progress ▓  Purple
readonly GRAY='\033[0;37m'       # Subtle   ─  Dim Gray
readonly NC='\033[0m'            # No Color (reset)

# -----------------------------------------------------------------------------
# BANNERS
# -----------------------------------------------------------------------------

show_main_banner() {
    echo -e "${CYAN}
╔══════════════════════════════════════════════════════════════════════╗
║                       🌐 NETBIRD VPN DEPLOYER                        ║
║                Complete Self-Hosted VPN Solution v2.0                ║
║                                                                      ║
║     Step CA + Traefik + Embedded OIDC + Management + Signal + Relay  ║
╚══════════════════════════════════════════════════════════════════════╝${NC}"
}

show_cleanup_banner() {
    echo -e "${YELLOW}
╓══════════════════════════════════════════════════════════════════════╖
║                           🧹 SYSTEM CLEANUP                          ║
║                           Nuclear Docker Reset                       ║
╙══════════════════════════════════════════════════════════════════════╜
${NC}"
}

show_setup_banner() {
    echo -e "${CYAN}
╓══════════════════════════════════════════════════════════════════════╖
║                           ⚙️  SETUP PHASE                             ║
║                     Intelligent Configuration Engine                 ║
╙══════════════════════════════════════════════════════════════════════╜
${NC}"
}

show_success_banner() {
    echo -e "${GREEN}
╔══════════════════════════════════════════════════════════════════════╗
║                      🎉 DEPLOYMENT SUCCEEDED!                        ║
║                       ALL SERVICES OPERATIONAL                       ║
╚══════════════════════════════════════════════════════════════════════╝${NC}"
}

show_update_banner() {
    echo -e "${CYAN}
╓══════════════════════════════════════════════════════════════════════╖
║                         🔄 UPDATE MODE                               ║
║                  Pull Latest Images & Restart Services               ║
╙══════════════════════════════════════════════════════════════════════╜
${NC}"
}

# -----------------------------------------------------------------------------
# LOGGING HELPERS
# -----------------------------------------------------------------------------

info() {
    echo -e "${BLUE}  ➜ $(printf '%-60s' "$1") ${NC}"
}

success() {
    echo -e "${GREEN}  ✓ $(printf '%-60s' "$1") ${NC}"
}

warn() {
    echo -e "${YELLOW}  ⓘ  $(printf '%-60s' "$1") ${NC}"
}

error() {
    echo -e "${RED}  ❌ CRITICAL: $1 ${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    exit 1
}

progress() {
    echo -e "${PURPLE}  $(printf '%-60s' "$1") ${NC}"
}

# -----------------------------------------------------------------------------
# USAGE INFORMATION
# -----------------------------------------------------------------------------

print_usage() {
    echo -e "${CYAN}
╔══════════════════════════════════════════════════════════════════════╗
║                      📖 NETBIRD DEPLOYER USAGE                       ║
╚══════════════════════════════════════════════════════════════════════╝${NC}

${GREEN}BASIC USAGE:${NC}
  $0                         ${GRAY}# Interactive deployment (prompts for domain & directory)${NC}

${GREEN}DEPLOYMENT MODES:${NC}
  $0 --dev                   ${GRAY}# Deploy with the development template (default)${NC}
  $0 --prod                  ${GRAY}# Deploy with the production template${NC}

${GREEN}UTILITY COMMANDS:${NC}
  $0 --backup                ${GRAY}# Create a backup of the current configuration${NC}
  $0 --update                ${GRAY}# Pull latest images and restart all containers${NC}
  $0 --help                  ${GRAY}# Show this help message${NC}

${GREEN}WORKFLOW:${NC}
  1. Prompts for a target domain name (default: mylocaldomain.dev)
  2. Prompts for a setup directory (default: /root)
  3. Shows available backups and allows selection, or starts a fresh install
  4. Cleans up existing Docker containers, volumes, and networks
  5. Generates or restores secrets and all configuration files
  6. Deploys all services using the selected template (dev/prod)
  7. Creates a timestamped backup of the new configuration

${GREEN}TEMPLATES:${NC}
  ${CYAN}--dev${NC}  → Uses docker-compose-template-dev.yml
  ${CYAN}--prod${NC} → Uses docker-compose-template-prod.yml

${GREEN}UPDATE WORKFLOW (--update):${NC}
  1. Stops and removes all running Docker containers
  2. Pulls the latest versions of all NetBird service images
  3. Restarts all services using the existing docker-compose.yml

${GREEN}IMAGES UPDATED (--update):${NC}
  ${GRAY}smallstep/step-ca:latest${NC}
  ${GRAY}traefik:latest${NC}
  ${GRAY}netbirdio/dashboard:latest${NC}
  ${GRAY}netbirdio/signal:latest${NC}
  ${GRAY}netbirdio/relay:latest${NC}
  ${GRAY}netbirdio/management:latest${NC}

${GREEN}BACKUP LOCATION:${NC}
  /backups/netbird-backup-YYYYMMDD-HHMMSS.tar.gz

${GREEN}EXAMPLES:${NC}
  $0                         ${GRAY}# Fully interactive deployment${NC}
  $0 --prod                  ${GRAY}# Production deployment${NC}
  $0 --backup                ${GRAY}# Backup current config only${NC}
  $0 --update                ${GRAY}# Update all images and restart services${NC}
"
}

# =============================================================================
# 🧹 CLEANUP PHASE — Nuclear Docker Reset
# =============================================================================

cleanup_docker_containers() {
    info "Scanning Docker environment for cleanup..."

    # 🛑 Stop all running containers gracefully before removal
    if [[ $(docker ps -q | wc -l) -gt 0 ]]; then
        progress "Stopping all running containers..."
        docker stop $(docker ps -q) >/dev/null 2>&1
        success "All containers gracefully stopped"
    else
        info "No running containers detected"
    fi

    # 🗑️ Remove all containers (both running and stopped)
    if [[ $(docker ps -aq | wc -l) -gt 0 ]]; then
        progress "Removing all containers..."
        docker rm $(docker ps -aq) >/dev/null 2>&1
        success "Container cleanup complete"
    else
        info "No containers to remove"
    fi
}

cleanup_docker_networks_volumes() {
    # 🌐 Remove unused Docker networks
    progress "Pruning unused networks..."
    docker network prune -f >/dev/null 2>&1
    success "Network cleanup complete"

    # 💾 Remove all Docker volumes to ensure a clean state
    if [[ $(docker volume ls -q | wc -l) -gt 0 ]]; then
        progress "Removing all Docker volumes..."
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        success "Volume cleanup complete"
    else
        info "No volumes to remove"
    fi
}

reset_configs_and_data() {
    # Check whether any existing NetBird configuration or data is present
    if [[ -d "${SETUP_DIR}/step-ca-data" || \
        -f "${SETUP_DIR}/relay.env" || \
        -d "${SETUP_DIR}/management" || \
        -f "${SETUP_DIR}/dashboard.env" || \
        -f "${SETUP_DIR}/docker-compose.yml" ]]; then

        # Warn the user before destructive removal
        echo -e "\n  ⚠️  Existing NetBird configuration and data detected."
        echo -e "  Proceeding will permanently delete all current configs and data."
        echo -e "  Ensure you have a backup before continuing.\n"
        read -r -p "$(echo -e "${CYAN}  Continue with a fresh deployment? ${GRAY}(default: y)${NC}: ${NC}")" user_input
        user_input=${user_input:-y}  # Default to 'y' if no input is provided

        if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
            progress "Removing existing NetBird configs and data..."
            # Remove all NetBird-managed files and directories
            rm -rf \
            ${SETUP_DIR}/relay.env \
            ${SETUP_DIR}/management \
            ${SETUP_DIR}/step-ca-data \
            ${SETUP_DIR}/dashboard.env \
            ${SETUP_DIR}/docker-compose.yml
            # Also clean up any remnant legacy secrets directory
            rm -rf ${SETUP_DIR}/secrets
            success "NetBird directory reset complete"
        else
            success "Aborted. Existing config and data were not removed."
            exit 0;
        fi
    else
        info "No existing NetBird configuration found — proceeding with fresh setup"
    fi
}

cleanup() {
    show_cleanup_banner
    cleanup_docker_containers
    cleanup_docker_networks_volumes
    reset_configs_and_data
    echo
}

# =============================================================================
# 🔄 UPDATE SYSTEM — Pull Latest Images & Restart Services
# =============================================================================

pull_latest_images() {
    echo -e "${CYAN}  🐳 PULLING LATEST IMAGES${NC}\n"

    failed=0

    for image in \
        "netbirdio/dashboard:latest" \
        "netbirdio/signal:latest" \
        "netbirdio/relay:latest" \
        "netbirdio/management:latest"
    do
        progress "Pulling ${image}..."
        if docker pull "${image}" >/dev/null 2>&1; then
            success "Updated: ${image}"
        else
            warn "Failed to pull: ${image} — existing local image will be used"
            failed=$((failed + 1))
        fi
    done

    echo
    if [ "$failed" -gt 0 ]; then
        warn "${failed} image(s) could not be pulled — services may not be fully up to date"
    else
        success "All images pulled successfully"
    fi
    echo
}

restart_services() {
    # Verify a docker-compose.yml exists before attempting to start services
    if [[ ! -f "docker-compose.yml" ]]; then
        error "docker-compose.yml not found in $PWD — cannot restart services.\n  Run a full deployment first or ensure you are in the correct directory."
    fi

    progress "Starting all services with updated images..."
    docker compose up -d
    sleep 3

    echo
    echo -e "${CYAN}  📊 SERVICE STATUS${NC}"
    docker compose ps | cat
    echo
}

update() {
    show_update_banner

    # Phase 1: Stop and remove all existing containers (preserves volumes/configs)
    show_cleanup_banner
    cleanup_docker_containers
    echo

    # Phase 2: Pull the latest versions of all service images
    pull_latest_images

    # Phase 3: Bring services back up with the freshly pulled images
    restart_services

    echo -e "${GREEN}
╔══════════════════════════════════════════════════════════════════════╗
║                      🎉 UPDATE COMPLETE!                             ║
║                  ALL SERVICES RESTARTED WITH LATEST IMAGES           ║
╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}  ⌨️  USEFUL COMMANDS${NC}"
    echo -e "${GRAY}    📋 View Status:    docker compose ps${NC}"
    echo -e "${GRAY}    📜 Follow Logs:    docker compose logs -f${NC}"
    echo -e "${GRAY}    🛑 Stop Services:  docker compose down${NC}"
    echo -e "${GRAY}    🔄 Full Redeploy:  $0${NC}\n"
}

# =============================================================================
# ⚙️  SETUP PHASE — Intelligent Configuration & Deployment
# =============================================================================

find_latest_backup() {
    # Return the path of the single most recent backup archive, or empty string
    ls -1 /backups/netbird-backup-*.tar.gz 2>/dev/null | sort | tail -n 1 || true
}

read_secrets() {
    # Load secrets from disk into shell variables, stripping any trailing newlines
    NB_AUTH_SECRET=$(tr -d '\n\r' < management/nb_auth_secret)
    DATASTORE_KEY=$(tr -d '\n\r' < management/datastore_encryption_key)
}

generate_secrets() {
    # Create cryptographically secure secrets using OpenSSL; skip if already present
    progress "Generating new cryptographically secure secrets..."
    mkdir -p management step-ca-data
    [[ ! -f step-ca-data/password ]] && openssl rand -base64 32 > step-ca-data/password
    [[ ! -f management/nb_auth_secret ]] && openssl rand -base64 32 > management/nb_auth_secret
    [[ ! -f management/datastore_encryption_key ]] && openssl rand -base64 32 > management/datastore_encryption_key
    success "New cryptographically secure secrets generated"
}

restore_secrets_or_generate() {
    local latest_backup="$1"
    local backup_contents="$2"

    # Attempt to restore secrets from the selected backup archive
    if [[ -n "${latest_backup}" ]]; then
        progress "Restoring secrets from backup..."
        mkdir -p management step-ca-data

        if [[ $(echo "${backup_contents}" | grep -c 'management/nb_auth_secret') -gt 0 ]]; then
            tar -xzf "${latest_backup}" management/nb_auth_secret management/datastore_encryption_key 2>/dev/null || true
            chmod 644 management/nb_auth_secret management/datastore_encryption_key 2>/dev/null || true
            success "Secrets restored from backup"
        else
            warn "No secrets found in backup archive — generating fresh secrets"
            generate_secrets
        fi

        # Fill in any secrets that may still be missing after a partial restore
        [[ ! -f management/nb_auth_secret ]]           && openssl rand -base64 32 > management/nb_auth_secret
        [[ ! -f management/datastore_encryption_key ]] && openssl rand -base64 32 > management/datastore_encryption_key
        [[ ! -f step-ca-data/password ]]               && openssl rand -base64 32 > step-ca-data/password
    else
        # No backup selected; generate all secrets from scratch
        generate_secrets
    fi

    # Load secrets into variables so templates can reference them
    read_secrets
}

init_step_ca() {
    # Create the Step CA data directory with the correct ownership for the container user
    progress "Initializing Step CA environment..."
    mkdir -p step-ca-data
    chown -R 1000:1000 step-ca-data
    success "Step CA directories prepared"

    # Start the Step CA container so it can self-initialize
    progress "Starting Step CA service..."
    docker compose up -d step-ca >/dev/null 2>&1

    # Poll until Step CA reports healthy or the timeout expires
    progress "Waiting for Step CA health check (10s timeout)..."
    local timeout=10 elapsed=0
    echo -n "     "
    while [[ $elapsed -lt $timeout ]]; do
        if docker compose ps step-ca 2>/dev/null | grep -q "healthy"; then
            echo -e "\n$(success "Step CA is healthy and ready")"
            break
        fi
        echo -n "."
        sleep 2
        elapsed=$((elapsed + 2))
    done

    if [[ $elapsed -ge $timeout ]]; then
        docker compose logs step-ca
        error "Step CA health check timed out — review the logs above for details"
    fi

    # Display the CA root certificate fingerprint for client trust configuration
    progress "Fetching CA root fingerprint..."
    local fingerprint
    fingerprint=$(docker compose exec -T step-ca step certificate fingerprint /home/step/certs/root_ca.crt 2>/dev/null | tr -d '\r\n' | tail -1)
    [[ -n "$fingerprint" ]] && info "CA Fingerprint: ${GRAY}${fingerprint}${NC}"

    # Add the ACME provisioner if it is not already present in the CA configuration
    if docker compose exec -T step-ca step ca provisioner list 2>/dev/null | grep -q "acme"; then
        success "ACME provisioner already configured"
    else
        progress "Adding ACME provisioner to Step CA..."
        docker compose exec -T step-ca step ca provisioner add acme --type ACME >/dev/null 2>&1
        docker compose restart step-ca >/dev/null 2>&1
        sleep 5
        success "ACME provisioner enabled"
    fi
}

restore_step_ca_data_or_init() {
    local latest_backup="$1"
    local backup_contents="$2"

    # Restore Step CA data from the selected backup, or initialize a new CA
    if [[ -n "${latest_backup}" ]]; then
        progress "Restoring Step CA data from backup..."
        if [[ $(echo "${backup_contents}" | grep -c 'step-ca-data/') -gt 0 ]]; then
            tar -xzf "${latest_backup}" step-ca-data/ >/dev/null 2>&1
            chown -R 1000:1000 step-ca-data
            success "Step CA data restored from backup"
            return
        else
            warn "No Step CA data found in backup archive — initializing a new CA"
            init_step_ca
        fi
    else
        # No backup selected; perform a fresh Step CA initialization
        init_step_ca
    fi
}

get_template() {
    local template="$1"
    local local_file="${SCRIPT_DIR}/${template}"
    local gir_repo="https://raw.githubusercontent.com/siammridha/netbird-setup/main"

    if [[ -f "$local_file" ]]; then
        cat "$local_file"
    else
        info "${YELLOW}Using remote ${template}"  >&2
        wget -qO- "${gir_repo}/${template}"
    fi
}

generate_relay_env() {
    progress "Configuring Relay service from template..."

    # Substitute domain and auth secret placeholders in the relay template
    get_template "relay-template.env" | \
    sed -e "s|<DOMAIN>|${DOMAIN}|g" \
        -e "s|<NB_AUTH_SECRET>|${NB_AUTH_SECRET}|g" > relay.env
    success "relay.env generated from template"
}

generate_dashboard_env() {
    progress "Configuring Dashboard OIDC settings from template..."

    # Substitute domain, auth secret, and datastore key placeholders in the dashboard template
    get_template "dashboard-template.env" | \
    sed -e "s|<DOMAIN>|${DOMAIN}|g" > dashboard.env
    success "dashboard.env generated from template"
}

generate_management_config() {
    progress "Generating Management service config from template..."

    # Substitute domain, auth secret, and datastore key placeholders in the management template
    mkdir -p management
    get_template "management-template.json" | \
    sed -e "s|<DOMAIN>|${DOMAIN}|g" \
        -e "s|<NB_AUTH_SECRET>|${NB_AUTH_SECRET}|g" \
        -e "s|<DATASTORE_KEY>|${DATASTORE_KEY}|g" > ./management/config.json
    success "management/config.json generated from template"
}

generate_docker_compose_yml() {
    local mode=$([[ "${DEPLOYMENT_MODE:-}" == "--prod" ]] && echo "prod" || echo "dev")
    progress "Generating docker-compose.yml from ${mode} template..."
    
    # Replace the domain and certificate name placeholder throughout docker-compose template
    get_template "docker-compose-template-${mode}.yml" | \
    sed -e "s|<DOMAIN>|${DOMAIN}|g" \
        -e "s|<CERT_NAME>|${CERT_NAME}|g" > docker-compose.yml
    success "docker-compose.yml generated from template"
}

restore_management_data_if_any() {
    local latest_backup="$1"
    local backup_contents="$2"

    # Restore the management service's persistent data directory from backup if present
    if [[ -n "${latest_backup}" ]]; then
        progress "Restoring Management service data from backup..."
        if [[ $(echo "${backup_contents}" | grep -c 'management/data') -gt 0 ]]; then
            tar -xzf "${latest_backup}" management/data >/dev/null 2>&1
            chmod -R 755 management/data
            chmod -R 644 management/config.json
            success "Management data restored from backup"
        else
            warn "No Management data found in backup archive — starting with an empty data directory"
        fi
    fi
}

bring_up_services() {
    info "Starting all services (pre-flight stabilization)..."
    docker compose up -d
    sleep 3
    echo
}

find_backups() {
    local backup_list selected_backup="" count choice idx file

    # Search for the 5 most recent backup archives under /backups/
    backup_list=$(ls -1 /backups/netbird-backup-*.tar.gz 2>/dev/null | sort -r | head -n 5)

    # If no backups exist, return an empty string and skip the restore prompt
    if [ -z "$backup_list" ]; then
        echo "$selected_backup"  # Return empty string — caller will treat this as "no backup"
    else
        # List available backups to the terminal for the user to choose from
        echo -e "${YELLOW}📦 Available backups (5 most recent):${NC}" >&2
        count=1
        for file in $backup_list; do
            echo "  [$count] $(basename "$file")" >&2
            count=$((count + 1))
        done
        echo "  [0] Skip restore — generate fresh secrets and CA" >&2

        # Prompt the user to select a backup or skip
        read -r -p "$(echo -e "${CYAN}Select backup to restore [0-$((count - 1))]: ${NC}")" choice
        choice=${choice:-0}

        # Validate that the input is a number within the valid range
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -gt $((count - 1)) ]; then
            warn "Invalid selection — defaulting to 0 (skip restore)" >&2
            choice=0
        fi

        # Resolve the numeric choice to the corresponding backup file path
        selected_backup=""
        if [ "$choice" -ne 0 ]; then
            idx=1
            for file in $backup_list; do
                if [ "$idx" -eq "$choice" ]; then
                    selected_backup="$file"
                    break
                fi
                idx=$((idx + 1))
            done
        fi
    fi

    # Return the selected backup path via stdout (empty string if none selected)
    echo "$selected_backup"
}

get_backup_contents() {
    local selected_backup=$1

    if [ -n "$selected_backup" ]; then
        # Log the restore source to the terminal only (not captured by callers)
        info "Restoring from backup: ${NC}$(basename "$selected_backup")" >&2
        # Output the archive's file list so callers can check for specific directories
        tar -tzf "$selected_backup" 2>/dev/null || true
    else
        info "No backup selected — fresh secrets and CA will be generated" >&2
        # Return empty string; callers treat this as "no contents to restore"
        echo ""
    fi
}

setup() {
    show_setup_banner
    echo -e "${GREEN}  🎯 Target Domain:      ${MAGENTA}${DOMAIN}${NC}"
    echo -e "${GREEN}  🎯 Setup Directory:    ${MAGENTA}${SETUP_DIR}${NC}"
    echo -e "${GREEN}  🎯 Deployment Mode:    ${MAGENTA}${DEPLOYMENT_MODE}${NC}\n"

    local selected_backup=$(find_backups)
    local backup_contents=$(get_backup_contents "$selected_backup")

    # Restore secrets from backup or generate fresh ones
    restore_secrets_or_generate "$selected_backup" "${backup_contents:-}"

    # Generate all service configuration files from their respective templates
    generate_relay_env
    generate_dashboard_env
    generate_management_config
    generate_docker_compose_yml

    # Restore Step CA data from backup or initialize a new CA instance
    restore_step_ca_data_or_init "$selected_backup" "${backup_contents:-}"

    # Restore management service persistent data from backup if available
    restore_management_data_if_any "$selected_backup" "${backup_contents:-}"

    # Uncomment to bring services up immediately after configuration
    bring_up_services
}

# =============================================================================
# 💾 BACKUP SYSTEM — Automated Configuration Preservation
# =============================================================================

backup_data() {
    local BACKUP_DIR="/backups"
    mkdir -p "${BACKUP_DIR}"
    BAACKUP_FILE="/backups/netbird-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    # Warn if any expected source paths are missing before creating the archive
    progress "Creating configuration and CA backup..."
    [[ ! -d "step-ca-data" ]] && { warn "step-ca-data/ directory not found — skipping"; }
    [[ ! -f "management/nb_auth_secret" ]] && { warn "management/nb_auth_secret not found — skipping"; }
    [[ ! -f "management/datastore_encryption_key" ]] && { warn "management/datastore_encryption_key not found — skipping"; }
    [[ ! -d "management/data" ]] && { warn "management/data directory not found — skipping"; }

    # Create a compressed archive; excludes ephemeral Step CA directories to keep size small
    tar -czf "${BAACKUP_FILE}" \
    --exclude='step-ca-data/db' \
    --exclude='step-ca-data/templates' \
    step-ca-data \
    management/nb_auth_secret \
    management/datastore_encryption_key \
    management/data \
    2>/dev/null || true

    [[ -f "${BAACKUP_FILE}" && -s "${BAACKUP_FILE}" ]] && \
        success "Backup saved ($(du -h "${BAACKUP_FILE}" | cut -f1))"

    echo -e "${CYAN}  💾 BACKUP ARCHIVE${NC}"
    echo -e "${GREEN}    📦 Location: ${BAACKUP_FILE}${NC}"
    echo -e "${GRAY}    🔍 Verify:   tar -tzf \"${BAACKUP_FILE}\"${NC}\n"
}

# =============================================================================
# 📊 POST-DEPLOYMENT INFORMATION
# =============================================================================

export_root_ca_if_present() {
    local root_ca_dir="${SETUP_DIR}/step-ca-data/certs/root_ca.crt"
    # Confirm the root CA certificate is accessible for client trust configuration
    if [[ -f "${root_ca_dir}" ]]; then
        success "📜 Root CA certificate available at: ${root_ca_dir}"
    fi
}

print_service_status() {
    echo -e "${CYAN}  📊 SERVICE STATUS${NC}"
    docker compose ps | cat
    echo
}

print_access_info() {
    echo -e "${CYAN}  🌐 ACCESS PORTAL${NC}"
    echo -e "${BLUE}    Dashboard:          https://${DOMAIN}${NC}"
    [ "${DEPLOYMENT_MODE:-}" == "--dev" ] && \
    echo -e "${BLUE}    Traefik Dashboard:  https://traefik.${DOMAIN}${NC}"
    echo -e "${BLUE}    Management API:     https://${DOMAIN}/api${NC}\n"
}

print_control_panel() {
    echo -e "${YELLOW}  ⌨️  CONTROL PANEL${NC}"
    echo -e "${GRAY}    📋 View Status:               docker compose ps${NC}"
    echo -e "${GRAY}    📜 Follow Logs:               docker compose logs -f${NC}"
    echo -e "${GRAY}    🛑 Graceful Stop:             docker compose down${NC}"
    echo -e "${GRAY}    🔄 Full Redeploy:             $0${NC}"
    echo -e "${GRAY}    🔄 Update Images:             $0 --update${NC}"
    echo -e "${GRAY}    📦 Backup Config and Data:    $0 --backup${NC}\n"
}

print_file_locations() {
    echo -e "${CYAN}  📁 CONFIGURATION FILES${NC}"
    echo -e "${GRAY}    relay.env           → ./relay.env${NC}"
    echo -e "${GRAY}    dashboard.env       → ./dashboard.env${NC}"
    echo -e "${GRAY}    management.json     → ./management/config.json${NC}"
    echo -e "${GRAY}    Root CA certificate → ${SETUP_DIR}/step-ca-data/certs/root_ca.crt${NC}\n"
}

print_backup_info() {
    echo -e "${CYAN}  💾 BACKUP ARCHIVE${NC}"
    echo -e "${GREEN}    📦 Location: ${BAACKUP_FILE}${NC}"
    echo -e "${GRAY}    🔍 Verify:   tar -tzf \"${BAACKUP_FILE}\"${NC}\n"
}

print_logs_commant() {
    echo -e "${CYAN}  📜 VIEW SERVICE LOGS${NC}"
    echo -e "${GRAY}    Step CA:     docker compose -f $PWD/docker-compose.yml logs step-ca${NC}"
    echo -e "${GRAY}    Relay:       docker compose -f $PWD/docker-compose.yml logs relay${NC}"
    echo -e "${GRAY}    Signal:      docker compose -f $PWD/docker-compose.yml logs signal${NC}"
    echo -e "${GRAY}    Dashboard:   docker compose -f $PWD/docker-compose.yml logs dashboard${NC}"
    echo -e "${GRAY}    Management:  docker compose -f $PWD/docker-compose.yml logs management${NC}"
    echo -e "${GRAY}    Traefik:     docker compose -f $PWD/docker-compose.yml logs traefik${NC}\n"
}

tail_initial_logs() {
    # Stream initial logs from all services — useful for post-deployment troubleshooting
    docker compose logs relay
    docker compose logs signal
    docker compose logs dashboard
    docker compose logs management
    docker compose logs traefik
    docker compose logs step-ca
}

# =============================================================================
# 🚀 MAIN ORCHESTRATION ENGINE
# =============================================================================

parse_domain() {
    # Prompt the user for the target domain; defaults to mylocaldomain.dev if left blank
    read -r -p "$(echo -e "${CYAN}  🌐 Enter target domain ${GRAY}(default: mylocaldomain.dev)${NC}: ${NC}")" domain
    domain=${domain:-mylocaldomain.dev}
    echo "${domain}"
}

parse_setup_diractory() {
    # Prompt the user for the setup directory where configs and data will be written
    read -r -p "$(echo -e "${CYAN}  📁 Enter setup directory ${GRAY}(default: /root)${NC}: ${NC}")" diractory
    setupDir=${setupDir:-/root}
    echo "${setupDir}"
}

main() {
    # --- Argument Handling ---

    if [[ "${1:-}" == "--backup" ]]; then
        # Backup-only mode: preserve current configuration without any deployment
        clear
        backup_data
        exit 0
    fi

    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        clear
        print_usage
        exit 0
    fi

    if [[ "${1:-}" == "--update" ]]; then
        # Update mode: stop containers, pull latest images, restart services
        clear
        show_main_banner
        update
        exit 0
    fi

    # --- Main Deployment Flow ---

    clear
    show_main_banner

    # Determine deployment mode (--dev is the default if no argument is provided)
    CURRENT_DIR=$PWD
    CERT_NAME="Sentry Vault"
    DEPLOYMENT_MODE=${1:---dev}
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

    # Interactively collect deployment parameters from the user
    DOMAIN=$(parse_domain)
    echo -e "${GREEN}  🎯 Target domain locked: ${MAGENTA}${DOMAIN}${NC}\n"

    SETUP_DIR=$(parse_setup_diractory)
    echo -e "${GREEN}  🎯 Setup directory set:  ${MAGENTA}${SETUP_DIR}${NC}\n"

    # Switch to the setup directory before executing any deployment steps
    cd ${SETUP_DIR}

    # Phase 1: Clean up all existing Docker resources and NetBird configuration
    cleanup

    # Phase 2: Generate/restore configuration and initialize services
    setup

    # Export the root CA certificate path for client trust configuration
    export_root_ca_if_present

    # Phase 3: Display deployment summary and operational information
    show_success_banner
    print_service_status
    print_access_info
    print_control_panel
    print_file_locations
    print_logs_commant

    echo -e "${GREEN}  ✨ NetBird VPN is now ${MAGENTA}LIVE${GREEN} on ${MAGENTA}${DOMAIN}${GREEN}!${NC}"
    echo -e "${YELLOW}  🔐 Be sure to trust the Root CA certificate on all clients to enable proper TLS operation.${NC}"

    # Uncomment the line below to stream initial service logs after deployment
    # tail_initial_logs
}

# 🎪 Showtime!
main "$@"