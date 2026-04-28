#!/bin/bash

set -e -o pipefail

trap 'echo ""; echo "Build interrupted. Exiting..."; exit 130' INT TERM

#============================================================
# HELP FUNCTION
#============================================================
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

FACTORY APP BOLT PACKAGE BUILD SYSTEM

Options:
  --help, -h                      Show this help message and exit
  --config-file FILE              Path to configuration file (default: ./config.env)

  Build Configuration:
  --build-list LIST               Comma-separated list of builds (e.g., "base:bitbake,wpe:bitbake,refui:refui")

  Version Configuration:
  --base-version VERSION          Base build version/branch
  --wpe-version VERSION           WPE build version/branch
  --refui-version VERSION         RefUI build version/branch

  Bolt Environment Configuration:
  --bolt-repo-sync-params PARAMS  Parameters passed to repo sync command (e.g., "--no-clone-bundle -j4")
  --bolt-dl-dir DIR               Download directory for build artifacts
  --bolt-sstate-dir DIR           Shared state cache directory for faster builds

  Directory Configuration:
  --work-dir DIR                  Working directory for builds (default: ./work)
  --bolts-dir DIR                 Output directory for bolt packages (default: ./bolts)

  Key Configuration:
  --private-key PATH              Path to private key for signing
  --signing-certificate PATH      Path to signing certificate for signing
  --key-passphrase PASS           Private key passphrase (if required)
  --key-format FORMAT             Key format: PEM or PKCS12 (default: PEM)

  Manifest & Tools:
  --manifest-file FILE            Path to manifest JSON file (default: ./bolts/factory-app-version.json)
  --ralfpack-bin PATH             Path to ralfpack binary (default: /usr/bin/ralfpack)

Examples:
  # Use default configuration file
  $0

  # Override specific versions
  $0 --base-version 0.2.1 --wpe-version 0.2.1

  # Use custom keys and directories
  $0 --private-key ./mykeys/private.key --signing-certificate ./mykeys/signing-certificate.pem --bolts-dir ./output

  # Custom build list
  $0 --build-list "base:bitbake,wpe:bitbake"

Note: Repository URLs are defined in config.env and cannot be overridden via command line.

EOF
    exit 0
}

#============================================================
# COMMAND LINE ARGUMENT PARSING
#============================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                ;;
            --config-file)
                if [ -z "$2" ]; then
                    echo "Error: --config-file requires a value"
                    exit 1
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            --build-list)
                if [ -z "$2" ]; then
                    echo "Error: --build-list requires a value"
                    exit 1
                fi
                CLI_BUILD_LIST="$2"
                shift 2
                ;;
            --base-version)
                if [ -z "$2" ]; then
                    echo "Error: --base-version requires a value"
                    exit 1
                fi
                CLI_BASE_VERSION="$2"
                shift 2
                ;;
            --wpe-version)
                if [ -z "$2" ]; then
                    echo "Error: --wpe-version requires a value"
                    exit 1
                fi
                CLI_WPE_VERSION="$2"
                shift 2
                ;;
            --refui-version)
                if [ -z "$2" ]; then
                    echo "Error: --refui-version requires a value"
                    exit 1
                fi
                CLI_REFUI_VERSION="$2"
                shift 2
                ;;
            --bolt-repo-sync-params)
                if [ -z "$2" ]; then
                    echo "Error: --bolt-repo-sync-params requires a value"
                    exit 1
                fi
                CLI_BOLT_REPO_SYNC_PARAMS="$2"
                shift 2
                ;;
            --bolt-dl-dir)
                if [ -z "$2" ]; then
                    echo "Error: --bolt-dl-dir requires a value"
                    exit 1
                fi
                CLI_BOLT_DL_DIR="$2"
                shift 2
                ;;
            --bolt-sstate-dir)
                if [ -z "$2" ]; then
                    echo "Error: --bolt-sstate-dir requires a value"
                    exit 1
                fi
                CLI_BOLT_SSTATE_DIR="$2"
                shift 2
                ;;
            --work-dir)
                if [ -z "$2" ]; then
                    echo "Error: --work-dir requires a value"
                    exit 1
                fi
                CLI_WORK_DIR="$2"
                shift 2
                ;;
            --bolts-dir)
                if [ -z "$2" ]; then
                    echo "Error: --bolts-dir requires a value"
                    exit 1
                fi
                CLI_BOLTS_DIR="$2"
                shift 2
                ;;
            --private-key)
                if [ -z "$2" ]; then
                    echo "Error: --private-key requires a value"
                    exit 1
                fi
                CLI_PRIVATE_KEY_PATH="$2"
                shift 2
                ;;
            --signing-certificate)
                if [ -z "$2" ]; then
                    echo "Error: --signing-certificate requires a value"
                    exit 1
                fi
                CLI_SIGNING_CERT_PATH="$2"
                shift 2
                ;;
            --key-passphrase)
                if [ -z "$2" ]; then
                    echo "Error: --key-passphrase requires a value"
                    exit 1
                fi
                CLI_PRIVATE_KEY_PASSPHRASE="$2"
                shift 2
                ;;
            --key-format)
                if [ -z "$2" ]; then
                    echo "Error: --key-format requires a value"
                    exit 1
                fi
                CLI_KEY_FORMAT="$2"
                shift 2
                ;;
            --manifest-file)
                if [ -z "$2" ]; then
                    echo "Error: --manifest-file requires a value"
                    exit 1
                fi
                CLI_MANIFEST_FILE="$2"
                shift 2
                ;;
            --ralfpack-bin)
                if [ -z "$2" ]; then
                    echo "Error: --ralfpack-bin requires a value"
                    exit 1
                fi
                CLI_RALFPACK_BIN="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Parse command line arguments first
parse_args "$@"

echo "============================================================"
echo "  FACTORY APP BOLT PACKAGE BUILD SYSTEM"
echo "============================================================"
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"

# Save project root directory
export PROJECT_ROOT="$(pwd)"

# Load configuration
CONFIG_FILE="${CONFIG_FILE:-./config.env}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "Loading configuration from: $CONFIG_FILE"
source "$CONFIG_FILE"

# Override configuration with command-line arguments if provided
[ -n "$CLI_BUILD_LIST" ] && BUILD_LIST="$CLI_BUILD_LIST"
[ -n "$CLI_BASE_VERSION" ] && BASE_VERSION="$CLI_BASE_VERSION"
[ -n "$CLI_WPE_VERSION" ] && WPE_VERSION="$CLI_WPE_VERSION"
[ -n "$CLI_REFUI_VERSION" ] && REFUI_VERSION="$CLI_REFUI_VERSION"
[ -n "$CLI_BOLT_REPO_SYNC_PARAMS" ] && BOLT_REPO_SYNC_PARAMS="$CLI_BOLT_REPO_SYNC_PARAMS"
[ -n "$CLI_BOLT_DL_DIR" ] && BOLT_DL_DIR="$CLI_BOLT_DL_DIR"
[ -n "$CLI_BOLT_SSTATE_DIR" ] && BOLT_SSTATE_DIR="$CLI_BOLT_SSTATE_DIR"
[ -n "$CLI_WORK_DIR" ] && WORK_DIR="$CLI_WORK_DIR"
[ -n "$CLI_BOLTS_DIR" ] && BOLTS_DIR="$CLI_BOLTS_DIR"
[ -n "$CLI_PRIVATE_KEY_PATH" ] && PRIVATE_KEY_PATH="$CLI_PRIVATE_KEY_PATH"
[ -n "$CLI_SIGNING_CERT_PATH" ] && SIGNING_CERT_PATH="$CLI_SIGNING_CERT_PATH"
[ -n "$CLI_PRIVATE_KEY_PASSPHRASE" ] && PRIVATE_KEY_PASSPHRASE="$CLI_PRIVATE_KEY_PASSPHRASE"
[ -n "$CLI_KEY_FORMAT" ] && KEY_FORMAT="$CLI_KEY_FORMAT"
[ -n "$CLI_MANIFEST_FILE" ] && MANIFEST_FILE="$CLI_MANIFEST_FILE"
[ -n "$CLI_RALFPACK_BIN" ] && RALFPACK_BIN="$CLI_RALFPACK_BIN"

# Generate ENV_CONTENT from individual variables
BOLT_ENV_CONTENT="BOLT_REPO_SYNC_PARAMS=\"${BOLT_REPO_SYNC_PARAMS}\"
BOLT_DL_DIR=\"${BOLT_DL_DIR}\"
BOLT_SSTATE_DIR=\"${BOLT_SSTATE_DIR}\""

# Function to convert relative paths to absolute
to_absolute() {
    local path="$1"
    [[ "$path" = /* ]] && echo "$path" && return
    echo "$PROJECT_ROOT/$path"
}

# Convert all directory paths to absolute and export
WORK_DIR="$(to_absolute "${WORK_DIR:-./work}")"
BOLTS_DIR="$(to_absolute "${BOLTS_DIR:-./bolts}")"
PRIVATE_KEY_PATH="$(to_absolute "${PRIVATE_KEY_PATH:-./keys/private.key}")"
SIGNING_CERT_PATH="$(to_absolute "$SIGNING_CERT_PATH")"
MANIFEST_FILE="$(to_absolute "${MANIFEST_FILE:-./bolts/factory-app-version.json}")"

# Create necessary directories
mkdir -p "$WORK_DIR" "$BOLTS_DIR"

echo "Config: $CONFIG_FILE"
echo "Project Root: $PROJECT_ROOT"
echo "Work Directory: $WORK_DIR"
echo "Bolts Directory: $BOLTS_DIR"
echo "Bolt Downloads dir: $BOLT_DL_DIR"
echo "Bolt sstate dir: $BOLT_SSTATE_DIR"
echo "Bolt repo sync params: $BOLT_REPO_SYNC_PARAMS"
echo ""

#============================================================
# HELPER FUNCTION TO GET CONFIG VALUE
#============================================================
get_config() {
    local build_name="$1"
    local config_key="$2"
    local var_name="${build_name^^}_${config_key}"
    echo "${!var_name}"
}

#============================================================
# GENERIC BUILD FUNCTION FOR BITBAKE BOLT REPOSITORIES
#============================================================
build_bolt_bitbake() {
    local BUILD_NAME="$1"
    local REPO_URL=$(get_config "$BUILD_NAME" "REPO_URL")
    local VERSION=$(get_config "$BUILD_NAME" "VERSION")
    local BOLT_MAKE_TARGET=$(get_config "$BUILD_NAME" "BOLT_MAKE_TARGET")
    local ENV_CONTENT="${BOLT_ENV_CONTENT}"
    local CLONE_DIR="${WORK_DIR}/${BUILD_NAME}"

    echo "============================================================"
    echo "  Building ${BUILD_NAME} (Bitbake)"
    echo "============================================================"

    echo "Configuration:"
    echo "  Repository: $REPO_URL"
    echo "  Version: $VERSION"
    echo "  Clone Directory: $CLONE_DIR"
    echo "  Bolts Directory: $BOLTS_DIR"
    echo "  Bolt Make Target: $BOLT_MAKE_TARGET"
    echo " "

    # Validate required configurations
    if [ -z "$REPO_URL" ] || [ -z "$VERSION" ] || [ -z "$BOLT_MAKE_TARGET" ]; then
        echo "Error: Missing required configuration for $BUILD_NAME"
        echo "Required: ${BUILD_NAME^^}_REPO_URL, ${BUILD_NAME^^}_VERSION, ${BUILD_NAME^^}_BOLT_MAKE_TARGET"
        return 1
    fi

    # Clone repository
    echo "Cloning $REPO_URL (branch: $VERSION)..."
    if [ -d "$CLONE_DIR" ]; then
        echo "Directory exists, removing..."
        rm -rf "$CLONE_DIR"
    fi

    git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$CLONE_DIR" || {
        echo "Git clone failed or interrupted"
        return 1
    }

    # Navigate to repo
    cd "$CLONE_DIR"

    # Setup .env file if env content provided
    if [ -n "$ENV_CONTENT" ]; then
        echo "Setting up .env file..."
        echo "$ENV_CONTENT" > .env
        echo ".env file created with provided content"
    fi

    # Source setup-environment if it exists
    if [ -f "setup-environment" ]; then
        echo "Sourcing setup-environment... $PWD"
        source setup-environment
    else
        echo "Note: setup-environment script not found (may not be needed)"
    fi

    # Build bolt pkg
    echo "Run bitbake for $BOLT_MAKE_TARGET-bolt-image"
    bitbake "${BOLT_MAKE_TARGET}-bolt-image" || {
        echo "Error: bitbake ${BOLT_MAKE_TARGET}-bolt-image failed or interrupted"
        return 1
    }

    # Build bolt-env first (this provides the bolt command)
    echo "Building bolt-env with bitbake..."
    bitbake bolt-env || {
        echo "bitbake bolt-env failed or interrupted"
        return 1
    }

    hash bolt 2>/dev/null || true

    # Run bolt make to install package if target provided
    if [ -n "${BOLT_MAKE_TARGET}" ]; then
        echo "Running bolt make..."
        if ! command -v bolt &> /dev/null; then
            echo "Error: bolt command not found. Please ensure bolt-env was built successfully."
            return 1
        fi

        bolt make "${BOLT_MAKE_TARGET}" --force-install || {
            echo "bolt make ${BOLT_MAKE_TARGET} failed or interrupted"
            return 1
        }
    fi

    echo "✓ ${BUILD_NAME} build completed successfully"
    cd "$PROJECT_ROOT"
    return 0
}

#============================================================
# BUILD REFUI (SPECIAL CASE - USES BOLT PACK)
#============================================================
build_refui_type() {
    local BUILD_NAME="$1"
    local REPO_URL=$(get_config "$BUILD_NAME" "REPO_URL")
    local VERSION=$(get_config "$BUILD_NAME" "VERSION")
    local CLONE_DIR="${WORK_DIR}/${BUILD_NAME}"
    local BOLT_DIR=bolt
    local PACK_SCRIPT=pack.sh
    local PACKAGES_DIR=packages
    local PACKAGE_CONFIG=package-configs/com.rdkcentral.${BUILD_NAME}.json

    echo "============================================================"
    echo "  Building ${BUILD_NAME} (RefUI Type)"
    echo "============================================================"

    echo "Configuration:"
    echo "  Repository: $REPO_URL"
    echo "  Version: $VERSION"
    echo "  Build Name: $BUILD_NAME"
    echo "  Clone Directory: $CLONE_DIR"
    echo "  Bolts Directory: $BOLTS_DIR"

    # Validate required configurations
    if [ -z "$REPO_URL" ] || [ -z "$VERSION" ]; then
        echo "Error: Missing required configuration for $BUILD_NAME"
        echo "Required: ${BUILD_NAME^^}_REPO_URL, ${BUILD_NAME^^}_VERSION"
        return 1
    fi

    # Clone repository
    echo "Cloning $REPO_URL (branch: $VERSION)..."
    if [ -d "$CLONE_DIR" ]; then
        echo "Directory exists, removing..."
        rm -rf "$CLONE_DIR"
    fi

    git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$CLONE_DIR" || {
        echo "Git clone failed or interrupted"
        return 1
    }

    # Navigate to repo
    cd "$CLONE_DIR"

    # Look for bolt directory
    if [ -n "$BOLT_DIR" ] && [ -d "$BOLT_DIR" ]; then
        echo "Found bolt directory: $BOLT_DIR, navigating..."
        cd "$BOLT_DIR"
    else
        echo "Warning: Bolt directory not specified or not found, staying in repo root"
    fi

    # Run pack.sh if it exists (prepares files for bolt pack)
    if [ -n "$PACK_SCRIPT" ] && [ -f "$PACK_SCRIPT" ]; then
        echo "Running $PACK_SCRIPT..."
        chmod +x "$PACK_SCRIPT"
        ./"$PACK_SCRIPT" || {
            echo "$PACK_SCRIPT failed or interrupted"
            return 1
        }
    else
        echo "Note: Pack script not specified or not found"
    fi

    # Navigate to packages directory if specified
    if [ -z "$PACKAGES_DIR" ] || [ ! -d "$PACKAGES_DIR" ]; then
        echo "Error: Packages directory not found or not specified: $PACKAGES_DIR"
        return 1
    fi

    # Check if bolt command is available
    echo "Checking for bolt command..."
    if ! command -v bolt &> /dev/null; then
        echo "Error: bolt command not found"
        echo "Please ensure a bitbake build has been run first to build bolt-env"
        return 1
    fi

    # Validate bolt pack prerequisites and run bolt pack
    if [ -z "$PACKAGE_CONFIG" ]; then
        echo "Error: PACKAGE_CONFIG is not set; cannot run bolt pack for ${BUILD_NAME}"
        return 1
    fi

    if [ ! -f "$PACKAGE_CONFIG" ]; then
        echo "Error: Package config not found: $PACKAGE_CONFIG"
        return 1
    fi

    if [ ! -f "${PACKAGES_DIR}/${BUILD_NAME}.tgz" ]; then
        echo "Error: Required package archive not found: ${PACKAGES_DIR}/${BUILD_NAME}.tgz"
        return 1
    fi

    echo "Running bolt pack..."
    bolt pack "$PACKAGE_CONFIG" "${PACKAGES_DIR}/${BUILD_NAME}.tgz" || {
        echo "bolt pack failed or interrupted"
        return 1
    }
    echo "✓ Bolt pack completed"
    # Copy package to bolts folder
    echo "Copying packages to bolts folder..."
    cd "$CLONE_DIR"

    # Look for .bolt packages
    local FOUND_PACKAGES=$(find . -name "*.bolt" -type f 2>/dev/null)
    if [ -n "$FOUND_PACKAGES" ]; then
        find . -name "*.bolt" -type f -exec cp -v {} "$BOLTS_DIR/" \;
        echo "${BUILD_NAME} bolt package copied to $BOLTS_DIR"
    else
        echo "Error: No .bolt packages found"
        cd "$PROJECT_ROOT"
        return 1
    fi

    echo "✓ ${BUILD_NAME} build completed successfully"
    cd "$PROJECT_ROOT"
    return 0
}

#============================================================
# SIGN BOLT PACKAGES
#============================================================
sign_packages() {
    echo "============================================================"
    echo "  Signing bolt packages"
    echo "============================================================"

    # Configuration variables with defaults
    local RALFPACK_BIN="${RALFPACK_BIN:-/usr/bin/ralfpack}"
    local KEY_FORMAT="${KEY_FORMAT:-PEM}"

    echo "Configuration:"
    echo "  Bolts Directory: $BOLTS_DIR"
    echo "  Ralfpack Binary: $RALFPACK_BIN"
    echo "  Private Key: $PRIVATE_KEY_PATH"
    echo "  Signing Certificate: $SIGNING_CERT_PATH"
    echo "  Key Format: $KEY_FORMAT"

    # Check if ralfpack binary exists
    if [ ! -f "$RALFPACK_BIN" ]; then
        echo "Error: ralfpack binary not found: $RALFPACK_BIN"
        echo "Please provide a valid path to ralfpack"
        return 1
    fi

    # Make ralfpack executable if it isn't already
    if [ ! -x "$RALFPACK_BIN" ]; then
        echo "Making ralfpack executable..."
        chmod +x "$RALFPACK_BIN"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to make ralfpack executable"
            echo "Try running: chmod +x $RALFPACK_BIN"
            return 1
        fi
    fi

    if [ "$KEY_FORMAT" != "PEM" ] && [ "$KEY_FORMAT" != "PKCS12" ]; then
        echo "Error: Invalid KEY_FORMAT: $KEY_FORMAT"
        echo "Supported formats: PEM, PKCS12"
        return 1
    fi

    # Check if bolts directory exists
    if [ ! -d "$BOLTS_DIR" ]; then
        echo "Error: Bolts directory not found: $BOLTS_DIR"
        return 1
    fi

    # Check if private key exists
    if [ ! -f "$PRIVATE_KEY_PATH" ]; then
        echo "Error: Private key not found: $PRIVATE_KEY_PATH"
        return 1
    fi

    # Check if signing certificate exists
    if [ ! -f "$SIGNING_CERT_PATH" ]; then
        echo "Error: Signing certificate not found: $SIGNING_CERT_PATH"
        return 1
    fi

    # Count packages
    local PACKAGE_COUNT=$(find "$BOLTS_DIR" -name "*.bolt" -type f 2>/dev/null | wc -l)
    if [ "$PACKAGE_COUNT" -eq 0 ]; then
        echo "Warning: No .bolt packages found in $BOLTS_DIR"
        return 0
    fi

    echo "Found $PACKAGE_COUNT package(s) to sign"

    # Sign all bolt packages
    echo "Signing packages in $BOLTS_DIR..."
    for package in "$BOLTS_DIR"/*.bolt; do
        if [ -f "$package" ]; then
            echo "Signing: $(basename "$package")"

            # Prepare sign command
            SIGN_CMD=("$RALFPACK_BIN" sign)
            if [ "$KEY_FORMAT" == "PKCS12" ]; then
                SIGN_CMD+=("--pkcs12" "$PRIVATE_KEY_PATH")
            else
                SIGN_CMD+=("--key" "$PRIVATE_KEY_PATH" "--cert" "$SIGNING_CERT_PATH")
            fi

            # Add passphrase if provided
            if [ -n "$PRIVATE_KEY_PASSPHRASE" ]; then
                SIGN_CMD+=("--passphrase" "$PRIVATE_KEY_PASSPHRASE")
            fi

            SIGN_CMD+=("$package")

            # Execute signing
            if "${SIGN_CMD[@]}"; then
                echo "✓ Signed: $(basename "$package")"
            else
                echo "Error: Failed to sign $(basename "$package")"
                return 1
            fi
        fi
    done

    # Verify all signed packages
    echo ""
    echo "Verifying signed packages..."
    for package in "$BOLTS_DIR"/*.bolt; do
        if [ -f "$package" ]; then
            echo "Verifying: $(basename "$package")"

            # Prepare verify command based on key format
            VERIFY_CMD=("$RALFPACK_BIN" verify)

            # Use signing certificate for verification
            VERIFY_CMD+=("--ca-roots" "$SIGNING_CERT_PATH")
            
            VERIFY_CMD+=("$package")
            # Execute verification
            if "${VERIFY_CMD[@]}"; then
                echo "✓ Verified: $(basename "$package")"
            else
                echo "Error: Failed to verify $(basename "$package")"
                return 1
            fi
        fi
    done

    echo ""
    echo "✓ All packages signed and verified successfully"
    return 0
}

#============================================================
# GENERATE MANIFEST JSON FILE
#============================================================
generate_manifest() {
    echo "============================================================"
    echo "  Generating manifest JSON file"
    echo "============================================================"

    # Configuration variables with defaults
    local MANIFEST_FILE="${MANIFEST_FILE:-./bolts/factory-app-version.json}"

    echo "Configuration:"
    echo "  Bolts Directory: $BOLTS_DIR"
    echo "  Signing certificate: $SIGNING_CERT_PATH"
    echo "  Manifest File: $MANIFEST_FILE"

    # Check if bolts dir exists
    if [ ! -d "$BOLTS_DIR" ] ; then
        echo "Bolts directory not found: $BOLTS_DIR"
        return 1
    fi

    # Check if signing certificate exists
    if [ ! -f "$SIGNING_CERT_PATH" ] ; then
        echo "Signing certificate not found: $SIGNING_CERT_PATH"
        return 1
    fi

    # Create manifest json
    local manifest_data="["
    local first=true

    # Process .bolt packages
    for bolt_file in "$BOLTS_DIR"/*.bolt; do
        # Skip if no .bolt files found
        if [ ! -f "$bolt_file" ] ; then
            continue
        fi

        local pkg_name=$(basename "$bolt_file")
        local sha=$(sha256sum "$bolt_file" | awk '{print $1}')

        if [ "$first" == false ] ; then
               manifest_data+=","
        fi

        first=false

        manifest_data+="
  {
    \"packagename\": \"$pkg_name\",
    \"srcuri\": \"file://$bolt_file\",
    \"sha256sum\": \"$sha\"
  }"
    done

    # Add Signing certificate entry
    local key_name=$(basename "$SIGNING_CERT_PATH")
    local key_sha=$(sha256sum "$SIGNING_CERT_PATH" | awk '{print $1}')

    manifest_data+=",
  {
    \"packagename\": \"$key_name\",
    \"srcuri\": \"file://$SIGNING_CERT_PATH\",
    \"sha256sum\": \"$key_sha\",
    \"installpath\": \"/etc/rdk/certs\"
  }"

    manifest_data+="
]"

    # Write to file
    echo "$manifest_data" > "$MANIFEST_FILE"
    echo "Manifest generated: $MANIFEST_FILE"
    return 0
}

#============================================================
# MAIN BUILD SEQUENCE - LOOP THROUGH BUILD_LIST
#============================================================

# Parse BUILD_LIST from config
if [ -z "$BUILD_LIST" ]; then
    echo "Error: BUILD_LIST not defined in config.env"
    echo "Please define BUILD_LIST with format: BUILD_NAME:BUILD_TYPE,..."
    echo "Example: BUILD_LIST=\"base:bitbake,wpe:bitbake,refui:refui\""
    exit 1
fi

echo "Build List: $BUILD_LIST"
echo ""

# Convert comma-separated list to array
IFS=',' read -ra BUILDS <<< "$BUILD_LIST"

# Loop through each build
for build_entry in "${BUILDS[@]}"; do
    # Parse build name and type
    IFS=':' read -r build_name build_type <<< "$build_entry"

    # Trim whitespace
    build_name=$(echo "$build_name" | xargs)
    build_type=$(echo "$build_type" | xargs)

    echo "Processing: $build_name (Type: $build_type)"

    # Execute appropriate build function based on type
    case "$build_type" in
        bitbake)
            build_bolt_bitbake "$build_name" || {
                echo "Error: Failed to build $build_name"
                exit 1
            }
            ;;
        refui)
            build_refui_type "$build_name" || {
                echo "Error: Failed to build $build_name"
                exit 1
            }
            ;;
        *)
            echo "Error: Unknown build type '$build_type' for $build_name"
            echo "Supported types: bitbake, refui"
            exit 1
            ;;
    esac

    echo ""
done

# Sign packages after all builds complete
sign_packages || {
    echo "Error: Failed to sign packages"
    exit 1
}

# Generate manifest
generate_manifest || {
    echo "Error: Failed to generate manifest file"
    exit 1
}
echo " "
echo "============================================================"
echo "  ✓ ALL BUILD STEPS COMPLETED SUCCESSFULLY"
echo "============================================================"
echo "Finished: $(date '+%Y-%m-%d %H:%M:%S')"
