#!/bin/bash
#
# Builds TFG for distribution.
#
# Three artifacts are available:
#   love     A .love archive: a ZIP of the contents of src/, so main.lua and
#            conf.lua sit at the archive root where the love runtime looks for
#            them. Playing it needs love installed.
#   windows  A ZIP holding TFG.exe, which is the Windows love runtime with the
#            .love archive appended to it, plus the DLLs it links against.
#   linux    A self-contained AppImage built from the official love AppImage.
#
# The windows and linux targets download pinned love runtimes and verify their
# SHA-256 before use.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="${0##*/}"
readonly SCRIPT_NAME

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT

readonly GAME_NAME="TFG"
readonly SOURCE_DIR="${REPO_ROOT}/src"
readonly BUILD_DIR="${REPO_ROOT}/build"
readonly CACHE_DIR="${BUILD_DIR}/cache"
readonly DIST_DIR="${BUILD_DIR}/dist"
readonly LOVE_ARTIFACT="${BUILD_DIR}/${GAME_NAME}.love"
readonly WINDOWS_ARTIFACT="${DIST_DIR}/${GAME_NAME}-win64.zip"
readonly LINUX_ARTIFACT="${DIST_DIR}/${GAME_NAME}-x86_64.AppImage"

# Entry points love requires at the root of the archive.
readonly REQUIRED_ENTRIES=("main.lua" "conf.lua")

# Editor and OS cruft that must never be shipped.
readonly EXCLUDED_PATTERNS=("*.DS_Store" "Thumbs.db" "*.swp" "*~")

# Pinned love runtimes. The checksums come from the official GitHub release
# and must be refreshed whenever LOVE_VERSION changes.
readonly LOVE_VERSION="11.5"
readonly LOVE_BASE_URL="https://github.com/love2d/love/releases/download"
readonly LOVE_WIN64_ZIP="love-${LOVE_VERSION}-win64.zip"
readonly LOVE_WIN64_SHA256="\
ba6e56be2685e53c817749c4a5007f51137136fe5a3ab64920508babc2e74369"
readonly LOVE_APPIMAGE="love-${LOVE_VERSION}-x86_64.AppImage"
readonly LOVE_APPIMAGE_SHA256="\
65a673406431eff7167a15a032bf7a2e4ba50108e091eb7b176465831f9b5e00"

# Pinned appimagetool, used to repack the love AppImage around the game.
readonly APPIMAGETOOL_VERSION="1.9.0"
readonly APPIMAGETOOL_BASE_URL="https://github.com/AppImage/appimagetool"
readonly APPIMAGETOOL="appimagetool-x86_64.AppImage"
readonly APPIMAGETOOL_SHA256="\
46fdd785094c7f6e545b61afcfb0f3d98d8eab243f644b4b17698c01d06083d1"

#######################################
# Prints a progress message.
# Arguments:
#   Message to print.
# Outputs:
#   Writes the message to STDOUT.
#######################################
info() {
  echo "==> $*"
}

#######################################
# Prints an error message.
# Globals:
#   SCRIPT_NAME
# Arguments:
#   Message to print.
# Outputs:
#   Writes the message to STDERR.
#######################################
err() {
  echo "${SCRIPT_NAME}: error: $*" >&2
}

#######################################
# Strips the repository prefix from a path for tidier logging.
# Globals:
#   REPO_ROOT
# Arguments:
#   Absolute path.
# Outputs:
#   Writes the relative path to STDOUT.
#######################################
relative_path() {
  echo "${1#"${REPO_ROOT}/"}"
}

#######################################
# Prints the command line usage.
# Globals:
#   GAME_NAME
#   LOVE_VERSION
#   SCRIPT_NAME
# Outputs:
#   Writes the usage text to STDOUT.
#######################################
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTION]...

Builds TFG for distribution.

Options:
  -t, --target TARGET  What to build. Repeatable. One of:
                         love     build/${GAME_NAME}.love (default)
                         windows  build/dist/${GAME_NAME}-win64.zip
                         linux    build/dist/${GAME_NAME}-x86_64.AppImage
                         all      all of the above
  -c, --clean          Remove the build directory and exit.
  -r, --run            Play the .love archive with the installed love.
  -h, --help           Show this help and exit.

The windows and linux targets download pinned love ${LOVE_VERSION} runtimes
into build/cache and verify their SHA-256 before use. The linux target also
needs desktop-file-validate, from the desktop-file-utils package.
EOF
}

#######################################
# Verifies that the given tools are on PATH.
# Arguments:
#   Tool names.
# Outputs:
#   Writes missing tool names to STDERR.
# Returns:
#   0 if all tools are present, 1 otherwise.
#######################################
require_tools() {
  local -a missing=()
  local tool
  for tool in "$@"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      missing+=("${tool}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    err "missing required tools: ${missing[*]}"
    return 1
  fi
}

#######################################
# Compares a file against an expected SHA-256.
# Arguments:
#   Path to the file.
#   Expected lowercase hex digest.
# Returns:
#   0 if the digest matches, 1 otherwise.
#######################################
verify_sha256() {
  local file="$1"
  local expected="$2"

  local actual
  actual="$(sha256sum -- "${file}" | cut -d ' ' -f 1)"
  [[ "${actual}" == "${expected}" ]]
}

#######################################
# Downloads a pinned runtime into the cache unless it is already there.
# Globals:
#   CACHE_DIR
# Arguments:
#   Download URL.
#   Expected SHA-256 of the download.
#   File name to store it under in the cache.
# Outputs:
#   Writes progress to STDOUT and failures to STDERR.
# Returns:
#   0 if the cached file is present and trusted, 1 otherwise.
#######################################
fetch_runtime() {
  local url="$1"
  local checksum="$2"
  local name="$3"
  local dest="${CACHE_DIR}/${name}"

  if [[ -f "${dest}" ]] && verify_sha256 "${dest}" "${checksum}"; then
    info "Using cached ${name}"
    return 0
  fi

  info "Downloading ${name}"
  mkdir -p -- "${CACHE_DIR}"
  if ! curl --fail --location --silent --show-error --retry 3 \
      --output "${dest}" -- "${url}"; then
    err "could not download ${url}"
    return 1
  fi

  if ! verify_sha256 "${dest}" "${checksum}"; then
    err "SHA-256 mismatch for ${name}; refusing to use it"
    rm -f -- "${dest}"
    return 1
  fi
}

#######################################
# Verifies that the source tree contains the love entry points.
# Globals:
#   REQUIRED_ENTRIES
#   SOURCE_DIR
# Outputs:
#   Writes missing paths to STDERR.
# Returns:
#   0 if the source tree is complete, 1 otherwise.
#######################################
check_sources() {
  if [[ ! -d "${SOURCE_DIR}" ]]; then
    err "source directory not found: ${SOURCE_DIR}"
    return 1
  fi

  local entry
  for entry in "${REQUIRED_ENTRIES[@]}"; do
    if [[ ! -f "${SOURCE_DIR}/${entry}" ]]; then
      err "source directory is missing ${entry}"
      return 1
    fi
  done
}

#######################################
# Syntax checks every Lua file when a Lua compiler is available.
# Globals:
#   SOURCE_DIR
# Outputs:
#   Writes compiler diagnostics to STDERR.
# Returns:
#   0 if all files parse or no compiler is installed, 1 otherwise.
#######################################
check_syntax() {
  local compiler=""
  local candidate
  for candidate in luac5.1 luac luajit; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      compiler="${candidate}"
      break
    fi
  done

  if [[ -z "${compiler}" ]]; then
    info "Skipping syntax check (no Lua compiler on PATH)"
    return 0
  fi

  info "Syntax checking Lua sources with ${compiler}"
  local -a files=()
  local file
  while IFS= read -r -d '' file; do
    files+=("${file}")
  done < <(find "${SOURCE_DIR}" -type f -name '*.lua' -print0)

  local failed="false"
  for file in "${files[@]}"; do
    # luajit has no -p flag, so discard its output instead.
    if [[ "${compiler}" == "luajit" ]]; then
      "${compiler}" -b "${file}" /dev/null || failed="true"
    else
      "${compiler}" -p "${file}" || failed="true"
    fi
  done

  if [[ "${failed}" == "true" ]]; then
    err "one or more Lua files failed to compile"
    return 1
  fi
}

#######################################
# Removes the build directory.
# Globals:
#   BUILD_DIR
# Outputs:
#   Writes progress to STDOUT.
#######################################
clean() {
  if [[ -d "${BUILD_DIR}" ]]; then
    info "Removing $(relative_path "${BUILD_DIR}")/"
    rm -rf -- "${BUILD_DIR}"
  fi
}

#######################################
# Reports the size of a finished artifact.
# Arguments:
#   Path to the artifact.
# Outputs:
#   Writes a summary to STDOUT.
#######################################
report_artifact() {
  local artifact="$1"

  local size
  size="$(du -h -- "${artifact}" | cut -f 1)"
  info "Built $(relative_path "${artifact}") (${size})"
}

#######################################
# Packages the source tree into the .love archive.
# Globals:
#   BUILD_DIR
#   EXCLUDED_PATTERNS
#   LOVE_ARTIFACT
#   SOURCE_DIR
# Outputs:
#   Writes progress to STDOUT.
#######################################
build_love() {
  check_sources
  check_syntax

  info "Packaging $(relative_path "${LOVE_ARTIFACT}")"
  mkdir -p -- "${BUILD_DIR}"
  rm -f -- "${LOVE_ARTIFACT}"

  # Zipping from inside src/ keeps main.lua at the archive root. -X drops
  # platform metadata so repeated builds stay byte-comparable.
  (
    cd -- "${SOURCE_DIR}"
    zip --quiet --recurse-paths -9 -X "${LOVE_ARTIFACT}" . \
        --exclude "${EXCLUDED_PATTERNS[@]}"
  )

  verify_love_archive
  report_artifact "${LOVE_ARTIFACT}"
}

#######################################
# Checks that the archive is intact and holds the love entry points.
# Globals:
#   LOVE_ARTIFACT
#   REQUIRED_ENTRIES
# Outputs:
#   Writes progress to STDOUT and failures to STDERR.
# Returns:
#   0 if the archive is valid, 1 otherwise.
#######################################
verify_love_archive() {
  info "Verifying archive"
  if ! unzip -qq -t -- "${LOVE_ARTIFACT}"; then
    err "archive failed its integrity check"
    return 1
  fi

  local contents
  contents="$(unzip -Z1 -- "${LOVE_ARTIFACT}")"

  local entry
  for entry in "${REQUIRED_ENTRIES[@]}"; do
    if ! grep -qxF -- "${entry}" <<<"${contents}"; then
      err "archive is missing root entry: ${entry}"
      return 1
    fi
  done
}

#######################################
# Bundles the game with the Windows love runtime into a ZIP.
# Globals:
#   BUILD_DIR
#   CACHE_DIR
#   DIST_DIR
#   GAME_NAME
#   LOVE_ARTIFACT
#   LOVE_BASE_URL
#   LOVE_VERSION
#   LOVE_WIN64_SHA256
#   LOVE_WIN64_ZIP
#   REPO_ROOT
#   WINDOWS_ARTIFACT
# Outputs:
#   Writes progress to STDOUT and failures to STDERR.
# Returns:
#   0 on success, 1 otherwise.
#######################################
build_windows() {
  require_tools curl sha256sum
  fetch_runtime "${LOVE_BASE_URL}/${LOVE_VERSION}/${LOVE_WIN64_ZIP}" \
      "${LOVE_WIN64_SHA256}" "${LOVE_WIN64_ZIP}"

  info "Assembling the Windows bundle"
  local staging="${BUILD_DIR}/staging-windows"
  rm -rf -- "${staging}"
  mkdir -p -- "${staging}"
  unzip -qq -- "${CACHE_DIR}/${LOVE_WIN64_ZIP}" -d "${staging}"

  local runtime="${staging}/love-${LOVE_VERSION}-win64"
  if [[ ! -f "${runtime}/love.exe" ]]; then
    err "love.exe not found inside ${LOVE_WIN64_ZIP}"
    return 1
  fi

  local payload="${staging}/${GAME_NAME}"
  mkdir -p -- "${payload}"

  # love.exe with the .love appended to it is a standalone game executable.
  cat -- "${runtime}/love.exe" "${LOVE_ARTIFACT}" \
      >"${payload}/${GAME_NAME}.exe"
  cp -- "${runtime}"/*.dll "${payload}/"
  cp -- "${runtime}/license.txt" "${payload}/LOVE-LICENSE.txt"
  cp -- "${REPO_ROOT}/LICENSE" "${payload}/LICENSE.txt"

  mkdir -p -- "${DIST_DIR}"
  rm -f -- "${WINDOWS_ARTIFACT}"
  (
    cd -- "${staging}"
    zip --quiet --recurse-paths -9 -X "${WINDOWS_ARTIFACT}" "${GAME_NAME}"
  )
  rm -rf -- "${staging}"

  report_artifact "${WINDOWS_ARTIFACT}"
}

#######################################
# Repacks the official love AppImage around the game.
# Globals:
#   APPIMAGETOOL
#   APPIMAGETOOL_BASE_URL
#   APPIMAGETOOL_SHA256
#   APPIMAGETOOL_VERSION
#   BUILD_DIR
#   CACHE_DIR
#   DIST_DIR
#   GAME_NAME
#   LINUX_ARTIFACT
#   LOVE_APPIMAGE
#   LOVE_APPIMAGE_SHA256
#   LOVE_ARTIFACT
#   LOVE_BASE_URL
#   LOVE_VERSION
# Outputs:
#   Writes progress to STDOUT and failures to STDERR.
# Returns:
#   0 on success, 1 otherwise.
#######################################
build_linux() {
  # appimagetool shells out to desktop-file-validate.
  require_tools curl sha256sum desktop-file-validate
  fetch_runtime "${LOVE_BASE_URL}/${LOVE_VERSION}/${LOVE_APPIMAGE}" \
      "${LOVE_APPIMAGE_SHA256}" "${LOVE_APPIMAGE}"
  fetch_runtime \
      "${APPIMAGETOOL_BASE_URL}/releases/download/${APPIMAGETOOL_VERSION}/${APPIMAGETOOL}" \
      "${APPIMAGETOOL_SHA256}" "${APPIMAGETOOL}"

  info "Assembling the Linux AppImage"
  local staging="${BUILD_DIR}/staging-linux"
  rm -rf -- "${staging}"
  mkdir -p -- "${staging}"
  chmod +x -- "${CACHE_DIR}/${LOVE_APPIMAGE}" "${CACHE_DIR}/${APPIMAGETOOL}"
  (
    cd -- "${staging}"
    "${CACHE_DIR}/${LOVE_APPIMAGE}" --appimage-extract >/dev/null
  )

  local appdir="${staging}/squashfs-root"
  cp -- "${LOVE_ARTIFACT}" "${appdir}/${GAME_NAME}.love"
  fuse_apprun "${appdir}/AppRun"
  brand_desktop_entry "${appdir}"

  mkdir -p -- "${DIST_DIR}"
  rm -f -- "${LINUX_ARTIFACT}"
  # appimagetool is itself an AppImage; extracting it avoids needing FUSE.
  local log="${staging}/appimagetool.log"
  if ! ARCH="x86_64" APPIMAGE_EXTRACT_AND_RUN=1 \
      "${CACHE_DIR}/${APPIMAGETOOL}" --no-appstream \
      "${appdir}" "${LINUX_ARTIFACT}" >"${log}" 2>&1; then
    err "appimagetool failed:"
    cat -- "${log}" >&2
    return 1
  fi
  chmod +x -- "${LINUX_ARTIFACT}"
  rm -rf -- "${staging}"

  report_artifact "${LINUX_ARTIFACT}"
}

#######################################
# Points the love AppRun at the bundled .love archive.
# Globals:
#   GAME_NAME
#   SCRIPT_NAME
# Arguments:
#   Path to the AppRun script.
# Outputs:
#   Writes failures to STDERR.
# Returns:
#   0 on success, 1 if the upstream hook is gone.
#######################################
fuse_apprun() {
  local apprun="$1"

  # Upstream ships this hook commented out for exactly this purpose.
  if ! grep -q '^#FUSE_PATH=' -- "${apprun}"; then
    err "AppRun no longer exposes the FUSE_PATH hook; update ${SCRIPT_NAME}"
    return 1
  fi

  local replacement="FUSE_PATH=\"\$APPDIR/${GAME_NAME}.love\""
  sed -i "s|^#FUSE_PATH=.*my_game\.love.*|${replacement}|" -- "${apprun}"

  if ! grep -q '^FUSE_PATH=' -- "${apprun}"; then
    err "failed to set FUSE_PATH in AppRun"
    return 1
  fi
}

#######################################
# Renames the love desktop entry so the AppImage advertises the game.
# Globals:
#   GAME_NAME
#   SCRIPT_NAME
# Arguments:
#   Path to the AppDir.
# Outputs:
#   Writes failures to STDERR.
# Returns:
#   0 on success, 1 if the upstream entry is gone.
#######################################
brand_desktop_entry() {
  local appdir="$1"

  if [[ ! -f "${appdir}/love.desktop" ]]; then
    err "love.desktop not found in the AppDir; update ${SCRIPT_NAME}"
    return 1
  fi

  local desktop="${appdir}/${GAME_NAME}.desktop"
  mv -- "${appdir}/love.desktop" "${desktop}"
  # The love entry claims the .love MIME type, which this bundle does not.
  sed -i \
      -e "s|^Name=.*|Name=${GAME_NAME}|" \
      -e "s|^Exec=.*|Exec=${GAME_NAME}|" \
      -e "s|^Comment=.*|Comment=A tiny fighting game|" \
      -e '/^MimeType=/d' \
      -- "${desktop}"
}

#######################################
# Launches the .love archive with the installed love runtime.
# Globals:
#   LOVE_ARTIFACT
# Outputs:
#   Writes progress to STDOUT and failures to STDERR.
# Returns:
#   The exit status of love, or 1 if love is not installed.
#######################################
run_game() {
  if ! command -v love >/dev/null 2>&1; then
    err "love is not installed; see https://love2d.org/"
    return 1
  fi

  info "Launching love"
  love "${LOVE_ARTIFACT}"
}

#######################################
# Parses the command line and drives the build.
# Arguments:
#   Command line options, see usage.
# Outputs:
#   Writes progress to STDOUT and failures to STDERR.
# Returns:
#   0 on success, non-zero on failure.
#######################################
main() {
  local clean_only="false"
  local run_after_build="false"
  local want_windows="false"
  local want_linux="false"

  while (($# > 0)); do
    case "$1" in
      -t | --target)
        if (($# < 2)); then
          err "--target requires an argument"
          return 1
        fi
        case "$2" in
          love)
            ;;
          windows)
            want_windows="true"
            ;;
          linux)
            want_linux="true"
            ;;
          all)
            want_windows="true"
            want_linux="true"
            ;;
          *)
            err "unknown target: $2"
            usage >&2
            return 1
            ;;
        esac
        shift
        ;;
      -c | --clean)
        clean_only="true"
        ;;
      -r | --run)
        run_after_build="true"
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        err "unknown option: $1"
        usage >&2
        return 1
        ;;
    esac
    shift
  done

  if [[ "${clean_only}" == "true" ]]; then
    clean
    return 0
  fi

  require_tools zip unzip

  # The platform bundles embed the .love archive, so it is always built.
  build_love

  if [[ "${want_windows}" == "true" ]]; then
    build_windows
  fi
  if [[ "${want_linux}" == "true" ]]; then
    build_linux
  fi

  if [[ "${run_after_build}" == "true" ]]; then
    run_game
  fi
}

main "$@"
