#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

FORCE=false

usage() {
  cat <<EOF
Usage:
  $0 [--force]

Options:
  --force   Overwrite installed systemd service files if templates are present.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "bootstrap must be run as root, for example: sudo $0"
  fi
}

fix_executable_permissions() {
  local fixer="$ACM_REPO_ROOT/scripts/setup/acore-fix-permissions.sh"

  log "Checking script executable permissions"

  if [[ -f "$fixer" ]]; then
    bash "$fixer"
  else
    echo "WARN: permission helper is missing: $fixer"
  fi
}

install_packages() {
  log "Installing required packages"

  command -v apt-get >/dev/null 2>&1 || die "apt-get is required for this bootstrap script"

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    cmake \
    make \
    build-essential \
    gcc \
    g++ \
    pkg-config \
    rsync \
    openssh-client \
    default-mysql-client \
    default-libmysqlclient-dev \
    iproute2 \
    libssl-dev \
    libboost-all-dev \
    libreadline-dev \
    libncurses-dev \
    procps \
    socat \
    zlib1g-dev \
    libbz2-dev \
    systemd
}

ensure_group() {
  if getent group "$ACORE_GROUP" >/dev/null 2>&1; then
    echo "Group already exists: $ACORE_GROUP"
  else
    echo "Creating group: $ACORE_GROUP"
    groupadd --system "$ACORE_GROUP"
  fi
}

ensure_user() {
  if id "$ACORE_USER" >/dev/null 2>&1; then
    echo "User already exists: $ACORE_USER"
  else
    echo "Creating user: $ACORE_USER"
    useradd --system \
      --gid "$ACORE_GROUP" \
      --home-dir "$ACM_ROOT" \
      --shell /usr/sbin/nologin \
      "$ACORE_USER"
  fi
}

ensure_directories() {
  log "Creating acore-manager directories"

  install -d -m 0755 \
    "$ACM_ROOT" \
    "$SOURCE_ROOT" \
    "$BUILD_DIR" \
    "$RELEASES_DIR" \
    "$SHARED_DIR" \
    "$DATADIR" \
    "$CONFIG_DIR" \
    "$MODULE_CONFIG_DIR" \
    "$SHARED_LOG_DIR" \
    "$BACKUP_DIR" \
    "$ACM_ROOT/logs"

  chown -R "$ACORE_USER:$ACORE_GROUP" \
    "$ACM_ROOT" \
    "$SOURCE_ROOT" \
    "$BUILD_DIR" \
    "$RELEASES_DIR" \
    "$SHARED_DIR" \
    "$DATADIR" \
    "$CONFIG_DIR" \
    "$MODULE_CONFIG_DIR" \
    "$SHARED_LOG_DIR" \
    "$BACKUP_DIR" \
    "$ACM_ROOT/logs"
}

copy_if_missing() {
  local source_file="$1"
  local dest_file="$2"

  mkdir -p "$(dirname "$dest_file")"

  if [[ -e "$dest_file" ]]; then
    echo "Leaving existing file unchanged: $dest_file"
  else
    echo "Creating $dest_file from $source_file"
    cp "$source_file" "$dest_file"
  fi
}

install_local_config_examples() {
  log "Preparing local config files"

  copy_if_missing \
    "$ACM_REPO_ROOT/config/defaults/manager.conf.example" \
    "$ACM_REPO_ROOT/config/local/manager.conf"

  copy_if_missing \
    "$ACM_REPO_ROOT/config/defaults/modules.txt.example" \
    "$ACM_REPO_ROOT/config/local/modules.txt"
}

install_systemd_templates() {
  local installer="$ACM_REPO_ROOT/scripts/setup/acore-install-services.sh"
  local args=()

  log "Installing systemd service templates"

  [[ -f "$installer" ]] || die "service installer is missing: $installer"
  if [[ "$FORCE" == "true" ]]; then
    args+=(--force)
  fi

  bash "$installer" "${args[@]}"
}

print_next_steps() {
  log "Bootstrap complete"

  cat <<EOF
Next steps:
  1. Review local config:
     $ACM_REPO_ROOT/config/local/manager.conf
     $ACM_REPO_ROOT/config/local/modules.txt

  2. Add database credentials if needed:
     cp $ACM_REPO_ROOT/config/defaults/db.conf.example $ACM_REPO_ROOT/config/local/db.conf
     edit $ACM_REPO_ROOT/config/local/db.conf

  3. Validate configuration:
     $ACM_REPO_ROOT/scripts/config/acore-validate-config.sh

  4. Update source and modules:
     $ACM_REPO_ROOT/scripts/source/acore-update-source.sh
     $ACM_REPO_ROOT/scripts/source/acore-update-modules.sh

  5. Build and create a release:
     $ACM_REPO_ROOT/scripts/build/acore-build.sh
     $ACM_REPO_ROOT/scripts/build/acore-create-release.sh

  6. Switch to a release when ready:
     $ACM_REPO_ROOT/scripts/releases/acore-list-releases.sh
     $ACM_REPO_ROOT/scripts/config/acore-prepare-configs.sh <release-name>
     $ACM_REPO_ROOT/scripts/config/acore-check-data.sh
     $ACM_REPO_ROOT/scripts/releases/acore-switch-release.sh <release-name>

Auth/world services were installed as templates only. They were not enabled or started.
The safe shutdown hook was enabled and started so it can run during host shutdown.
Idle sleep services are enabled by default when SLEEP_ENABLED is true. They are
started only after authserver.conf is ready for the proxy/backend port split.
EOF
}

require_root
fix_executable_permissions
install_packages
ensure_group
ensure_user
ensure_directories
install_local_config_examples
install_systemd_templates
print_next_steps
