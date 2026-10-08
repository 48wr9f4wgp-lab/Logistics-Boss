#!/usr/bin/env python3
"""New-run, read-only PCK resource diagnostics. Never changes qualification outcome."""
import ctypes
import ctypes.util
import hashlib
import json
from pathlib import Path
import struct
import sys


def resources(path):
    data = Path(path).read_bytes()
    magic, version, major, minor, patch, flags, base, directory = struct.unpack_from('<6I2Q', data)
    assert magic == 0x43504447 and version == 4 and not flags & 1, 'Expected unencrypted Godot4 PCK'
    count = struct.unpack_from('<I', data, directory)[0]
    cursor = directory + 4
    entries = {}
    for _ in range(count):
        length = struct.unpack_from('<I', data, cursor)[0]
        cursor += 4
        name = data[cursor:cursor + length].rstrip(b'\0').decode('utf-8')
        cursor += length
        offset, size = struct.unpack_from('<QQ', data, cursor)
        cursor += 16
        expected_md5 = data[cursor:cursor + 16]
        cursor += 16
        entry_flags = struct.unpack_from('<I', data, cursor)[0]
        cursor += 4
        raw = data[base + offset:base + offset + size]
        assert len(raw) == size and hashlib.md5(raw).digest() == expected_md5, name
        assert not entry_flags & 1, 'Encrypted resource is not diagnostic input'
        assert name not in entries, 'Duplicate resource path'
        entries[name] = raw
    return entries


def scene_bytes(data):
    if data[:4] != b'RSCC':
        return data
    mode, block_size, total = struct.unpack_from('<3I', data, 4)
    assert mode == 2, 'Only official Zstd scene compression is supported'
    count = (total + block_size - 1) // block_size
    sizes = struct.unpack_from('<' + 'I' * count, data, 16)
    cursor = 16 + 4 * count
    lib = ctypes.CDLL(ctypes.util.find_library('zstd'))
    lib.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
    lib.ZSTD_decompress.restype = ctypes.c_size_t
    lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
    lib.ZSTD_isError.restype = ctypes.c_uint
    parts = []
    for size in sizes:
        compressed = data[cursor:cursor + size]
        cursor += size
        out = ctypes.create_string_buffer(block_size)
        written = lib.ZSTD_decompress(out, block_size, compressed, len(compressed))
        assert not lib.ZSTD_isError(written), 'Invalid compressed scene block'
        parts.append(out.raw[:written])
    result = b''.join(parts)
    assert len(result) == total
    return result


def node_id_field(data):
    # Diagnostic recognition only. These bytes are NEVER normalized or ignored
    # by verify_writer_export.py. Unknown/multiple patterns remain unclassified.
    marker = b'\x05\x00\x00\x00\x09\x00\x00\x00node_ids\x00\x20\x00\x00\x00'
    if data.count(marker) != 1:
        return None
    count_offset = data.index(marker) + len(marker)
    count = struct.unpack_from('<I', data, count_offset)[0]
    begin = count_offset + 4
    end = begin + count * 4
    assert 0 < count < 10000 and end <= len(data)
    return {'offset': begin, 'end': end, 'count': count,
            'values': list(struct.unpack_from('<' + 'i' * count, data, begin))}


def compare(old_path, new_path):
    old, new = resources(old_path), resources(new_path)
    report = {'scope': 'Read-only resource diagnostic for this run; no equality exemption',
              'candidateSHA256': hashlib.sha256(Path(old_path).read_bytes()).hexdigest(),
              'fullExportSHA256': hashlib.sha256(Path(new_path).read_bytes()).hexdigest(),
              'candidateResourceCount': len(old), 'fullExportResourceCount': len(new),
              'unchanged': 0, 'differences': []}
    for name in sorted(set(old) | set(new)):
        a, b = old.get(name), new.get(name)
        if a == b:
            report['unchanged'] += 1
            continue
        row = {'path': name, 'candidateSHA256': hashlib.sha256(a).hexdigest() if a is not None else None,
               'fullExportSHA256': hashlib.sha256(b).hexdigest() if b is not None else None,
               'candidateSize': len(a) if a is not None else None, 'fullExportSize': len(b) if b is not None else None}
        if a is not None and b is not None and name.endswith('.scn'):
            x, y = scene_bytes(a), scene_bytes(b)
            left, right = node_id_field(x), node_id_field(y)
            row.update(decompressedSizes=[len(x), len(y)], candidateNodeIds=left, fullExportNodeIds=right)
            row['differingDecompressedBytes'] = sum(i != j for i, j in zip(x, y)) + abs(len(x) - len(y))
            row['differenceConfinedToRecognizedNodeIds'] = bool(left and right and
                left['offset'] == right['offset'] and left['end'] == right['end'] and
                x[:left['offset']] == y[:right['offset']] and x[left['end']:] == y[right['end']:])
        report['differences'].append(row)
    return report


if __name__ == '__main__':
    report = compare(sys.argv[1], sys.argv[2])
    Path(sys.argv[3]).write_text(json.dumps(report, indent=2) + '\n')
    print('WRITER_PACK_DIAGNOSTIC ' + json.dumps(report))
