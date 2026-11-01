// SPDX-FileCopyrightText: 2026 Contributors to neuron
// SPDX-License-Identifier: GPL-3.0-or-later
// Additional permission: Neuron-Woflo exception; see repository-root LICENSE.md.

//! Read-only hardware identity hints for compatibility inspection.
//! A recognized VID:PID is NOT a verified feature protocol or device driver.

use serde::Deserialize;
use std::sync::LazyLock;

#[derive(Debug, Clone, Deserialize)]
pub struct HardwareHint {
    pub vendor_id: u16,
    pub product_id: u16,
    pub model: String,
    pub role: String,
}

#[derive(Deserialize)]
struct Catalog {
    device: Vec<HardwareHint>,
}

static OBSERVED: LazyLock<Vec<HardwareHint>> = LazyLock::new(|| {
    toml::from_str::<Catalog>(include_str!("../data/observed-razer-hardware.toml"))
        .expect("embedded observed hardware catalog must parse")
        .device
});

/// Some high-rate Razer receivers/mice have a verified failure mode: a legacy
/// polling write can reduce a previously configured 8 kHz link to 500 Hz.
///
/// OpenRazer issue #2950 documents this for the DeathAdder V3 Pro wireless
/// alternative PID 00C3; PID 00B3 is its HyperPolling receiver. The standard
/// 1 kHz setter must not be offered by auto-adoption on either ID. Likewise,
/// a successful extended-rate getter alone does not verify the write sequence.
/// Hardware-tested curated definitions can explicitly opt into the correct path.
/// https://github.com/openrazer/openrazer/issues/2950
#[must_use]
pub fn needs_verified_polling_write(vid: u16, pid: u16, command: &str) -> bool {
    vid == 0x1532 && matches!(pid, 0x00B3 | 0x00C3)
        && matches!(command, "set_polling" | "set_polling2")
}

/// An OS-reported hardware identity, never an assertion that a Neuron command works.
#[must_use]
pub fn observed(vid: u16, pid: u16) -> Option<&'static HardwareHint> {
    OBSERVED.iter().find(|d| d.vendor_id == vid && d.product_id == pid)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lab_models_match_observed_usb_ids() {
        assert_eq!(observed(0x1532, 0x024E).unwrap().model, "Razer BlackWidow V3");
        assert_eq!(observed(0x1532, 0x052C).unwrap().role, "audio_headset");
        assert_eq!(observed(0x1532, 0x0542).unwrap().role, "audio_microphone");
        assert_eq!(observed(0x1532, 0x0C02).unwrap().role, "mousepad");
        assert_eq!(observed(0x1532, 0x0F20).unwrap().role, "accessory");
    }

    #[test]
    fn receiver_is_not_misidentified_as_deathadder_mouse() {
        let receiver = observed(0x1532, 0x00B3).unwrap();
        assert_eq!(receiver.role, "wireless_receiver");
        assert!(!receiver.model.contains("DeathAdder"));
        assert!(observed(0x1532, 0x48F0).is_none());
        assert!(observed(0x1234, 0x024E).is_none());
    }

    #[test]
    fn unverified_high_rate_devices_never_advertise_synthetic_polling_writes() {
        for pid in [0x00B3, 0x00C3] {
            assert!(needs_verified_polling_write(0x1532, pid, "set_polling"));
            assert!(needs_verified_polling_write(0x1532, pid, "set_polling2"));
            assert!(!needs_verified_polling_write(0x1532, pid, "polling_rate"));
            assert!(!needs_verified_polling_write(0x1532, pid, "polling2"));
        }
        assert!(!needs_verified_polling_write(0x1532, 0x024E, "set_polling"));
        assert!(!needs_verified_polling_write(0x1234, 0x00B3, "set_polling"));
    }

    #[test]
    fn catalog_has_unique_id_pairs_and_no_empty_values() {
        let mut keys = std::collections::BTreeSet::new();
        for hint in OBSERVED.iter() {
            assert!(keys.insert((hint.vendor_id, hint.product_id)));
            assert!(!hint.model.is_empty() && !hint.role.is_empty());
        }
    }
}
