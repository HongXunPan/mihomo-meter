use std::ptr;

pub const ABI_VERSION: u32 = 1;
const MAXIMUM_TRAFFIC_UNIT: u32 = 4;

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MmScaledTraffic {
    pub value: f64,
    pub unit: u32,
    pub decimal_places: u32,
}

impl MmScaledTraffic {
    fn from_bytes(bytes: u64) -> Self {
        let mut value = bytes as f64;
        let mut unit = 0;
        while value >= 1_000.0 && unit < MAXIMUM_TRAFFIC_UNIT {
            value /= 1_000.0;
            unit += 1;
        }

        let decimal_places = if unit == 0 || value >= 100.0 {
            0
        } else if value >= 10.0 {
            1
        } else {
            2
        };

        Self {
            value,
            unit,
            decimal_places,
        }
    }
}

#[no_mangle]
pub extern "C" fn mm_core_abi_version() -> u32 {
    ABI_VERSION
}

#[no_mangle]
/// # Safety
///
/// `output` 必须指向可写的完整 `MmScaledTraffic` 结构体空间，或传入空指针获取错误码。
pub unsafe extern "C" fn mm_scale_traffic(bytes: u64, output: *mut MmScaledTraffic) -> i32 {
    if output.is_null() {
        return -1;
    }

    let result = MmScaledTraffic::from_bytes(bytes);
    // 安全性：上方已验证指针非空，调用方必须提供可写的完整结构体空间。
    unsafe {
        ptr::write(output, result);
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn abi_version_is_stable() {
        assert_eq!(mm_core_abi_version(), 1);
    }

    #[test]
    fn traffic_scaling_uses_decimal_units_and_mac_precision() {
        let cases = [
            (0, 0.0, 0, 0),
            (999, 999.0, 0, 0),
            (1_000, 1.0, 1, 2),
            (1_500, 1.5, 1, 2),
            (10_000, 10.0, 1, 1),
            (100_000, 100.0, 1, 0),
            (1_000_000, 1.0, 2, 2),
            (1_000_000_000_000, 1.0, 4, 2),
        ];

        for (bytes, expected_value, expected_unit, expected_decimal_places) in cases {
            let result = MmScaledTraffic::from_bytes(bytes);
            assert!((result.value - expected_value).abs() < f64::EPSILON);
            assert_eq!(result.unit, expected_unit);
            assert_eq!(result.decimal_places, expected_decimal_places);
        }
    }

    #[test]
    fn traffic_scaling_rejects_null_output_pointer() {
        // 安全性：空指针是该 ABI 明确定义的错误输入，不会被解引用。
        let status = unsafe { mm_scale_traffic(1_000, ptr::null_mut()) };
        assert_eq!(status, -1);
    }
}
