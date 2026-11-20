#!/usr/bin/env python3
"""Normalise le manifeste AXML exporté par Godot 4.7.2, avant alignement et signature.
Références : export_plugin.cpp du tag 4.7.2-stable et attributs AOSP public-final.xml.
"""
from __future__ import annotations
import argparse
import json
import pathlib
import re
import struct
import zipfile
NO_INDEX = 0xFFFFFFFF
ATTR_VERSION = 0x01010519
ATTR_REQUIRED = 0x0101028E

def _u32(data: bytes | bytearray, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]

def _length8(data: bytes, offset: int) -> tuple[int, int]:
    value = data[offset]
    return (((value & 0x7F) << 8) | data[offset + 1], offset + 2) if value & 0x80 else (value, offset + 1)

def _length16(data: bytes, offset: int) -> tuple[int, int]:
    value = struct.unpack_from("<H", data, offset)[0]
    return (((value & 0x7FFF) << 16) | struct.unpack_from("<H", data, offset + 2)[0], offset + 4) if value & 0x8000 else (value, offset + 2)

def _encode8(value: int) -> bytes:
    if not 0 <= value <= 0x7FFF: raise ValueError("Chaîne UTF-8 trop longue")
    return bytes([0x80 | (value >> 8), value & 255]) if value > 127 else bytes([value])

def _encode16(value: int) -> bytes:
    return struct.pack("<HH", 0x8000 | (value >> 16), value & 0xFFFF) if value > 0x7FFF else struct.pack("<H", value)

def normalize_manifest(data: bytes, package: str) -> tuple[bytes, list[str]]:
    if not re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z][a-zA-Z0-9_]*)+", package):
        raise ValueError("Identifiant Android invalide")
    if len(data) < 8 or struct.unpack_from("<HHI", data) != (3, 8, len(data)):
        raise ValueError("Manifeste AXML inattendu")
    chunks: list[bytearray] = []; offset = 8
    while offset < len(data):
        kind, header, size = struct.unpack_from("<HHI", data, offset)
        if header < 8 or size < header or offset + size > len(data): raise ValueError("Chunk AXML invalide")
        chunks.append(bytearray(data[offset:offset + size])); offset += size
    pool_index = next(i for i, c in enumerate(chunks) if struct.unpack_from("<H", c)[0] == 1)
    map_index = next(i for i, c in enumerate(chunks) if struct.unpack_from("<H", c)[0] == 0x180)
    pool = bytes(chunks[pool_index])
    _, header, _, count, styles, flags, start, styles_start = struct.unpack_from("<HHIIIIII", pool)
    if header != 28 or styles or styles_start: raise ValueError("Pool AXML non pris en charge")
    utf8 = bool(flags & 0x100); strings: list[str] = []
    for index in range(count):
        position = start + _u32(pool, 28 + 4 * index)
        if utf8:
            _, position = _length8(pool, position); length, position = _length8(pool, position)
            value = pool[position:position + length].decode("utf-8")
        else:
            length, position = _length16(pool, position); value = pool[position:position + length * 2].decode("utf-16-le")
        strings.append(value)
    resources = list(struct.unpack_from("<" + "I" * ((len(chunks[map_index]) - 8) // 4), chunks[map_index], 8))
    changes: list[str] = []; providers: list[str] = []; package_seen = False
    def intern(value: str) -> int:
        if value not in strings: strings.append(value)
        return strings.index(value)
    def typed(chunk: bytearray, position: int, kind: int, value: int) -> None:
        struct.pack_into("<I", chunk, position + 8, NO_INDEX)
        struct.pack_into("<HBBI", chunk, position + 12, 8, 0, kind, value)
    for chunk in chunks:
        if struct.unpack_from("<H", chunk)[0] != 0x102: continue
        tag = strings[_u32(chunk, 20)]
        attr_start, attr_size, attr_count = struct.unpack_from("<HHH", chunk, 24)
        if attr_size != 20 or 16 + attr_start + attr_count * attr_size > len(chunk): raise ValueError("Attributs inattendus")
        attributes = {strings[_u32(chunk, 16 + attr_start + i * attr_size + 4)]: 16 + attr_start + i * attr_size for i in range(attr_count)}
        def value(name: str) -> str:
            position = attributes[name]; raw = _u32(chunk, position + 8)
            return strings[raw] if raw != NO_INDEX else (strings[_u32(chunk, position + 16)] if chunk[position + 15] == 3 else "")
        if tag == "manifest":
            if value("package") != package: raise ValueError("Paquet inattendu")
            package_seen = True
        if tag == "uses-feature" and "required" in attributes:
            position = attributes["required"]
            if chunk[position + 15] == 3:
                raw = value("required")
                if raw not in ["true", "false"]: raise ValueError("Booléen inattendu")
                typed(chunk, position, 0x12, NO_INDEX if raw == "true" else 0)
                changes.append("typed uses-feature required=" + raw)
            name_index = _u32(chunk, position + 4)
            if name_index >= len(resources) or resources[name_index] != ATTR_REQUIRED: raise ValueError("ID required inattendu")
        if tag == "uses-feature" and "version" in attributes:
            position = attributes["version"]; name_index = _u32(chunk, position + 4)
            if chunk[position + 15] == 3:
                raw = value("version"); number = int(raw, 16 if raw.startswith("0x") else 10)
                if not 0 <= number <= NO_INDEX: raise ValueError("Version hors limites")
                typed(chunk, position, 0x11 if raw.startswith("0x") else 0x10, number)
                changes.append("typed uses-feature version=" + raw)
            if name_index >= len(resources): resources += [0] * (name_index + 1 - len(resources))
            if resources[name_index] not in [0, ATTR_VERSION]: raise ValueError("ID version inattendu")
            if resources[name_index] == 0:
                resources[name_index] = ATTR_VERSION; changes.append("mapped android:version resource ID")
        if tag == "provider":
            name = value("name"); authority = value("authorities")
            if name == "androidx.startup.InitializationProvider" and authority == package + ".fileprovider":
                position = attributes["authorities"]; authority = package + ".androidx-startup"; index = intern(authority)
                struct.pack_into("<I", chunk, position + 8, index); struct.pack_into("<HBBI", chunk, position + 12, 8, 0, 3, index)
                changes.append("restored distinct androidx-startup authority")
            providers.extend(authority.split(";"))
    if not package_seen or len(providers) != len(set(providers)): raise ValueError("Paquet absent ou autorités dupliquées")
    if not changes: return data, []
    offsets: list[int] = []; body = bytearray()
    for string in strings:
        offsets.append(len(body)); encoded16 = string.encode("utf-16-le")
        if utf8:
            encoded = string.encode("utf-8"); body += _encode8(len(encoded16) // 2) + _encode8(len(encoded)) + encoded + b"\0"
        else: body += _encode16(len(encoded16) // 2) + encoded16 + b"\0\0"
    body += b"\0" * (-len(body) % 4); start = 28 + 4 * len(strings)
    chunks[pool_index] = bytearray(struct.pack("<HHIIIIII", 1, 28, start + len(body), len(strings), 0, flags & ~1, start, 0) + struct.pack("<" + "I" * len(offsets), *offsets) + body)
    chunks[map_index] = bytearray(struct.pack("<HHI", 0x180, 8, 8 + 4 * len(resources)) + struct.pack("<" + "I" * len(resources), *resources))
    content = b"".join(chunks)
    return struct.pack("<HHI", 3, 8, 8 + len(content)) + content, changes

def normalize_apk(source: pathlib.Path, target: pathlib.Path, package: str) -> list[str]:
    if target.exists() or source.resolve() == target.resolve(): raise ValueError("Choisir une nouvelle sortie")
    with zipfile.ZipFile(source) as original:
        manifest, changes = normalize_manifest(original.read("AndroidManifest.xml"), package)
        repeated, extra = normalize_manifest(manifest, package)
        if repeated != manifest or extra: raise ValueError("Correction non idempotente")
        with zipfile.ZipFile(target, "w") as output:
            for info in original.infolist():
                if re.fullmatch(r"META-INF/(?:MANIFEST\.MF|[^/]+\.(?:RSA|DSA|EC|SF))", info.filename, re.I): continue
                output.writestr(info, manifest if info.filename == "AndroidManifest.xml" else original.read(info))
    return changes

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path); parser.add_argument("target", type=pathlib.Path)
    parser.add_argument("--package", required=True); args = parser.parse_args()
    print(json.dumps({"changes": normalize_apk(args.source, args.target, args.package), "status": "UNSIGNED_REQUIRES_ZIPALIGN_AND_APKSIGNER"}, indent=2))
if __name__ == "__main__": main()
