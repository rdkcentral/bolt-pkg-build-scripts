# Factory App Bolt Package Build System

Build scripts for assembling, packaging, signing, and generating manifests for RDK-E factory app bolt packages on a Linux host.

| File | Description |
|------|-------------|
| `gen-bolt-pkgs.sh` | Main build orchestrator script |
| `config.env` | Build configuration (repositories, versions, keys, paths) |

### Prerequisites

The `bolt` package build system is Yocto-based. Ensure the build host satisfies the requirements for [Kirkstone-based builds](https://docs.yoctoproject.org/kirkstone/ref-manual/system-requirements.html#required-packages-for-the-build-host), and that the following are available:

- `repo` tool — see [Install repo tool](https://android.googlesource.com/tools/repo)
- `git`
- `ralfpack` binary (default path: `/usr/bin/ralfpack`) — must be [built for the host](https://github.com/rdkcentral/ralfpack)
- Signing key pair (PEM or PKCS12 format) - see [Create self-signed keys using openssl](https://wiki.rdkcentral.com/spaces/RDK/pages/447124247/Bolt+package+-+signing+and+verification#Boltpackagesigningandverification-Signing-keyGeneration)

## Usage

```bash
bash gen-bolt-pkgs.sh [OPTIONS]
```

By default, `gen-bolt-pkgs.sh` reads `./config.env`. To specify an alternative configuration file:

```bash
bash gen-bolt-pkgs.sh --config-file /path/to/custom.env
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `--help`, `-h` | Show help message and exit |
| `--config-file FILE` | Path to configuration file (default: `./config.env`) |
| `--build-list LIST` | Comma-separated list of builds (e.g., `"base:bitbake,wpe:bitbake,refui:refui"`) |
| `--base-version VERSION` | Base build version/branch |
| `--wpe-version VERSION` | WPE build version/branch |
| `--refui-version VERSION` | RefUI build version/branch |
| `--bolt-repo-sync-params PARAMS` | Parameters passed to `repo sync` (e.g., `"--no-clone-bundle -j4"`) |
| `--bolt-dl-dir DIR` | Download directory for build artifacts |
| `--bolt-sstate-dir DIR` | Shared state cache directory for faster builds |
| `--work-dir DIR` | Working directory for builds (default: `./work`) |
| `--bolts-dir DIR` | Output directory for bolt packages (default: `./bolts`) |
| `--private-key PATH` | Path to private key for signing |
| `--public-key PATH` | Path to public key for verification |
| `--key-passphrase PASS` | Private key passphrase (if required) |
| `--key-format FORMAT` | Key format: `PEM` or `PKCS12` (default: `PEM`) |
| `--manifest-file FILE` | Path to manifest JSON file (default: `./bolts/factory-app-version.json`) |
| `--ralfpack-bin PATH` | Path to `ralfpack` binary (default: `/usr/bin/ralfpack`) |

Command-line options override the corresponding values from `config.env`. Repository URLs are defined in `config.env` only and cannot be overridden via command line.

Examples:

```bash
# Override specific versions
bash gen-bolt-pkgs.sh --base-version 0.2.1 --wpe-version 0.2.1

# Use custom keys and output directory
bash gen-bolt-pkgs.sh --private-key ./mykeys/private.key --public-key ./mykeys/public.key --bolts-dir ./output

# Run a subset of builds
bash gen-bolt-pkgs.sh --build-list "base:bitbake,wpe:bitbake"
```

## Build Pipeline

The script executes the following steps in order, as specified in `config.env` (optionally overridden by CLI flags):

1. **Build loop** — Iterates over `BUILD_LIST`, invoking the appropriate build function for each entry.
2. **Sign packages** — Signs all `.bolt` packages in `BOLTS_DIR` using `ralfpack` and verifies each signature.
3. **Generate outputs** — Produces `factory-app-version.json` listing each `.bolt` package and the public key with SHA-256 checksums.

### Configuration (`config.env`)

#### Build List

`BUILD_LIST` supports generic `bitbake`-based builds as well as a dedicated build type for the factory web app / UI (`refui`). To add more targets, define the per-build variables described below and append `buildname:bitbake` to `BUILD_LIST`.

```
BUILD_LIST="base:bitbake,wpe:bitbake,refui:refui"
```

Entries are comma-separated `BUILD_NAME:BUILD_TYPE` pairs, executed in the order listed.

#### Per-Build Variables

Each build named `<BUILD_NAME>` is configured with the following variables:

| Variable | Description |
|----------|-------------|
| `<BUILD_NAME>_REPO_URL` | Git repository URL |
| `<BUILD_NAME>_VERSION` | Branch or tag to clone |
| `<BUILD_NAME>_BOLT_MAKE_TARGET` | `bolt make` target name (bitbake builds only) |

#### Bolt Environment Configuration

For bitbake builds, the following variables are written to a `.env` file in the cloned repository before building:

| Variable | Default | Description |
|----------|---------|-------------|
| `BOLT_REPO_SYNC_PARAMS` | `--no-clone-bundle -j<nproc>` | Parameters passed to `repo sync` |
| `BOLT_DL_DIR` | `~/downloads` | Download directory for build artifacts (saves bandwidth on rebuilds) |
| `BOLT_SSTATE_DIR` | `~/sstate-cache` | Shared state cache directory (significantly speeds up subsequent builds) |

#### Paths

| Variable | Default | Description |
|----------|---------|-------------|
| `WORK_DIR` | `./work` | Directory where repositories are cloned |
| `BOLTS_DIR` | `./bolts` | Output directory for signed `.bolt` packages |
| `MANIFEST_FILE` | `./bolts/factory-app-version.json` | Output path for the generated manifest |

## 1. Build Loop

Reads `BUILD_LIST` from `config.env` and executes each target according to its build type.

### Build Types

| Type | Description |
|------|-------------|
| `bitbake` | Clones a Yocto/bitbake repository, runs `bitbake <target>-bolt-image`, then `bitbake bolt-env`, then `bolt make <target> --force-install` |
| `refui` | Clones a RefUI repository, runs `pack.sh`, then `bolt pack` to produce `.bolt` packages |

### Default Builds

| Name | Type | Repository |
|------|------|------------|
| `base` | `bitbake` | `rdkcentral/meta-bolt-distro` |
| `wpe` | `bitbake` | `rdkcentral/meta-bolt-wpe` |
| `refui` | `refui` | `rdkcentral/rdke-refui` |

## 2. Signing

Update the following variables in `config.env` before running the build. These are used to sign and verify the generated packages.

| Variable | Default | Description |
|----------|---------|-------------|
| `PRIVATE_KEY_PATH` | `./keys/private.key` | Path to the private signing key |
| `PUBLIC_KEY_PATH` | `./keys/public.key` | Path to the public key |
| `PRIVATE_KEY_PASSPHRASE` | _(empty)_ | Passphrase for the private key (optional) |
| `KEY_FORMAT` | `PEM` | Key format: `PEM` or `PKCS12` |
| `RALFPACK_BIN` | `/usr/bin/ralfpack` | Path to the `ralfpack` binary |

## 3. Outputs

The script produces an app manifest compatible with the [FactoryApp Install bbclass](https://github.com/rdkcentral/meta-rdk-auxiliary/blob/1.8.0/docs/install-factoryapps.md).

| Path | Description |
|------|-------------|
| `./bolts/*.bolt` | Signed bolt packages |
| `./bolts/factory-app-version.json` | Manifest containing package names, source URIs, and SHA-256 checksums |
