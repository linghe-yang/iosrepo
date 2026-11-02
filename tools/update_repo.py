"""Generate or check this flat APT repository. Python standard library only."""
import argparse
import bz2
from datetime import datetime, timezone
from email.utils import format_datetime
import gzip
import hashlib
import io
import lzma
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[1]
INDEXES = ("Packages", "Packages.gz", "Packages.bz2", "Packages.xz")
ALGORITHMS = {"MD5Sum": "md5", "SHA1": "sha1", "SHA256": "sha256", "SHA512": "sha512"}


def fields(text):
    return dict(line.split(": ", 1) for line in text.splitlines()
                if line and not line[0].isspace() and ": " in line)


def control(data):
    if data[:8] != b"!<arch>\n":
        raise ValueError("Invalid DEB header")
    position = 8
    while position < len(data):
        header = data[position:position + 60]
        if len(header) != 60 or header[58:60] != b"`\n":
            raise ValueError("Invalid DEB member header")
        name, size = header[:16].strip().rstrip(b"/"), int(header[48:58])
        if name.startswith(b"control.tar"):
            with tarfile.open(fileobj=io.BytesIO(data[position + 60:position + 60 + size]), mode="r:*") as archive:
                member = next(item for item in archive if item.name.removeprefix("./") == "control")
                return archive.extractfile(member).read().decode("utf-8").replace("\r\n", "\n").strip()
        position += 60 + size + size % 2
    raise ValueError("DEB has no control archive")


def generate():
    paragraphs, architectures, identities = [], set(), set()
    for path in sorted((ROOT / "debs").rglob("*.deb")):
        data = path.read_bytes()
        text = control(data)
        metadata = fields(text)
        identity = tuple(metadata[key] for key in ("Package", "Version", "Architecture"))
        if identity in identities:
            raise ValueError(f"Duplicate package/version/architecture: {identity}")
        identities.add(identity)
        architectures.add(metadata["Architecture"])
        relative = path.relative_to(ROOT).as_posix()
        text += f"\nFilename: ./{relative}\nSize: {len(data)}\n"
        for field, algorithm in [("MD5sum", "md5"), ("SHA1", "sha1"), ("SHA256", "sha256"), ("SHA512", "sha512")]:
            text += f"{field}: {hashlib.new(algorithm, data).hexdigest()}\n"
        paragraphs.append(text)
    if not paragraphs:
        raise ValueError("No DEBs in debs/")
    index = ("\n".join(paragraphs) + "\n").encode("utf-8")
    return {"Packages": index, "Packages.gz": gzip.compress(index, mtime=0),
            "Packages.bz2": bz2.compress(index), "Packages.xz": lzma.compress(index)}, sorted(architectures), len(paragraphs)


def check(expected, architectures):
    # Check semantic decompression instead of assuming a particular compressor version.
    if (ROOT / "Packages").read_bytes() != expected["Packages"]:
        raise ValueError("Packages is stale; regenerate indexes")
    for name, decompress in [("Packages.gz", gzip.decompress), ("Packages.bz2", bz2.decompress), ("Packages.xz", lzma.decompress)]:
        if decompress((ROOT / name).read_bytes()) != expected["Packages"]:
            raise ValueError(f"Stale compressed index: {name}")
    release = (ROOT / "Release").read_text(encoding="utf-8")
    release_fields = fields(release)
    required = {"Origin", "Label", "Suite", "Codename", "Architectures", "Components"}
    if not required.issubset(release_fields) or not release_fields["Components"].strip():
        raise ValueError("Release is missing required repository metadata, including Components required by Sileo")
    if release_fields["Architectures"].split() != architectures:
        raise ValueError("Release architectures do not match packages")
    algorithm, checked = None, set()
    for line in release.splitlines():
        if line.endswith(":") and line[:-1] in ALGORITHMS:
            algorithm = ALGORITHMS[line[:-1]]
        elif line.startswith(" "):
            digest, size, name = line.split()
            if name not in INDEXES or algorithm is None:
                raise ValueError("Unexpected Release checksum entry")
            data = (ROOT / name).read_bytes()
            if len(data) != int(size) or hashlib.new(algorithm, data).hexdigest() != digest:
                raise ValueError(f"Release checksum mismatch: {name}")
            checked.add((algorithm, name))
    if checked != {(algorithm, name) for algorithm in ALGORITHMS.values() for name in INDEXES}:
        raise ValueError("Release is missing checksum entries")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check without writing files")
    args = parser.parse_args()
    if not args.check and any((ROOT / name).exists() for name in ("Release.gpg", "InRelease", "Packages.zst", "Packages.lzma")):
        raise ValueError("Signed metadata or additional index formats detected; use a matching generation/signing process")
    outputs, architectures, count = generate()
    if not args.check:
        old = fields((ROOT / "Release").read_text(encoding="utf-8")) if (ROOT / "Release").exists() else {}
        release = "".join(f"{key}: {old.get(key, default)}\n" for key, default in [
            ("Origin", "sangeeeee iOS Repo"), ("Label", "sangeeeee iOS Repo"),
            ("Suite", "stable"), ("Codename", "stable"), ("Components", "main")])
        release += "Architectures: " + " ".join(architectures) + "\n"
        release += f"Date: {format_datetime(datetime.now(timezone.utc), usegmt=True)}\n"
        release += f"Description: {old.get('Description', 'Personal jailbreak package repository')}\n"
        for field, algorithm in ALGORITHMS.items():
            release += field + ":\n"
            for name, data in outputs.items():
                release += f" {hashlib.new(algorithm, data).hexdigest()} {len(data)} {name}\n"
        for name, data in outputs.items():
            (ROOT / name).write_bytes(data)
        (ROOT / "Release").write_bytes(release.encode("utf-8"))
    check(outputs, architectures)
    print(f"PASS: {count} packages; package metadata, compressed indexes and Release checksums verified")


if __name__ == "__main__":
    main()
