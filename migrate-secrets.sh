#!/bin/sh
#
# ╔══════════════════════════════════════════════════════════════════════╗
# ║                    🔐 NETBIRD SECRETS MIGRATOR                       ║
# ║          Migrate from legacy secrets/ layout to current layout       ║
# ╚══════════════════════════════════════════════════════════════════════╝
#
# 🎯 PURPOSE
# ==========
# One-time migration script that moves NetBird secrets from the legacy
# centralised secrets/ directory to their new canonical locations:
#
#   BEFORE (legacy)                    AFTER (current)
#   ─────────────────────────────────  ──────────────────────────────────
#   secrets/nb_auth_secret          →  management/nb_auth_secret
#   secrets/datastore_encryption_key→  management/datastore_encryption_key
#   secrets/step_ca_password        →  step-ca-data/password
#   secrets/                        →  (removed)
#
# 📋 USAGE
# ========
#   ./migrate-secrets.sh                       # Run from the setup directory
#   ./migrate-secrets.sh /path/to/setup/dir    # Specify setup directory
#
# ⚠️  PREREQUISITES
# =================
#   Run from — or pass as an argument — the NetBird setup directory that
#   contains the legacy secrets/ folder. Docker containers do NOT need to
#   be stopped before running; no container config is modified.
#
# 🛡️  SAFETY
# ==========
#   • Dry-run validation before any file is touched
#   • Refuses to overwrite files that already exist at the target paths
#   • Refuses to proceed if any source file is missing
#   • Removes secrets/ only after ALL three files have been moved
#   • Non-destructive on any error — exits immediately (set -euo pipefail)
#
set -euo pipefail

# =============================================================================
# 🌈 COLOUR HELPERS
# =============================================================================

readonly GREEN='\033[1;32m'
readonly BLUE='\033[1;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m'

info()    { echo -e "${BLUE}  ➜ $1${NC}"; }
success() { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}  ⓘ  $1${NC}"; }
error()   { echo -e "${RED}  ❌ CRITICAL: $1${NC}"; exit 1; }

# =============================================================================
# 🔍 PRE-FLIGHT CHECKS
# =============================================================================

preflight_checks() {
    local setup_dir="$1"

    info "Checking setup directory: ${setup_dir}"

    # ── Source files must all be present ──────────────────────────────────────
    local missing=0
    for src_file in \
        "${setup_dir}/secrets/nb_auth_secret" \
        "${setup_dir}/secrets/datastore_encryption_key" \
        "${setup_dir}/secrets/step_ca_password"
    do
        if [[ ! -f "${src_file}" ]]; then
            warn "Missing source file: ${src_file}"
            missing=$((missing + 1))
        fi
    done

    if [[ "${missing}" -gt 0 ]]; then
        error "${missing} source file(s) not found in secrets/. Is this the correct setup directory?"
    fi

    success "All source files present in secrets/"

    # ── Target paths must NOT already exist ───────────────────────────────────
    local conflicts=0
    for target_file in \
        "${setup_dir}/management/nb_auth_secret" \
        "${setup_dir}/management/datastore_encryption_key" \
        "${setup_dir}/step-ca-data/password"
    do
        if [[ -f "${target_file}" ]]; then
            warn "Target already exists: ${target_file}"
            conflicts=$((conflicts + 1))
        fi
    done

    if [[ "${conflicts}" -gt 0 ]]; then
        error "${conflicts} target file(s) already exist. Migration may have already been run, or files were placed manually. Aborting to avoid data loss."
    fi

    success "No conflicts at target locations"

    # ── Destination directories must exist (step-ca-data is required by step-ca) ─
    if [[ ! -d "${setup_dir}/management" ]]; then
        error "management/ directory not found in ${setup_dir}. Ensure NetBird has been set up before running this migration."
    fi

    if [[ ! -d "${setup_dir}/step-ca-data" ]]; then
        error "step-ca-data/ directory not found in ${setup_dir}. Ensure Step CA has been initialised before running this migration."
    fi

    success "Destination directories confirmed"
}

# =============================================================================
# 🚚 MIGRATION
# =============================================================================

migrate() {
    local setup_dir="$1"

    info "Moving secrets/nb_auth_secret           → management/nb_auth_secret"
    mv "${setup_dir}/secrets/nb_auth_secret" \
       "${setup_dir}/management/nb_auth_secret"
    chmod 644 "${setup_dir}/management/nb_auth_secret"
    success "nb_auth_secret moved"

    info "Moving secrets/datastore_encryption_key → management/datastore_encryption_key"
    mv "${setup_dir}/secrets/datastore_encryption_key" \
       "${setup_dir}/management/datastore_encryption_key"
    chmod 644 "${setup_dir}/management/datastore_encryption_key"
    success "datastore_encryption_key moved"

    info "Moving secrets/step_ca_password         → step-ca-data/password"
    mv "${setup_dir}/secrets/step_ca_password" \
       "${setup_dir}/step-ca-data/password"
    chmod 644 "${setup_dir}/step-ca-data/password"
    success "step_ca_password moved (renamed to password)"

    # All three files are safely at their new locations — remove the now-empty directory
    info "Removing empty secrets/ directory..."
    rmdir "${setup_dir}/secrets" 2>/dev/null \
        || warn "secrets/ is not empty — check for unexpected files and remove it manually"
    success "secrets/ directory removed"
}

# =============================================================================
# 🚀 MAIN
# =============================================================================

main() {
    echo -e "${CYAN}
╔══════════════════════════════════════════════════════════════════════╗
║                    🔐 NETBIRD SECRETS MIGRATOR                       ║
╚══════════════════════════════════════════════════════════════════════╝${NC}"

    # Resolve the setup directory — default to current working directory
    local setup_dir="${1:-$PWD}"
    setup_dir="$(cd "${setup_dir}" && pwd)"  # Convert to absolute path

    echo -e "${CYAN}  📁 Setup directory: ${GRAY}${setup_dir}${NC}\n"

    preflight_checks "${setup_dir}"

    echo
    echo -e "${YELLOW}  The following files will be moved:${NC}"
    echo -e "${GRAY}    secrets/nb_auth_secret           → management/nb_auth_secret${NC}"
    echo -e "${GRAY}    secrets/datastore_encryption_key → management/datastore_encryption_key${NC}"
    echo -e "${GRAY}    secrets/step_ca_password         → step-ca-data/password${NC}"
    echo -e "${GRAY}    secrets/                         → (removed when empty)${NC}"
    echo

    read -r -p "$(echo -e "${CYAN}  Proceed with migration? [y/N]: ${NC}")" confirm
    confirm="${confirm:-N}"

    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        info "Migration cancelled — no files were changed."
        exit 0
    fi

    echo
    migrate "${setup_dir}"

    echo -e "${GREEN}
╔══════════════════════════════════════════════════════════════════════╗
║                    🎉 MIGRATION COMPLETE!                             ║
╚══════════════════════════════════════════════════════════════════════╝${NC}"

    echo -e "${YELLOW}  ⚠️  Next steps:${NC}"
    echo -e "${GRAY}    1. Update your docker-compose.yml secrets block:${NC}"
    echo -e "${GRAY}       secrets:${NC}"
    echo -e "${GRAY}         step_ca_password:${NC}"
    echo -e "${GRAY}           file: ./step-ca-data/password   # was: ./secrets/step_ca_password${NC}"
    echo -e "${GRAY}    2. Restart containers to pick up the new secret path:${NC}"
    echo -e "${GRAY}       docker compose down && docker compose up -d${NC}"
    echo -e "${GRAY}    3. Run a backup to capture the new layout:${NC}"
    echo -e "${GRAY}       ./netbird-deploy.sh --backup${NC}"
    echo
}

main "$@"