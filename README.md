# Factory App Bolt Package Build System

Build scripts for assembling, packaging, signing, and generating manifests for RDK-E factory app bolt packages on a Linux host.

| File | Description |
|------|-------------|
| `master.sh` | Main build orchestrator script |
| `config.env` | Build configuration (repositories, versions, keys, paths) |

### Prerequisites

The `bolt` package build system is Yocto-based. Ensure the build host satisfies the requirements for [Kirkstone-based builds](https://docs.yoctoproject.org/kirkstone/ref-manual/system-requirements.html#required-packages-for-the-build-host), and that the following are available:

- `repo` tool — see [Install repo tool](https://android.googlesource.com/tools/repo)
- `git`
- `ralfpack` binary (default path: `/usr/bin/ralfpack`) — must be [built for the host](https://github.com/rdkcentral/ralfpack)
- Signing key pair (PEM or PKCS12 format)

## Usage

```bash
bash master.sh
```

By default, `master.sh` reads `./config.env`. To specify an alternative configuration file:

```bash
CONFIG_FILE=/path/to/custom.env bash master.sh
```

## Build Pipeline

The script executes the following steps in order, as specified in `config.env`:

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
| `<BUILD_NAME>_ENV_CONTENT` | Content written to `.env` in the cloned repository |

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
| `bitbake` | Clones a Yocto/bitbake repository, runs `bitbake bolt-env`, then `bolt make <target> --install` |
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
| `PRIVATE_KEY_PATH` | `/path/to/keys/private.key` | Path to the private signing key |
| `PUBLIC_KEY_PATH` | `/path/to/keys/public.key` | Path to the public key |
| `PRIVATE_KEY_PASSPHRASE` | _(empty)_ | Passphrase for the private key (optional) |
| `KEY_FORMAT` | `PEM` | Key format: `PEM` or `PKCS12` |
| `RALFPACK_BIN` | `/usr/bin/ralfpack` | Path to the `ralfpack` binary |

## 3. Outputs

The script produces an app manifest compatible with the [FactoryApp Install bbclass](https://github.com/rdkcentral/meta-rdk-auxiliary/blob/1.8.0/docs/install-factoryapps.md).

| Path | Description |
|------|-------------|
| `./bolts/*.bolt` | Signed bolt packages |
| `./bolts/factory-app-version.json` | Manifest containing package names, source URIs, and SHA-256 checksums |
