#ifndef MIHOMO_METER_SHARED_CORE_H
#define MIHOMO_METER_SHARED_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
#define MM_SHARED_CORE_ABI_VERSION 1u

typedef struct mm_scaled_traffic {
  double value;
  uint32_t unit;
  uint32_t decimal_places;
} mm_scaled_traffic_t;

uint32_t mm_core_abi_version(void);
int32_t mm_scale_traffic(uint64_t bytes, mm_scaled_traffic_t *output);

#ifdef __cplusplus
}
#endif

#endif
