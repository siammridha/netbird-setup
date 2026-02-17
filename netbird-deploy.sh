#!/bin/sh
#
# ╔══════════════════════════════════════════════════════════════════════╗
# ║                           🌐 NETBIRD DEPLOYER                        ║
# ║                Complete Self-Hosted VPN Solution                     ║
# ║  Step CA + Traefik + Embedded OIDC + Management + Signal + Relay     ║
# ╚══════════════════════════════════════════════════════════════════════╝
# 
# 🎯 PURPOSE
# ==========
# Automates complete cleanup, secure setup, and deployment of NetBird 
# self-hosted VPN platform with Step CA certificate authority, Traefik 
# reverse proxy, and embedded OIDC identity provider for Zero Trust access.
#
# ✨ FEATURES
# ===========
# ├─ 🧹 Complete Docker cleanup (containers/volumes/networks)
# ├─ 🔐 Generates cryptographically secure random secrets
# ├─ 📜 Step CA with ACME provisioner for automated certs
# ├─ 🚀 Deploys Management Service, Signal, Relay, Dashboard
# ├─ 🌍 Interactive domain configuration with default option
# ├─ 💾 Smart backup/restore from top 5 most recent backups
# ├─ 🔄 Template-based configuration generation (dev/prod modes)
# ├─ 🎨 Real-time colored progress with spinners & status
# ├─ 📊 Post-deployment access info & management commands
# └─ 🗂️ Backup-only mode for preserving existing configurations
#
# 🛠️ PREREQUISITES
# ================
# ├─ Docker + Docker Compose v2+
# ├─ Required path: alpine_vm/net_bird/
# ├─ Root/sudo privileges for dir operations
# ├─ Public domain with DNS A record pointing to server
# └─ Template files: relay-template.env, dashboard-template.env, 
#                    management-template.json, docker-compose-template-dev.yml,
#                    docker-compose-template-prod.yml
#
# 📋 USAGE
# ========
#   ./netbird-deployer.sh                   # Interactive mode (prompts for domain)
#   ./netbird-deployer.sh --dev             # Deploy with dev template (default)
#   ./netbird-deployer.sh --prod            # Deploy with production template
#   ./netbird-deployer.sh --backup          # Backup existing configuration only
#   ./netbird-deployer.sh --help            # Show usage information
#
# 🔄 DEPLOYMENT MODES
# ===================
#   --dev   : Uses docker-compose-template-dev.yml (default behavior)
#   --prod  : Uses docker-compose-template-prod.yml for production deployment
#
# 💾 BACKUP & RESTORE
# ===================
#   During deployment, script will:
#   ├─ Search for the 5 most recent backups in /backups/
#   ├─ Allow user to select a backup to restore from (or skip)
#   ├─ Restore secrets/, step-ca-data/, and management/data if available
#   └─ Generate fresh secrets and CA if no backup selected
#
#   Backups include:
#   ├─ secrets/ (nb_auth_secret, datastore_encryption_key, step_ca_password)
#   ├─ step-ca-data/ (CA certificates and configuration)
#   └─ management/data (management service persistent data)
#
# 🏷️ METADATA
# ===========
# Author: NetBird Deployment Engineering Team
# Version: 2.0 - Enhanced UI/UX Edition
# License: MIT
#
set -euo pipefail # 🚫 Exit on any error, undefined vars, or pipe failures
# =============================================================================
# 🌈 TERMINAL BEAUTIFICATION & LOGGING SYSTEM
# =============================================================================
# ANSI Extended Color Palette
readonly GREEN='\033[1;32m'      # Success ✓ Bright Green
readonly BLUE='\033[1;34m'       # Info ➜ Bright Blue  
readonly YELLOW='\033[1;33m'     # Warning ⚠ Bright Yellow
readonly RED='\033[1;31m'        # Error ✗ Bright Red
readonly CYAN='\033[1;36m'       # Highlight 🔍 Bright Cyan
readonly MAGENTA='\033[1;35m'    # Domain 🌐 Bright Magenta
readonly PURPLE='\033[0;35m'     # Progress ▓ Bright Purple
readonly GRAY='\033[0;37m'       # Subtle ─ Dim Gray
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
  $0                         ${GRAY}# Interactive deployment (prompts for domain)${NC}

${GREEN}DEPLOYMENT MODES:${NC}
  $0 --dev                   ${GRAY}# Deploy with development template (default)${NC}
  $0 --prod                  ${GRAY}# Deploy with production template${NC}

${GREEN}UTILITY COMMANDS:${NC}
  $0 --backup                ${GRAY}# Create backup of current configuration${NC}
  $0 --help                  ${GRAY}# Show this help message${NC}

${GREEN}WORKFLOW:${NC}
  1. Script prompts for domain name (default: mylocaldomain.dev)
  2. Shows available backups and allows selection or fresh install
  3. Performs cleanup of existing Docker resources
  4. Generates/restores secrets and configurations
  5. Deploys all services using selected template (dev/prod)
  6. Creates backup of new configuration

${GREEN}TEMPLATES:${NC}
  ${CYAN}--dev${NC}  → Uses docker-compose-template-dev.yml
  ${CYAN}--prod${NC} → Uses docker-compose-template-prod.yml

${GREEN}BACKUP LOCATION:${NC}
  /backups/netbird-backup-YYYYMMDD-HHMMSS.tar.gz

${GREEN}EXAMPLES:${NC}
  $0                         ${GRAY}# Interactive deployment${NC}
  $0 --prod                  ${GRAY}# Production deployment${NC}
  $0 --backup                ${GRAY}# Backup only${NC}
"
}
# =============================================================================
# 🧹 CLEANUP PHASE - Nuclear Docker Reset
# =============================================================================
cleanup_docker_containers() {
    info "Scanning Docker environment for cleanup..."
    # 🛑 Stop all containers gracefully
    if [[ $(docker ps -q | wc -l) -gt 0 ]]; then
        progress "Stopping all running containers..."
        docker stop $(docker ps -q) >/dev/null 2>&1
        success "✅ All containers gracefully stopped"
    else
        info "ℹ️  No running containers detected"
    fi
    # 🗑️ Remove all containers (running + stopped)
    if [[ $(docker ps -aq | wc -l) -gt 0 ]]; then
        progress "Removing all containers..."
        docker rm $(docker ps -aq) >/dev/null 2>&1
        success "✅ Container cleanup complete"
    else
        info "ℹ️  No containers to remove"
    fi
}
cleanup_docker_networks_volumes() {
    # 🌐 Clean networks
    progress "Pruning unused networks..."
    docker network prune -f >/dev/null 2>&1
    success "✅ Network cleanup complete"
    # 💾 Remove Docker volumes
    if [[ $(docker volume ls -q | wc -l) -gt 0 ]]; then
        progress "Removing all Docker volumes..."
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        success "✅ Volume cleanup complete"
    else
        info "ℹ️  No volumes to remove"
    fi
}
reset_configs_and_data() {
    # Check if config and data exist
    if [[ -d "${SETUP_DIR}/secrets" || \
        -f "${SETUP_DIR}/relay.env" || \
        -d "${SETUP_DIR}/management" || \
        -d "${SETUP_DIR}/step-ca-data" || \
        -f "${SETUP_DIR}/dashboard.env" || \
        -f "${SETUP_DIR}/docker-compose.yml" ]]; then
        # Ask user if they want to continue
        echo -e "\n  ⚠️  Existing Netbird configuration and data detected."
        echo -e "  Continuing will delete all current configs and data!"
        echo -e "  Make sure to backup any important data before proceeding."
        read -r -p "$(echo -e "${CYAN}  Do you want to continue with a fresh deploy? ${GRAY}(default: y)${NC}: ${NC}")" user_input
        user_input=${user_input:-y}  # Default to 'y' if no input is given

        if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
            progress "Removing existing netbird configs and data..."
            # Remove the config and data
            rm -rf \
            ${SETUP_DIR}/secrets \
            ${SETUP_DIR}/relay.env \
            ${SETUP_DIR}/management \
            ${SETUP_DIR}/step-ca-data \
            ${SETUP_DIR}/dashboard.env \
            ${SETUP_DIR}/docker-compose.yml
            success "✅ NetBird directory reset complete"
        else
            success "Aborting. The config and data were not removed."
            exit 0;
        fi
    else
        info "ℹ️  No existing netbird directory found"
        # Proceed with your script as usual if no config/data exists
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
# ⚙️  SETUP PHASE - Intelligent Configuration & Deployment
# =============================================================================
find_latest_backup() {
    ls -1 /backups/netbird-backup-*.tar.gz 2>/dev/null | sort | tail -n 1 || true
}
read_secrets() {
    NB_AUTH_SECRET=$(tr -d '\n\r' < secrets/nb_auth_secret)
    DATASTORE_KEY=$(tr -d '\n\r' < secrets/datastore_encryption_key)
}
generate_secrets() {
    # Generate new cryptographically secure secrets
    progress "🔐 Generating new cryptographically secure Secrets..."
    mkdir -p secrets
    [[ ! -f secrets/step_ca_password ]] && openssl rand -base64 32 > secrets/step_ca_password
    [[ ! -f secrets/nb_auth_secret ]] && openssl rand -base64 32 > secrets/nb_auth_secret
    [[ ! -f secrets/datastore_encryption_key ]] && openssl rand -base64 32 > secrets/datastore_encryption_key
    success "✅ New cryptographically secure secrets generated"
}
restore_secrets_or_generate() {
    local latest_backup="$1"
    local backup_contents="$2"
    # Restore secrets from backup if available
    if [[ -n "${latest_backup}" ]]; then
        progress "🔐 Restoring secrets from backup..."
        if [[ $(echo "${backup_contents}" | grep -c 'secrets/') -gt 0 ]]; then
            tar -xzf "${latest_backup}" secrets/ >/dev/null 2>&1
            success "✅ Secrets restored from backup"
        else
            warn "No Managsecretsement data found in backup archive"
            generate_secrets
        fi
    else
        generate_secrets
    fi
    # Read secrets into variables for template replacement
    read_secrets
}
init_step_ca() {
    # Initialize fresh Step CA if no backup
    progress "📁 Initializing Step CA environment..."
    sudo mkdir -p step-ca-data
    sudo chown -R 1000:1000 step-ca-data
    success "✅ Step CA directories prepared"
    progress "🚀 Starting Step CA service..."
    docker compose up -d step-ca >/dev/null 2>&1
    # Wait for Step CA to become healthy
    progress "⏳ Waiting for Step CA health check (10s timeout)..."
    local timeout=10 elapsed=0
    echo -n "     "
    while [[ $elapsed -lt $timeout ]]; do
        if docker compose ps step-ca 2>/dev/null | grep -q "healthy"; then
            echo -e "\n$(success "✅ Step CA healthy & ready")"
            break
        fi
        echo -n "."
        sleep 2
        elapsed=$((elapsed + 2))
    done
    if [[ $elapsed -ge $timeout ]]; then
        docker compose logs step-ca
        error "Step CA health check timeout - check logs above"
    fi
    # Fetch and display CA root fingerprint
    progress "🔑 Fetching CA root fingerprint..."
    local fingerprint
    fingerprint=$(docker compose exec -T step-ca step certificate fingerprint /home/step/certs/root_ca.crt 2>/dev/null | tr -d '\r\n' | tail -1)
    [[ -n "$fingerprint" ]] && info "CA Fingerprint: ${GRAY}${fingerprint}${NC}"
    # Configure ACME provisioner if not already present
    if docker compose exec -T step-ca step ca provisioner list 2>/dev/null | grep -q "acme"; then
        success "✅ ACME provisioner already configured"
    else
        progress "🔧 Adding ACME provisioner..."
        docker compose exec -T step-ca step ca provisioner add acme --type ACME >/dev/null 2>&1
        docker compose restart step-ca >/dev/null 2>&1
        sleep 5
        success "✅ ACME provisioner enabled"
    fi
}
restore_step_ca_data_or_init() {
    local latest_backup="$1"
    local backup_contents="$2"
    # Restore Step CA data from backup if available
    if [[ -n "${latest_backup}" ]]; then
        progress "📥 Restoring Step CA data from backup..."
        if [[ $(echo "${backup_contents}" | grep -c 'step-ca-data/') -gt 0 ]]; then
            tar -xzf "${latest_backup}" step-ca-data/ >/dev/null 2>&1
            success "✅ Step CA data restored from backup"
            return
        else
            warn "No Step CA data found in backup archive"
            init_step_ca
        fi
    else
        init_step_ca
    fi
}
generate_relay_env() {
    local realy_dir="${SCRIPT_DIR}/relay-template.env"
    progress "📡 Configuring Relay Service from template..."
    # Generate relay.env from relay-template.env
    if [[ -f ${realy_dir} ]]; then
        # Replace <DOMAIN> and <NB_AUTH_SECRET> with actual values
        sed -e "s|<DOMAIN>|${DOMAIN}|g" \
            -e "s|<NB_AUTH_SECRET>|${NB_AUTH_SECRET}|g" \
            ${realy_dir} > relay.env
        success "✅ relay.env generated from template"
    else
        error "${realy_dir} file not found!"
    fi
}
generate_dashboard_env() {
    local dashboard_dir="${SCRIPT_DIR}/dashboard-template.env"
    progress "📊 Configuring Dashboard OIDC from template..."
    # Generate dashboard.env from dashboard-template.env
    if [[ -f ${dashboard_dir} ]]; then
        # Replace <DOMAIN>, <NB_AUTH_SECRET>, and <DATASTORE_KEY> with actual values
        sed -e "s|<DOMAIN>|${DOMAIN}|g" \
            -e "s|<NB_AUTH_SECRET>|${NB_AUTH_SECRET}|g" \
            -e "s|<DATASTORE_KEY>|${DATASTORE_KEY}|g" \
            ${dashboard_dir} > dashboard.env
        success "✅ dashboard.env generated from template"
    else
        error "${dashboard_dir} file not found!"
    fi
}
generate_management_config() {
    local management_dir="${SCRIPT_DIR}/management-template.json"
    progress "🎛️  Generating Management Service config from template..."
    # Generate management/config.json from management-template.json
    if [[ -f ${management_dir} ]]; then
        mkdir -p management
        # Replace <DOMAIN>, <NB_AUTH_SECRET>, and <DATASTORE_KEY> with actual values
        sed -e "s|<DOMAIN>|${DOMAIN}|g" \
            -e "s|<NB_AUTH_SECRET>|${NB_AUTH_SECRET}|g" \
            -e "s|<DATASTORE_KEY>|${DATASTORE_KEY}|g" \
            ${management_dir} > ./management/config.json
        success "✅ management config.json generated from template"
    else
        error "${management_dir} file not found!"
    fi
}
restore_management_data_if_any() {
    local latest_backup="$1"
    local backup_contents="$2"
    # Restore management service data from backup if available
    if [[ -n "${latest_backup}" ]]; then
        progress "📥 Restoring Management data from backup..."
        if [[ $(echo "${backup_contents}" | grep -c 'management/data') -gt 0 ]]; then
            tar -xzf "${latest_backup}" management/data >/dev/null 2>&1
            success "✅ Management data restored from backup"
        else
            warn "No Management data found in backup archive"
        fi
    fi
}
select_docker_compose_template() {
    # Select docker-compose template based on deployment mode
    if [[ "${DEPLOYMENT_MODE:-}" == "--prod" ]]; then
        info "Using production docker-compose template"
        local prod_docker_compose="${SCRIPT_DIR}/docker-compose-template-prod.yml"
        if [[ -f "${prod_docker_compose}" ]]; then
            cp ${prod_docker_compose} docker-compose.yml
        else
            warn ""${prod_docker_compose}" not found"
        fi
    else
        info "Using development docker-compose template"
        local dev_docker_compose="${SCRIPT_DIR}/docker-compose-template-dev.yml"
        if [[ -f "${dev_docker_compose}" ]]; then
            cp ${dev_docker_compose} docker-compose.yml
        else
            warn ""${dev_docker_compose}" not found"
        fi
    fi
}
update_docker_compose_domain() {
    progress "🔄 Updating docker-compose.yml with domain..."
    # Replace <DOMAIN> placeholder in docker-compose.yml
    if [[ -f docker-compose.yml ]]; then
        sed -i "s|<DOMAIN>|${DOMAIN}|g" docker-compose.yml
        success "✅ Docker Compose updated"
    else
        warn "docker-compose.yml not found"
    fi
}
bring_up_services() {
    info "💤 Pre-flight service stabilization..."
    docker compose up -d
    sleep 3
    echo
}
find_backups() {
    local backup_list selected_backup count choice idx file

    # Search for the 5 most recent backups
    backup_list=$(ls -1 /backups/netbird-backup-*.tar.gz 2>/dev/null | sort -r | head -n 5)

    # If no backups found, return empty
    if [ -z "$backup_list" ]; then
        echo ""  # return empty string
    else
        # Display available backups **to terminal**, even if called via $()
        echo -e "${YELLOW}📦 Available backups (5 most recent):${NC}" >&2
        count=1
        for file in $backup_list; do
            echo "  [$count] $(basename "$file")" >&2
            count=$((count + 1))
        done
        echo "  [0] Skip restore / generate fresh secrets" >&2

        # Prompt user
        read -r -p "$(echo -e "${CYAN}Select backup to restore [0-$((count - 1))]: ${NC}")" choice
        choice=${choice:-0}

        # Validate input
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -gt $((count - 1)) ]; then
            warn "⚠️ Invalid selection, defaulting to 0 (skip restore)" >&2
            choice=0
        fi

        # Determine selected backup
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

    # Return the selected backup path via stdout
    echo "$selected_backup"
}

get_backup_contents() {
    local selected_backup=$1

    if [ -n "$selected_backup" ]; then
        # Info message to terminal only
        info "📥 Restoring from backup: ${NC}$(basename "$selected_backup")" >&2
        # List contents of the tar.gz archive, one per line
        tar -tzf "$selected_backup" 2>/dev/null || true
    else
        info "ℹ️  Skipping backup restore, generating fresh secrets & CA" >&2
        # Return empty string for contents
        echo ""
    fi
}


setup() {
    show_setup_banner
    echo -e "${GREEN}🎯 TARGET DOMAIN: ${NC}${DOMAIN}"
    echo -e "${GREEN}🎯 SETUP DIRACTORY: ${NC}${SETUP_DIR}"
    echo -e "${GREEN}🎯 DEPLOYMENT MODE: ${NC}${DEPLOYMENT_MODE}\n"
    
    local selected_backup=$(find_backups)
    local backup_contents=$(get_backup_contents "$selected_backup")
    # Restore or generate secrets
    restore_secrets_or_generate "$selected_backup" "${backup_contents:-}"
    # Generate configuration files from templates
    generate_relay_env
    generate_dashboard_env
    generate_management_config
    # Select the appropriate docker-compose template based on the deployment mode argument
    select_docker_compose_template
    update_docker_compose_domain
    # Initialize or restore Step CA
    restore_step_ca_data_or_init "$selected_backup" "${backup_contents:-}"
    # Restore management data if available
    restore_management_data_if_any "$selected_backup" "${backup_contents:-}"
    # Start all services
    # bring_up_services
}
# =============================================================================
# 💾 BACKUP SYSTEM - Automated CA Preservation
# =============================================================================
backup_data() {
    local BACKUP_DIR="/backups"
    mkdir -p "${BACKUP_DIR}"
    BAACKUP_FILE="/backups/netbird-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    # Verify directories exist before attempting backup
    progress "💾 Creating CA backup..."
    [[ ! -d "secrets" ]] && { warn "No secrets for backup"; }
    [[ ! -d "step-ca-data" ]] && { warn "No step-ca-data for backup"; }
    [[ ! -d "management/data" ]] && { warn "No management service data for backup"; }
    # Create compressed archive of secrets, step-ca-data, and management/data
    # Excludes step-ca-data/db and step-ca-data/templates to reduce size
    tar -czf "${BAACKUP_FILE}" \
    --exclude='step-ca-data/db' \
    --exclude='step-ca-data/secrets' \
    --exclude='step-ca-data/templates' \
    step-ca-data secrets management/data 2>/dev/null || true
    [[ -f "${BAACKUP_FILE}" && -s "${BAACKUP_FILE}" ]] && \
        success "✅ Backup saved ($(du -h "${BAACKUP_FILE}" | cut -f1))"
    echo -e "${CYAN}💾 BACKUP ARCHIVE${NC}"
    echo -e "${GREEN}  📦 Location: ${BAACKUP_FILE}${NC}"
    echo -e "${GRAY}  🔍 Verify:   tar -tzf \"${BAACKUP_FILE}\"${NC}\n"
}
# =============================================================================
# 📊 POST-DEPLOYMENT INFO
# =============================================================================
export_root_ca_if_present() {
    local root_ca_dir="${SETUP_DIR}/step-ca-data/certs/root_ca.crt"
    # Export root CA certificate to alpine_vm directory for easy access
    if [[ -f "${root_ca_dir}" ]]; then
        success "✅ Root CA certificate at: ${root_ca_dir}"
    fi
}
print_service_status() {
    echo -e "${CYAN}📊 SERVICE STATUS${NC}"
    docker compose ps | cat
    echo
}
print_access_info() {
    echo -e "${CYAN}🌐 ACCESS PORTAL${NC}"
    echo -e "${BLUE}  Dashboard:          https://${DOMAIN}${NC}"
    if [[ "${DEPLOYMENT_MODE:-}" == "--dev" ]]; then
        echo -e "${BLUE}  Traefik Dashboard:  https://traefik.${DOMAIN}${NC}"
    fi
    echo -e "${BLUE}  Management API:     https://${DOMAIN}/api${NC}\n"
}
print_control_panel() {
    echo -e "${YELLOW}⌨️  CONTROL PANEL${NC}"
    echo -e "${GRAY}  📋 View Status:               docker compose ps${NC}"
    echo -e "${GRAY}  📜 Follow Logs:               docker compose logs -f${NC}"
    echo -e "${GRAY}  🛑 Graceful Stop:             docker compose down${NC}"
    echo -e "${GRAY}  🔄 Full Redeploy:             $0${NC}"
    echo -e "${GRAY}  📦 Backup Config and Data:    $0 --backup${NC}\n"
}
print_file_locations() {
    echo -e "${CYAN}📁 CONFIGURATION FILES${NC}"
    echo -e "${GRAY}  relay.env          → ./relay.env${NC}"
    echo -e "${GRAY}  dashboard.env      → ./dashboard.env${NC}"
    echo -e "${GRAY}  management.json    → ./management/config.json${NC}\n"
}
print_backup_info() {
    echo -e "${CYAN}💾 BACKUP ARCHIVE${NC}"
    echo -e "${GREEN}  📦 Location: ${BAACKUP_FILE}${NC}"
    echo -e "${GRAY}  🔍 Verify:   tar -tzf \"${BAACKUP_FILE}\"${NC}\n"
}
print_logs_commant() {
    echo -e "${CYAN}📜 VIEW SERVICE LOGS${NC}"
    echo -e "${GRAY}  Step CA Logs:      → docker compose -f $PWD/docker-compose.yml logs step-ca${NC}"
    echo -e "${GRAY}  Relay Logs:        → docker compose -f $PWD/docker-compose.yml logs relay${NC}"
    echo -e "${GRAY}  Signal Logs:       → docker compose -f $PWD/docker-compose.yml logs signal${NC}"
    echo -e "${GRAY}  Dashboard Logs:    → docker compose -f $PWD/docker-compose.yml logs dashboard${NC}"
    echo -e "${GRAY}  Management Logs:   → docker compose -f $PWD/docker-compose.yml logs management${NC}"
    echo -e "${GRAY}  Traefik Logs:      → docker compose -f $PWD/docker-compose.yml logs traefik${NC}\n"
}
tail_initial_logs() {
    # Display initial logs from all services for troubleshooting
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
    # Prompt user to enter a domain (always interactive)
    read -r -p "$(echo -e "${CYAN}🌐 Enter domain ${GRAY}(default: mylocaldomain.dev)${NC}: ${NC}")" domain
    domain=${domain:-mylocaldomain.dev}  # Default to mylocaldomain.dev if user input is empty
    echo "${domain}"
}
parse_setup_diractory() {
    # Prompt user to enter a setup diractory (always interactive)
    read -r -p "$(echo -e "${CYAN}🌐 Enter setup diractory ${GRAY}(default: /root)${NC}: ${NC}")" diractory
    setupDir=${setupDir:-/root}  # Default to /root if user input is empty
    echo "${setupDir}"
}
main() {
    # Argument handling
    if [[ "${1:-}" == "--backup" ]]; then
        # Run backup only, no cleanup/deploy
        clear
        backup_data
        exit 0
    fi
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        clear
        print_usage
        exit 0
    fi
    # Main deployment flow
    clear
    show_main_banner
    # Always prompt for domain interactively
    DEPLOYMENT_MODE=${1:---dev}
    CURRENT_DIR=$PWD
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    DOMAIN=$(parse_domain)
    echo -e "${GREEN}🎯 Target Domain Locked: ${MAGENTA}${DOMAIN}${NC}\n"
    SETUP_DIR=$(parse_setup_diractory)
    echo -e "${GREEN}🎯 Setup diractory: ${MAGENTA}${SETUP_DIR}${NC}\n"

    #Execute deployment phases
    cd ${SETUP_DIR}
    cleanup
    setup  # Pass --dev or --prod to setup function
    # Export root CA certificate for client configuration
    export_root_ca_if_present
    # Display success and information
    show_success_banner
    print_service_status
    print_access_info
    print_control_panel
    print_file_locations
    print_logs_commant
    echo -e "${GREEN}✨ NetBird VPN platform is now${MAGENTA} LIVE ${GREEN}on ${MAGENTA}${DOMAIN}${NC}${GREEN}!${NC}"
    # Uncomment to display initial service logs
    # tail_initial_logs
}
# 🎪 Showtime!
main "$@"