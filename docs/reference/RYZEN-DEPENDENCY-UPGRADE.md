# Rust 1.99.1 dependency upgrade (RYZEN)

Work branch: feature/ryzen-razer-device-compat. Main remains unchanged.

## Status

The repository toolchain, CI and release workflows now target Rust 1.99.1.
Major/direct dependency requirements were moved forward for Slint, Windows-Sys,
CPAL, tray-icon, global-hotkey, quick-xml, TOML, zip, png, dirs, base64,
sha2 and ctor. Source adjustments include CPAL stream configs by value,
quick-xml string-based events and ctor's explicit unsafe constructor marker.

**Neither Cargo.lock nor a compiled/tested artifact has been produced by this
repository-only edit.** The original lockfile is deliberately untouched rather
than being fabricated. The Windows RYZEN checkout must resolve dependencies
with Cargo 1.99.1 and commit the generated lockfile. A successful dependency
resolution does not guarantee that source code compiles after API migrations.

The bundled CPython 3.12.13 (python-build-standalone 20260610) is a separate,
SHA-verified runtime payload, not a Cargo dependency. This upgrade does not
silently replace it.

## Finish upgrading the entire workspace on RYZEN

Open PowerShell 7 in a **normal, non-elevated** Windows session. Ensure Git,
Rust 1.99.1, Visual Studio 2022 MSVC tooling, the Windows SDK and Internet
access are available. From a clean checkout of this branch:

    git fetch origin
    git switch feature/ryzen-razer-device-compat
    git pull --ff-only

Install the Cargo manifest-upgrade helper:

    cargo install cargo-edit --locked

Then upgrade all seven workspace manifests, including explicit incompatible
version requirements and transitive locked versions, using Cargo's resolver:

    .\scripts\upgrade-dependencies.ps1 -DryRun
    .\scripts\upgrade-dependencies.ps1

The first command is optional preview. The second updates every direct
dependency declaration across workspace crates, plus Cargo.lock. It checks
against the Rust 1.99.1 compatibility target. Versions not manually changed
in this branch (including serde, clap, regex, rayon, libc, proptest, tar, ureq
and the remaining Cargo direct dependencies) are upgraded by this pass.
Read the diff to catch obsolete features or libraries before compiling.

Build stages:

    cargo check --workspace --all-targets --locked
    .\validate.ps1 -Locked
    .\release.ps1 -NoRelaunch

Do not start Neuron or uninstall Synapse until the build checks succeed.
Validate the feature-flag variant before release:

    .\validate.ps1 -Mode full -Locked

Only commit the resulting Cargo.lock and any necessary source migrations
after this native RYZEN check. Commit from the feature branch, not main.
Do not open a PR until the changes are ready: the existing CI configuration
starts Windows and Linux builds on pull_request.

## Breaking API migration hotspots

- **quick-xml 0.42**: element names and text are strings rather than bytes,
  and XML text unescaping uses xml_content(XmlVersion).
- **CPAL 0.18**: StreamConfig is passed by value; Stream::play remains
  required to start playback. Check notifications and audio callbacks on
  RYZEN after compilation.
- **Slint 1.18**: the old unstable-wgpu-28 feature was removed; the opt-in
  renderer now uses unstable-wgpu-30. Inspect WGPU rendering separately.
- **windows-sys 0.61**: new bindings can change Win32 FFI signatures;
  compile the Windows targets, not just the shared core.
- **ctor 1.0**: test constructors require #[ctor::ctor(unsafe)].
- **zip 8, png 0.18, sha2 0.11**: review compatibility and run import,
  export, cryptographic verification and image tests.

No crate publication, firmware update, driver removal or hardware writes are
part of this dependency upgrade.
