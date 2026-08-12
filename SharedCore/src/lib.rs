use std::ptr;

pub const ABI_VERSION: u32 = 1;
const MAXIMUM_TRAFFIC_UNIT: u32 = 4;
pub const MAXIMUM_PROXY_TYPE_INPUT_LENGTH: usize = 64;
pub const PROXY_TYPE_UNRECOGNIZED: u32 = 0;
pub const PROXY_TYPE_PROXY: u32 = 1;
pub const PROXY_TYPE_DIRECT: u32 = 2;
pub const PROXY_TYPE_REJECT: u32 = 3;

const STATUS_NULL_OUTPUT: i32 = -1;
const STATUS_INVALID_INPUT: i32 = -2;
const STATUS_INPUT_TOO_LONG: i32 = -3;

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

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MmProxyTypeClassification {
    pub category: u32,
}

impl MmProxyTypeClassification {
    fn from_input(input: &[u8]) -> Result<Self, i32> {
        if input.len() > MAXIMUM_PROXY_TYPE_INPUT_LENGTH {
            return Err(STATUS_INPUT_TOO_LONG);
        }
        if !input.is_ascii() {
            return Err(STATUS_INVALID_INPUT);
        }

        let mut normalized = [0_u8; MAXIMUM_PROXY_TYPE_INPUT_LENGTH];
        let mut normalized_length = 0;
        for byte in input {
            if byte.is_ascii_alphanumeric() {
                normalized[normalized_length] = byte.to_ascii_lowercase();
                normalized_length += 1;
            }
        }
        let normalized = &normalized[..normalized_length];

        let category = match normalized {
            b"direct" => PROXY_TYPE_DIRECT,
            b"reject" | b"rejectdrop" => PROXY_TYPE_REJECT,
            value if Self::is_concrete_proxy_type(value) => PROXY_TYPE_PROXY,
            _ => PROXY_TYPE_UNRECOGNIZED,
        };
        Ok(Self { category })
    }

    fn is_concrete_proxy_type(normalized: &[u8]) -> bool {
        const CONCRETE_PROXY_TYPES: &[&str] = &[
            "anytls",
            "http",
            "hysteria",
            "hysteria2",
            "shadowsocks",
            "shadowsocksr",
            "snell",
            "socks5",
            "ssh",
            "trojan",
            "tuic",
            "vless",
            "vmess",
            "wireguard",
        ];
        CONCRETE_PROXY_TYPES
            .iter()
            .any(|candidate| normalized == candidate.as_bytes())
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
        return STATUS_NULL_OUTPUT;
    }

    let result = MmScaledTraffic::from_bytes(bytes);
    // 安全性：上方已验证指针非空，调用方必须提供可写的完整结构体空间。
    unsafe {
        ptr::write(output, result);
    }
    0
}

#[no_mangle]
/// # Safety
///
/// `output` 必须指向可写的完整 `MmProxyTypeClassification` 结构体空间。
/// `length` 大于零时，`input` 必须指向至少 `length` 字节的可读空间。
pub unsafe extern "C" fn mm_classify_proxy_type(
    input: *const u8,
    length: u32,
    output: *mut MmProxyTypeClassification,
) -> i32 {
    if output.is_null() {
        return STATUS_NULL_OUTPUT;
    }
    if length as usize > MAXIMUM_PROXY_TYPE_INPUT_LENGTH {
        return STATUS_INPUT_TOO_LONG;
    }
    if length > 0 && input.is_null() {
        return STATUS_INVALID_INPUT;
    }

    let input = if length == 0 {
        &[]
    } else {
        // 安全性：调用方必须保证输入指针指向至少 length 字节的可读空间。
        unsafe { std::slice::from_raw_parts(input, length as usize) }
    };
    let result = match MmProxyTypeClassification::from_input(input) {
        Ok(result) => result,
        Err(status) => return status,
    };
    // 安全性：上方已验证输出指针非空，调用方必须提供可写的完整结构体空间。
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

    #[test]
    fn proxy_type_classification_preserves_mac_categories_and_normalization() {
        let cases: &[(&[u8], u32)] = &[
            (b"AnyTLS", PROXY_TYPE_PROXY),
            (b"Http", PROXY_TYPE_PROXY),
            (b"Hysteria", PROXY_TYPE_PROXY),
            (b"Hysteria-2", PROXY_TYPE_PROXY),
            (b"Shadowsocks", PROXY_TYPE_PROXY),
            (b"ShadowsocksR", PROXY_TYPE_PROXY),
            (b"Snell", PROXY_TYPE_PROXY),
            (b"SOCKS_5", PROXY_TYPE_PROXY),
            (b"Ssh", PROXY_TYPE_PROXY),
            (b"Trojan", PROXY_TYPE_PROXY),
            (b"Tuic", PROXY_TYPE_PROXY),
            (b"Vless", PROXY_TYPE_PROXY),
            (b"Vmess", PROXY_TYPE_PROXY),
            (b"Wire Guard", PROXY_TYPE_PROXY),
            (b"D-I_R E C T", PROXY_TYPE_DIRECT),
            (b"Reject-Drop", PROXY_TYPE_REJECT),
            (b"Selector", PROXY_TYPE_UNRECOGNIZED),
            (b"", PROXY_TYPE_UNRECOGNIZED),
        ];

        for (input, expected_category) in cases {
            let result = MmProxyTypeClassification::from_input(input).unwrap();
            assert_eq!(result.category, *expected_category);
        }
    }

    #[test]
    fn proxy_type_classification_enforces_ascii_and_length_boundaries() {
        let maximum_input = [b'x'; MAXIMUM_PROXY_TYPE_INPUT_LENGTH];
        assert_eq!(
            MmProxyTypeClassification::from_input(&maximum_input)
                .unwrap()
                .category,
            PROXY_TYPE_UNRECOGNIZED
        );

        let oversized_input = [b'x'; MAXIMUM_PROXY_TYPE_INPUT_LENGTH + 1];
        assert_eq!(
            MmProxyTypeClassification::from_input(&oversized_input),
            Err(STATUS_INPUT_TOO_LONG)
        );
        assert_eq!(
            MmProxyTypeClassification::from_input("Vméss".as_bytes()),
            Err(STATUS_INVALID_INPUT)
        );
    }

    #[test]
    fn proxy_type_classification_validates_abi_pointers() {
        let mut output = MmProxyTypeClassification {
            category: PROXY_TYPE_PROXY,
        };

        // 安全性：空输出指针是该 ABI 明确定义的错误输入，不会被解引用。
        let null_output_status =
            unsafe { mm_classify_proxy_type(b"Direct".as_ptr(), 6, ptr::null_mut()) };
        assert_eq!(null_output_status, STATUS_NULL_OUTPUT);

        // 安全性：非零长度配合空输入指针会在解引用前返回稳定错误码。
        let null_input_status = unsafe { mm_classify_proxy_type(ptr::null(), 1, &mut output) };
        assert_eq!(null_input_status, STATUS_INVALID_INPUT);

        // 安全性：零长度允许空输入指针，输出结构体由本测试提供完整可写空间。
        let empty_input_status = unsafe { mm_classify_proxy_type(ptr::null(), 0, &mut output) };
        assert_eq!(empty_input_status, 0);
        assert_eq!(output.category, PROXY_TYPE_UNRECOGNIZED);
    }
}
