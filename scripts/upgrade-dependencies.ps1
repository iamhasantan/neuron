# SPDX-FileCopyrightText: 2026 Contributors to neuron
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Upgrade EVERY direct crates.io dependency declaration in the workspace to the
# latest release compatible with Rust 1.99.1. Then resolve every transitive
# dependency through Cargo itself. Never manually edit Cargo.lock.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expected = '1.99.1'

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Rust/Cargo not found. Install Rust stable MSVC and reopen PowerShell.'
}
if (-not (Get-Command cargo-upgrade -ErrorAction SilentlyContinue)) {
    throw 'cargo-edit is required. Install with: cargo install cargo-edit --locked'
}

Push-Location $repo
try {
    $rustcVersion = (& rustc --version 2>&1) -join ' '
    if ($LASTEXITCODE -ne 0 -or $rustcVersion -notmatch [regex]::Escape("rustc $expected")) {
        throw "This branch requires Rust $expected. Found: $rustcVersion"
    }

    $manifests = @(
        'Cargo.toml',
        'crates/engram/Cargo.toml',
        'crates/neuron-core/Cargo.toml',
        'crates/neuron-host/Cargo.toml',
        'crates/neuron-cli/Cargo.toml',
        'crates/neuron-app/Cargo.toml',
        'crates/neuron-testkit/Cargo.toml'
    )

    # Enumerate explicitly to include build, development and platform-specific
    # dependencies. cargo upgrade changes manifests; cargo update changes the lockfile.
    foreach ($relative in $manifests) {
        $manifest = Join-Path $repo $relative
        Write-Host "Upgrade direct dependencies: $relative" -ForegroundColor Cyan
        $arguments = @(
            'upgrade', '--manifest-path', $manifest,
            '--incompatible', 'allow',
            '--pinned', 'allow',
            '--rust-version', $expected
        )
        if ($DryRun) { $arguments += '--dry-run' }
        & cargo @arguments
        if ($LASTEXITCODE -ne 0) { throw "cargo upgrade failed for $relative (exit $LASTEXITCODE)" }
    }

    if ($DryRun) {
        Write-Host 'Dry run: no manifests or lockfile were changed.' -ForegroundColor Yellow
        & cargo update --dry-run
    } else {
        Write-Host 'Resolve latest transitive dependencies and regenerate Cargo.lock.' -ForegroundColor Cyan
        & cargo update
    }
    if ($LASTEXITCODE -ne 0) { throw "cargo update failed (exit $LASTEXITCODE)" }

    if (-not $DryRun) {
        Write-Host 'Verify workspace resolves with the current Cargo.lock.' -ForegroundColor Cyan
        & cargo metadata --format-version 1 --locked --no-deps | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Cargo metadata/lockfile verification failed' }
    }

    if ($Check -and -not $DryRun) {
        Write-Host 'Checking all workspace targets (compiles, no execution).' -ForegroundColor Cyan
        & cargo check --workspace --all-targets --locked
        if ($LASTEXITCODE -ne 0) { throw 'Cargo check failed: adjust breaking APIs before testing' }
    }
    Write-Host 'Review git diff, particularly dependency features, then run the test suite.' -ForegroundColor Green
} finally {
    Pop-Location
}
