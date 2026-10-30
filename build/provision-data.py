"""Download pinned HLDS data into a runtime volume, never into a published image."""
import hashlib
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import tempfile
import urllib.request
import zipfile

URL = 'https://github.com/EXORTEM/hlds/releases/download/8308/hlds_build_8308.zip'
# Measured from the complete 433317491-byte upstream release asset (2026-10-30).
# GitHub release metadata does not publish an independent digest for this asset.
SHA256 = '03a1035e6a479ccf0a64e842fe0f0315f1f2f9e0160619127a61ae68cdb37df9'
root = Path('/data')
marker = root / '.hlds-8308.sha256'
if marker.exists() and marker.read_text().strip() == SHA256 and all((root / p).exists() for p in ('valve', 'cstrike', 'valve.zip')):
    print('Pinned game data already prepared', flush=True)
    raise SystemExit(0)
root.mkdir(parents=True, exist_ok=True)
# Staging and downloaded archive are isolated from this script's directory.
with tempfile.TemporaryDirectory(prefix='.prepare-', dir=root) as temporary:
    stage = Path(temporary)
    archive = stage / 'download.zip'
    print('Downloading original HLDS 8308 release data...', flush=True)
    digest = hashlib.sha256()
    with urllib.request.urlopen(URL, timeout=120) as response, archive.open('wb') as output:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
            output.write(chunk)
    if digest.hexdigest() != SHA256:
        raise SystemExit('HLDS archive checksum mismatch; refusing extraction')
    prepared = stage / 'prepared'
    prepared.mkdir()
    with zipfile.ZipFile(archive) as source:
        for entry in source.infolist():
            path = PurePosixPath(entry.filename)
            if path.is_absolute() or '..' in path.parts or '\\' in entry.filename:
                raise SystemExit('Unsafe archive path')
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise SystemExit('Archive symlinks are not supported')
            # Original release layout is hlds/{valve,cstrike}/...
            if len(path.parts) < 3 or path.parts[0] != 'hlds' or path.parts[1] not in ('valve', 'cstrike'):
                continue
            target = prepared.joinpath(*path.parts[1:])
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with source.open(entry) as incoming, target.open('wb') as output:
                    shutil.copyfileobj(incoming, output)
                target.chmod(0o644)
    for required in ('valve/halflife.wad', 'cstrike/liblist.gam'):
        if not (prepared / required).is_file():
            raise SystemExit(f'Unexpected archive layout: missing {required}')
    print('Preparing browser ZIP...', flush=True)
    with zipfile.ZipFile(prepared / 'valve.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=1) as browser:
        for directory in ('valve', 'cstrike'):
            for file in sorted((prepared / directory).rglob('*')):
                if file.is_file():
                    browser.write(file, file.relative_to(prepared))
    # Publish marker last. Interrupted provisioning is retried on next start.
    marker.unlink(missing_ok=True)
    for name in ('valve', 'cstrike', 'valve.zip'):
        target = root / name
        if target.is_dir():
            shutil.rmtree(target)
        elif target.exists():
            target.unlink()
        os.replace(prepared / name, target)
    marker.write_text(SHA256 + '\n')
print('Game data prepared successfully', flush=True)
