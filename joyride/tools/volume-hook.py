#!/usr/bin/env python3
"""muOS volume keys hook; native input event listener for ALSA mixer."""
import glob, os, re, select, struct, subprocess

EVENT = struct.Struct('@llHHi')
MIXER_ENV = dict(os.environ)
for key in ('ALSA_CONFIG_PATH', 'ALSA_CARD'):
    MIXER_ENV.pop(key, None)

def volume():
    try:
        out = subprocess.check_output(['amixer', '-c', '0', 'get', 'digital volume'], text=True, env=MIXER_ENV)
        match = re.search(r'Mono:\s*(\d+)', out)
        limits = re.search(r'Limits:.*?(\d+)\s*-\s*(\d+)', out)
        return (int(match[1]), int(limits[1]), int(limits[2])) if match and limits else None
    except Exception:
        return None

def main():
    streams = []
    for path in glob.glob('/dev/input/event*'):
        try:
            streams.append(open(path, 'rb', buffering=0))
        except OSError:
            pass
    if not streams:
        print('muOS volume hook: no readable input devices', flush=True)
        return
    try:
        while streams:
            ready, _, _ = select.select(streams, [], [])
            for stream in ready:
                data = stream.read(EVENT.size)
                if len(data) != EVENT.size:
                    streams.remove(stream)
                    stream.close()
                    continue
                _, _, typ, code, value = EVENT.unpack(data)
                if typ != 1 or value not in (1, 2) or code not in (114, 115):
                    continue
                state = volume()
                if state:
                    current, low, high = state
                    step = max(1, round((high - low) * 6 / 63))
                    target = max(low, min(high, current + (-step if code == 114 else step)))
                    subprocess.run(
                        ['amixer', '-c', '0', 'set', 'digital volume', str(target)],
                        stdout=subprocess.DEVNULL,
                        check=False,
                        env=MIXER_ENV,
                    )
    finally:
        for stream in streams:
            try:
                stream.close()
            except Exception:
                pass

if __name__ == '__main__':
    main()
