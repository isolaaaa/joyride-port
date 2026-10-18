/* SPDX-License-Identifier: MIT */
/* texconv.c -- Fast .tex texture converter and downscaler */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define TEX_MAGIC 0x01584554 /* "TEX\x01" in little-endian */

/*
 * Returns:
 *   > 0: output size in bytes
 *   0: skipped or error
 */
int texconv_process(
    const uint8_t *in, size_t in_size,
    uint8_t *out, size_t out_max,
    int mode /* 1: convert_4to2 (same size), 2: downscale_4to2 (half size), 3: downscale_2to2 (half size) */
) {
    if (!in || !out || in_size < 52)
        return 0;

    const uint32_t *in_hdr = (const uint32_t *)in;
    if (in_hdr[0] != TEX_MAGIC)
        return 0;

    uint32_t w = in_hdr[7];
    uint32_t h = in_hdr[8];
    uint32_t sz = in_hdr[12];

    if (w == 0 || h == 0 || in_size < 52 + sz)
        return 0;

    uint32_t bpp = sz / (w * h);
    uint32_t *out_hdr = (uint32_t *)out;
    memcpy(out, in, 52);

    if (mode == 1) {
        /* Convert 4-bpp to 2-bpp, same dimensions */
        if (bpp != 4)
            return 0;
        size_t out_data_sz = (size_t)w * h * 2;
        if (52 + out_data_sz > out_max)
            return 0;

        out_hdr[1] = 0x01000000;
        out_hdr[2] = 0x03040204;
        out_hdr[3] = 0x01040404;
        out_hdr[12] = (uint32_t)out_data_sz;

        const uint8_t *src = in + 52;
        uint16_t *dst = (uint16_t *)(out + 52);
        size_t total_pixels = (size_t)w * h;

        for (size_t i = 0; i < total_pixels; i++) {
            uint16_t r = src[i * 4 + 0] >> 4;
            uint16_t g = src[i * 4 + 1] >> 4;
            uint16_t b = src[i * 4 + 2] >> 4;
            uint16_t a = src[i * 4 + 3] >> 4;
            dst[i] = (r << 12) | (g << 8) | (b << 4) | a;
        }

        return (int)(52 + out_data_sz);
    } else if (mode == 2) {
        /* Downscale 4-bpp to 2-bpp, half dimensions */
        if (bpp != 4 || w < 2 || h < 2)
            return 0;

        uint32_t nw = w / 2;
        uint32_t nh = h / 2;
        size_t out_data_sz = (size_t)nw * nh * 2;
        if (52 + out_data_sz > out_max)
            return 0;

        out_hdr[1] = 0x01000000;
        out_hdr[2] = 0x03040204;
        out_hdr[3] = 0x01040404;
        out_hdr[5] = (nh << 16) | nw;
        out_hdr[7] = nw;
        out_hdr[8] = nh;
        out_hdr[12] = (uint32_t)out_data_sz;

        const uint8_t *src = in + 52;
        uint16_t *dst = (uint16_t *)(out + 52);

        for (uint32_t y = 0; y < nh; y++) {
            size_t r0 = (size_t)(2 * y) * w * 4;
            size_t r1 = (size_t)(2 * y + 1) * w * 4;
            for (uint32_t x = 0; x < nw; x++) {
                size_t p00 = r0 + (size_t)(2 * x) * 4;
                size_t p01 = r0 + (size_t)(2 * x + 1) * 4;
                size_t p10 = r1 + (size_t)(2 * x) * 4;
                size_t p11 = r1 + (size_t)(2 * x + 1) * 4;

                uint16_t r = (src[p00 + 0] + src[p01 + 0] + src[p10 + 0] + src[p11 + 0]) >> 6;
                uint16_t g = (src[p00 + 1] + src[p01 + 1] + src[p10 + 1] + src[p11 + 1]) >> 6;
                uint16_t b = (src[p00 + 2] + src[p01 + 2] + src[p10 + 2] + src[p11 + 2]) >> 6;
                uint16_t a = (src[p00 + 3] + src[p01 + 3] + src[p10 + 3] + src[p11 + 3]) >> 6;

                dst[(size_t)y * nw + x] = (r << 12) | (g << 8) | (b << 4) | a;
            }
        }

        return (int)(52 + out_data_sz);
    } else if (mode == 3) {
        /* Downscale 2-bpp to 2-bpp, half dimensions */
        if (bpp != 2 || w < 2 || h < 2)
            return 0;

        uint32_t nw = w / 2;
        uint32_t nh = h / 2;
        size_t out_data_sz = (size_t)nw * nh * 2;
        if (52 + out_data_sz > out_max)
            return 0;

        out_hdr[5] = (nh << 16) | nw;
        out_hdr[7] = nw;
        out_hdr[8] = nh;
        out_hdr[12] = (uint32_t)out_data_sz;

        const uint16_t *src = (const uint16_t *)(in + 52);
        uint16_t *dst = (uint16_t *)(out + 52);

        for (uint32_t y = 0; y < nh; y++) {
            size_t r0 = (size_t)(2 * y) * w;
            size_t r1 = (size_t)(2 * y + 1) * w;
            for (uint32_t x = 0; x < nw; x++) {
                uint16_t v00 = src[r0 + 2 * x];
                uint16_t v01 = src[r0 + 2 * x + 1];
                uint16_t v10 = src[r1 + 2 * x];
                uint16_t v11 = src[r1 + 2 * x + 1];

                uint16_t r = (((v00 >> 12) & 0xf) + ((v01 >> 12) & 0xf) + ((v10 >> 12) & 0xf) + ((v11 >> 12) & 0xf) + 2) >> 2;
                uint16_t g = (((v00 >>  8) & 0xf) + ((v01 >>  8) & 0xf) + ((v10 >>  8) & 0xf) + ((v11 >>  8) & 0xf) + 2) >> 2;
                uint16_t b = (((v00 >>  4) & 0xf) + ((v01 >>  4) & 0xf) + ((v10 >>  4) & 0xf) + ((v11 >>  4) & 0xf) + 2) >> 2;
                uint16_t a = (( v00        & 0xf) + ( v01        & 0xf) + ( v10        & 0xf) + ( v11        & 0xf) + 2) >> 2;

                dst[(size_t)y * nw + x] = (r << 12) | (g << 8) | (b << 4) | a;
            }
        }

        return (int)(52 + out_data_sz);
    }

    return 0;
}
