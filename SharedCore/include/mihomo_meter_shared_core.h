#ifndef MIHOMO_METER_SHARED_CORE_H
#define MIHOMO_METER_SHARED_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
#define MM_SHARED_CORE_ABI_VERSION 1u
#define MM_PROXY_TYPE_MAX_INPUT_LENGTH 64u
#define MM_PROXY_TYPE_UNRECOGNIZED 0u
#define MM_PROXY_TYPE_PROXY 1u
#define MM_PROXY_TYPE_DIRECT 2u
#define MM_PROXY_TYPE_REJECT 3u
#define MM_SHARED_CORE_STATUS_NULL_OUTPUT -1
#define MM_SHARED_CORE_STATUS_INVALID_INPUT -2
#define MM_SHARED_CORE_STATUS_INPUT_TOO_LONG -3

typedef struct mm_scaled_traffic {
  double value;
  uint32_t unit;
  uint32_t decimal_places;
} mm_scaled_traffic_t;

typedef struct mm_proxy_type_classification {
  uint32_t category;
} mm_proxy_type_classification_t;

uint32_t mm_core_abi_version(void);
int32_t mm_scale_traffic(uint64_t bytes, mm_scaled_traffic_t *output);
int32_t mm_classify_proxy_type(const uint8_t *input, uint32_t length,
                               mm_proxy_type_classification_t *output);

#ifdef __cplusplus
}
#endif

#endif
