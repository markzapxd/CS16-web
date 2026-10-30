"""Fail closed source edits for the pinned engine and vendored web client."""
import sys
from pathlib import Path

def replace(path, old, new):
    text = path.read_text()
    if text.count(old) != 1:
        raise SystemExit(f"Unexpected source context: {path}")
    path.write_text(text.replace(old, new))

root = Path(sys.argv[2])
if sys.argv[1] == 'engine':
    replace(root / 'engine/common/net_ws.c', '''    if (fragments && fragments[0] != buf) {
        for (int i = 0; i < packet_count; ++i)
            free(fragments[i]);
    }
''', '')
    # fragments are either borrowed buf or interior pointers into the single block.
    # Only fragment_data_block, fragments and sizes own allocations.
elif sys.argv[1] == 'client':
    path = root / 'src/client/main.ts'
    replace(path, '    const contentLength = res.headers.get(\'Content-Length\');', '''    if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
    const contentLength = res.headers.get('Content-Length');''')
    replace(path, '    await Promise.all(Object.entries(zip.files).map(async ([filename, file]) => {', '    for (const [filename, file] of Object.entries(zip.files)) {')
    replace(path, '        if (file.dir) return;', '        if (file.dir) continue;')
    replace(path, '    }))', '    }')
    replace(path, '''    const customMap = await fetchWithProgress('cstrike/maps/garten_v05.bsp')
    x.em.FS.mkdirTree('/rodir/cstrike/maps')
    x.em.FS.writeFile('/rodir/cstrike/maps/garten_v05.bsp', new Uint8Array(customMap))''', '''    const manifest = await fetch('/deployment-preload.json', {cache: 'no-store'});
    if (!manifest.ok) throw new Error(`Preload manifest HTTP ${manifest.status}`);
    const files: unknown = await manifest.json();
    if (!Array.isArray(files)) throw new Error('Invalid preload manifest');
    for (const file of files) {
        if (typeof file !== 'string' || !/^cstrike\\/[A-Za-z0-9_./-]+$/.test(file) || file.split('/').some(p => p === '..' || p === '')) throw new Error('Invalid preload path');
        const data = await fetchWithProgress('/' + file);
        const target = '/rodir/' + file;
        x.em.FS.mkdirTree(target.slice(0, target.lastIndexOf('/')));
        x.em.FS.writeFile(target, new Uint8Array(data));
    }''')
else:
    raise SystemExit('Unknown patch target')
