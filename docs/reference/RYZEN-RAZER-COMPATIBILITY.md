# RYZEN Razer compatibility bring-up

This is a local Windows hardware validation plan, **not a claim that these models are fully supported**. USB identities came from Windows device enumeration captured on 2026-11-01. No system serials, container IDs or device paths are committed. No physical lighting, haptics, DPI or polling result has been observed by this branch.

## Exact observed hardware

| VID:PID | Windows device | Expected OS path | Still to verify |
|---|---|---|---|
| 1532:00B3 | HyperPolling Wireless Dongle | Standard USB/HID | Paired DeathAdder V3 Pro identity, DPI readback, *actual* 4K/8K polling |
| 1532:024E | BlackWidow V3 | Standard keyboard HID | Lighting topology, game mode, remaps and device custody |
| 1532:0C02 | Goliathus Chroma | HID + Chroma candidate | LED topology and effect response |
| 1532:0F20 | Base Station V2 Chroma | HID + accessory functions | RGB without disrupting headset or USB functions |
| 1532:052C | Kraken V3 Pro | Windows USB audio (usbaudio) | Audio baseline, THX, HyperSense and RGB independence |
| 1532:0542 | Seiren V2 Pro | Razer audio services and HID | Mic/headphone, mute, monitoring, filter and limiter |

A VID:PID match is **identity evidence only**, not evidence of a working Razer protocol. The 00B3 PID identifies the RECEIVER, not the paired mouse. The extra 48F0 Razer HID PID has no verified product name and is deliberately unmapped.

The new observed hardware catalog only informs the read-only compatibility inspector. It does not define opcodes, change driver selection, take custody of input, or shadow automatic device adoption.

**High-rate polling safeguard:** OpenRazer issue #2950 reports a DeathAdder V3 Pro
wireless-alt interface (1532:00C3) where an attempted legacy 8 kHz polling
write resulted in **500 Hz** instead. This PID was not seen in the user's
Windows inventory; it is a documented related mode. This branch now declines
to synthesize or expose unverified polling setters for 00B3 and 00C3, including
previously cached auto definitions. Reading the polling state remains possible.
No polling writes are enabled until the correct extended protocol and physical
sampling rate have been verified. See:
https://github.com/openrazer/openrazer/issues/2950


## Phase 0: retain a recovery path

Before uninstalling any software or driver:

1. Verify a restorable Windows system backup (or make one), and keep basic keyboard and mouse input available.
2. Export Synapse profiles you want to retain.
3. In an **elevated** PowerShell 7 terminal in the repository directory, run:

       pwsh -NoProfile -File .\scripts\razer-compat-baseline.ps1 -Stage Before -ExportRazerDrivers

   This script inventories Windows PnP devices, driver providers/INFs, driver services and audio endpoints. The optional switch copies installed Razer and THX OEM driver packages through pnputil /export-driver. It never removes or updates them. Check export-results.json for failures.
4. Keep the generated %LOCALAPPDATA%\neuron\razer-lab\before-* folder local. Device instance IDs, service paths and topology may be identifying; do not commit or upload the unreviewed JSON.

A driver export is not a system image and does not preserve firmware, Razer app settings, or THX service state.

## Phase 1: remove Synapse, not the Microsoft USB stack

1. Remove the Synapse app and its unwanted UI modules through Windows installed apps. Reboot.
2. Do **not** remove Microsoft HidUsb, kbdhid, mouhid, usbccgp, usbaudio or usbser services.
3. Take a second snapshot:

       pwsh -NoProfile -File .\scripts\razer-compat-baseline.ps1 -Stage After

4. Compare devices.json, drivers.json, services.json and audio-endpoints.json from both snapshots.
5. Initially retain the Seiren RazerSeirenV2Pro and RazerSeirenV2Proks services and the Kraken THX components. Test a working microphone and speaker setup before contemplating their removal.

Razer INFs can remain in the Windows Driver Store after uninstalling Synapse. Windows can rebind a stored Razer INF or download one through Windows Update. SetupAPI evidence from this machine also mentions RazerS3CoinstallerEx.dll and RzS3WizardPkgS3.exe, so an existing Razer INF may carry an old Synapse-era installer hook. An app uninstall alone does not establish a driver-free system.

Avoid blanket driver purges, forced OEM INF deletion, disabling driver signature enforcement, or weakening Windows security. Any later selective driver removal should be scoped to one identified INF, with a proven recovery path.

## Phase 2: no-write Neuron discovery, once building is authorized

No compiled or hardware-tested build is included in this phase. After the owner authorizes a build and has a working CLI, use a new local dossier:

    $folder = Join-Path $env:LOCALAPPDATA ('neuron\compat-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    .\neuron.exe compat collect --out "$folder"
    .\neuron.exe compat inspect "$folder" --local-names

Compatibility collection reads Windows and HID enumeration metadata without sending protocol commands or changing hardware. The inspector shows observed identity-only hints for these six PIDs, including observed_model_hint and observed_role_hint in JSON output. A hint never implies any device settings work.

Inspect registry_match, the report signature, descriptor completeness and any findings before running Neuron's separate read-only SYSTEM diagnostics. The automatic adoption path probes protocol getters; it is not the same as metadata-only collection.

Do not upload the private dossier's local.json. For sharing, export one device group using compat export, review the sanitized bundle, verify and pack it before attaching.

## Phase 3: controlled functional bring-up

| Test | Safe baseline | Not assumed |
|---|---|---|
| DeathAdder V3 Pro over receiver 00B3 | Cursor, buttons and stable wireless | DPI writes or 4K/8K control |
| BlackWidow V3 | Normal keyboard and Fn/Win keys | Macro remaps, RGB and firmware game mode |
| Goliathus Chroma | USB enumeration | RGB protocol or exact LED layout |
| Base Station V2 Chroma | USB/headset functionality | RGB control or hub independence |
| Kraken V3 Pro | Windows playback and microphone | THX replacement, HyperSense or RGB |
| Seiren V2 Pro | Windows input/monitoring and physical knobs | Limiter, sidetone routing, Stream Mixer |

Inspect getter responses, preserve existing high-polling settings, and require hardware readback before enabling any setter. Device-reported polling settings do not prove actual mouse report rates; verify latency and real polling separately. Rust tests or matching USB IDs cannot attest physical hardware behavior.

## Build and PR policy

- Stage source, documentation and evidence collection code on a feature branch. Do not invent device control opcodes. Promote device definitions only after hardware validation and protocol ledger updates.
- No compilation, tests, CI or installer build is authorized yet.
- The repository's GitHub Actions CI triggers on pull_request. Opening a PR therefore starts a build automatically. Leave the branch unmerged and the PR unopened until the owner approves CI/builds.
- At that point run the repository validation gate, execute read-only and then approved functional device tests, and submit the PR with an honest hardware verification report.
