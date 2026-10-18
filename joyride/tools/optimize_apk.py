#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
optimize_apk.py -- Optimizes Jetpack Joyride textures for low-memory handhelds (R36s / 1GB RAM)
- Converts heavy 4-bpp atlas textures (backgrounds) to 16-bit 2-bpp (RGBA4444) with intact dimensions.
- Downscales standalone heavy textures (notice boards, logos, UI backings) by 2x and converts to 16-bit.
"""

import os
import sys
import zipfile
import struct
import re
import ctypes
import tempfile

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 optimize_apk.py <input_apk> [output_apk]")
        sys.exit(1)

    input_apk = sys.argv[1]
    output_apk = sys.argv[2] if len(sys.argv) > 2 else input_apk

    script_dir = os.path.dirname(os.path.abspath(__file__))
    so_path = os.path.join(script_dir, "libtexconv.so")
    if not os.path.exists(so_path):
        os.system(f"gcc -O3 -fPIC -shared -o '{so_path}' '{os.path.join(script_dir, 'texconv.c')}'")

    texconv = ctypes.CDLL(so_path)
    texconv.texconv_process.argtypes = [
        ctypes.c_char_p, ctypes.c_size_t,
        ctypes.c_char_p, ctypes.c_size_t,
        ctypes.c_int
    ]
    texconv.texconv_process.restype = ctypes.c_int

    print(f"Opening APK: {input_apk}")
    zin = zipfile.ZipFile(input_apk, "r")

    # Discover all texture filenames referenced by atlases
    atlas_texs = set()
    for name in zin.namelist():
        if name.endswith(".atlas"):
            data = zin.read(name)
            matches = re.findall(rb"[a-zA-Z0-9_/.-]+\.tex", data)
            for m in matches:
                atlas_texs.add(m.decode().split("/")[-1])

    print(f"Identified {len(atlas_texs)} atlas texture names.")

    tmp_out = output_apk + ".tmp"
    zout = zipfile.ZipFile(tmp_out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6)

    orig_total_bytes = 0
    new_total_bytes = 0
    converted_atlas_count = 0
    downscaled_count = 0
    total_tex_count = 0

    out_buf = ctypes.create_string_buffer(32 * 1024 * 1024)

    for info in zin.infolist():
        raw = zin.read(info)
        orig_len = len(raw)

        if not info.filename.endswith(".tex") or orig_len < 52 or not raw.startswith(b"TEX\x01"):
            zout.writestr(info, raw)
            continue

        total_tex_count += 1
        orig_total_bytes += orig_len
        base = info.filename.split("/")[-1]

        ints = struct.unpack("<13I", raw[:52])
        w = ints[7]
        h = ints[8]
        sz = ints[12]

        if w == 0 or h == 0 or (w * h) == 0:
            zout.writestr(info, raw)
            new_total_bytes += orig_len
            continue

        bpp = sz // (w * h)
        processed = False

        if base in atlas_texs:
            if bpp == 4:
                # Mode 1: convert 4bpp to 2bpp, preserve dimensions
                res_sz = texconv.texconv_process(raw, orig_len, out_buf, len(out_buf), 1)
                if res_sz > 0:
                    zout.writestr(info, out_buf.raw[:res_sz])
                    new_total_bytes += res_sz
                    converted_atlas_count += 1
                    processed = True
        else:
            # Standalone texture: downscale if >= 128KB or (w >= 256 or h >= 256)
            if (orig_len >= 128 * 1024 or max(w, h) >= 256) and w >= 4 and h >= 4:
                mode = 2 if bpp == 4 else (3 if bpp == 2 else 0)
                if mode > 0:
                    res_sz = texconv.texconv_process(raw, orig_len, out_buf, len(out_buf), mode)
                    if res_sz > 0:
                        zout.writestr(info, out_buf.raw[:res_sz])
                        new_total_bytes += res_sz
                        downscaled_count += 1
                        processed = True
            elif bpp == 4:
                # Convert remaining 32-bit textures to 16-bit to minimize memory and GPU bandwidth
                res_sz = texconv.texconv_process(raw, orig_len, out_buf, len(out_buf), 1)
                if res_sz > 0:
                    zout.writestr(info, out_buf.raw[:res_sz])
                    new_total_bytes += res_sz
                    converted_atlas_count += 1
                    processed = True

        if not processed:
            zout.writestr(info, raw)
            new_total_bytes += orig_len

    zin.close()
    zout.close()

    os.replace(tmp_out, output_apk)

    saved_mb = (orig_total_bytes - new_total_bytes) / (1024 * 1024)
    print("=" * 60)
    print("Optimization complete!")
    print(f"Total .tex files:            {total_tex_count}")
    print(f"Atlas textures converted:    {converted_atlas_count} (32-bit -> 16-bit, same dims)")
    print(f"Standalone downscaled:       {downscaled_count} (2x downscaled + 16-bit)")
    print(f"Original texture uncomp size:{orig_total_bytes / (1024*1024):.2f} MB")
    print(f"Optimized texture uncomp:   {new_total_bytes / (1024*1024):.2f} MB")
    print(f"Texture RAM saved:           {saved_mb:.2f} MB")
    print(f"Resulting APK file:          {output_apk} ({os.path.getsize(output_apk)/(1024*1024):.2f} MB)")
    print("=" * 60)

if __name__ == "__main__":
    main()
