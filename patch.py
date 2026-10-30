"""Fail-closed patches for the digest-pinned upstream image. No game data included."""
import hashlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
def checked(path, digest):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != digest:
        raise SystemExit(f"Unexpected upstream SHA256: {path}")
    return data

engine = root / "xash"
data = bytearray(checked(engine, "5414c5feb550e8748f4fb5681a1470e736bb67b77923d85ed949c761e385fa75"))
offset = 0x084d0843 - 0x08048000
if data[offset:offset+5] != bytes.fromhex("8b04248b7c"):
    raise SystemExit("Unexpected native instructions")
data[offset:offset+5] = bytes.fromhex("e91d000000")
engine.write_bytes(data)
client = root / "public/assets/index-D_oQDsUs.js"
text = checked(client, "32b58cb870b0482c3ba8203d7e1dfbde1f9f94cc9daa81e1702861ba2ae88770").decode()
def replace_once(old, new):
    global text
    if text.count(old) != 1:
        raise SystemExit("Unexpected client patch context")
    text = text.replace(old, new)
replace_once('async function getGameFiles(){const e=await get(FILE_KEY);if(e)return updateStatus("Loading cached game files..."),jszip_minExports.loadAsync(e);updateStatus("Fetching game files...");const t=await(await fetch(FILE_KEY)).arrayBuffer();return await set(FILE_KEY,t),jszip_minExports.loadAsync(t)}', 'async function getGameFiles(){updateStatus("Fetching game files...");const response=await fetch(FILE_KEY);if(!response.ok)throw new Error("Game files HTTP "+response.status);return jszip_minExports.loadAsync(await response.arrayBuffer())}')
replace_once('await Promise.all(t.map(async([o,l])=>{if(l.dir){n-=1;return}const _="/rodir/"+o,c=_.split("/").slice(0,-1).join("/");e.em.FS.mkdirTree(c),e.em.FS.writeFile(_,await l.async("uint8array")),a+=1,updateProgress(a,n),updateStatus(`Loading game files... (${a}/${n})`)})),e.em.FS.chdir("/rodir"),updateStatus("Game loaded successfully!")}', 'for(const[o,l]of t){if(l.dir){n-=1;continue}const _="/rodir/"+o,c=_.split("/").slice(0,-1).join("/");e.em.FS.mkdirTree(c),e.em.FS.writeFile(_,await l.async("uint8array")),a+=1,updateProgress(a,n),updateStatus(`Loading game files... (${a}/${n})`)}await preloadCustomFiles(e);e.em.FS.chdir("/rodir"),updateStatus("Game loaded successfully!")}')
text += 'async function preloadCustomFiles(e){const response=await fetch("/deployment-preload.json",{cache:"no-store"});if(!response.ok)throw new Error("Preload manifest HTTP "+response.status);const files=await response.json();if(!Array.isArray(files))throw new Error("Invalid preload manifest");for(const path of files){if(typeof path!=="string"||!/^cstrike\\/[A-Za-z0-9_./-]+$/.test(path)||path.split("/").some(p=>p===".."||p===""))throw new Error("Invalid preload path");updateStatus("Loading "+path);const res=await fetch("/"+path);if(!res.ok)throw new Error(path+" HTTP "+res.status);const target="/rodir/"+path;e.em.FS.mkdirTree(target.slice(0,target.lastIndexOf("/")));e.em.FS.writeFile(target,new Uint8Array(await res.arrayBuffer()))}}'
client.write_text(text)
