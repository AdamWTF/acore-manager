#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

acquire_acm_lock build

command -v cmake >/dev/null 2>&1 || die "cmake is not available"
command -v make >/dev/null 2>&1 || die "make is not available"

[[ -d "$ACORE_SOURCE_DIR" ]] || die "ACORE_SOURCE_DIR does not exist: $ACORE_SOURCE_DIR"
[[ -f "$ACORE_SOURCE_DIR/CMakeLists.txt" ]] || die "ACORE_SOURCE_DIR does not look like an AzerothCore source tree: $ACORE_SOURCE_DIR"

STAGING_DIR="$BUILD_DIR/staging"
STAGING_ROOT="$BUILD_DIR/staging-root"
RUNTIME_INSTALL_PREFIX="$CURRENT_LINK"
cmake_args=(
  -S "$ACORE_SOURCE_DIR"
  -B "$BUILD_DIR"
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
  -DCMAKE_INSTALL_PREFIX="$RUNTIME_INSTALL_PREFIX"
)

if [[ -n "${CMAKE_EXTRA_FLAGS:-}" ]]; then
  echo "Using extra CMake flags: $CMAKE_EXTRA_FLAGS"
  # shellcheck disable=SC2206
  extra_cmake_args=( $CMAKE_EXTRA_FLAGS )
  cmake_args+=("${extra_cmake_args[@]}")
else
  echo "Using extra CMake flags: none"
fi

print_failure_context() {
  echo
  echo "Build step failed."
  echo
  echo "Tool versions:"

  if command -v gcc >/dev/null 2>&1; then
    gcc --version | head -n 1
  else
    echo "gcc: not found"
  fi

  if command -v g++ >/dev/null 2>&1; then
    g++ --version | head -n 1
  else
    echo "g++: not found"
  fi

  if command -v cmake >/dev/null 2>&1; then
    cmake --version | head -n 1
  else
    echo "cmake: not found"
  fi

  echo
  echo "CMake flags used:"
  printf '  %q\n' "${cmake_args[@]}"
  echo
  echo "Runtime install prefix: $RUNTIME_INSTALL_PREFIX"
  echo "Packaging staging directory: $STAGING_DIR"
  echo
  echo "See docs/troubleshooting.md for known build issues and workarounds."
}

run_build_step() {
  "$@" || {
    print_failure_context
    return 1
  }
}

build_threads="$BUILD_THREADS"
if [[ "$build_threads" == "auto" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    build_threads="$(nproc)"
  else
    build_threads="1"
  fi
fi

log "Preparing build directories"
mkdir -p "$BUILD_DIR"
rm -rf "$STAGING_DIR"
rm -rf "$STAGING_ROOT"
mkdir -p "$STAGING_DIR"
mkdir -p "$STAGING_ROOT"

log "Configuring AzerothCore"
run_build_step cmake "${cmake_args[@]}"

log "Building AzerothCore"
run_build_step cmake --build "$BUILD_DIR" --parallel "$build_threads"

log "Installing into staging"
run_build_step env DESTDIR="$STAGING_ROOT" cmake --install "$BUILD_DIR"

staged_prefix="$STAGING_ROOT$RUNTIME_INSTALL_PREFIX"
[[ -d "$staged_prefix" ]] || die "expected staged runtime prefix was not created: $staged_prefix"

if command -v rsync >/dev/null 2>&1; then
  rsync -a "$staged_prefix/" "$STAGING_DIR/"
else
  cp -a "$staged_prefix/." "$STAGING_DIR/"
fi

validate_runtime_artifacts "$STAGING_DIR" "staging"

echo
echo "Build completed successfully."
echo "Staging directory: $STAGING_DIR"
echo "Runtime install prefix baked into build: $RUNTIME_INSTALL_PREFIX"
