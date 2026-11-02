"""Packages the compiled C for a release: the objects for {$L} (Win64 COFF,
Win32 OMF) and the DLLs, each zip with the licences and a README.txt, and
SHA-256 sums (LF line endings, so `sha256sum -c` reads them anywhere).

First build both platforms (a RAD Studio command prompt):

    build-c.cmd dll
    build-c.cmd win32 dll

then:

    python tools\\package-release.py 0.1.0          (writes dist\\)
"""
import hashlib
import pathlib
import re
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
if len(sys.argv) < 2:
    sys.exit(__doc__)
VER = sys.argv[1]
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / 'dist'
OUT.mkdir(parents=True, exist_ok=True)
OBJ = ROOT / 'obj'
LICENCES = {
    'licenses/tree-sitter-LICENSE': ROOT / 'c' / 'tree-sitter' / 'LICENSE',
    'licenses/tree-sitter-delphi13-LICENSE': ROOT / 'c' / 'tree-sitter-delphi13' / 'LICENSE',
    'licenses/TreeSitter4D-LICENSE': ROOT / 'LICENSE',
}


def version_of(folder):
    """The version a c\\ folder's README states, so a zip's can't go stale."""
    text = (ROOT / 'c' / folder / 'README.md').read_text(encoding='utf-8')
    m = re.search(r'\bv\d+\.\d+\.\d+\b', text)
    if not m:
        sys.exit(f'no version in c/{folder}/README.md')
    return m.group()


VERSIONS = f"tree-sitter {version_of('tree-sitter')} and tree-sitter-delphi13 {version_of('tree-sitter-delphi13')}"
OBJECTS_TXT = f"""TreeSitter4D {VER}: the C, compiled, for Delphi's {{$L}}

Unzip into the repository's root, beside delphi\\, so these land in obj\\
where delphi\\TreeSitter.Api.pas links them:

  obj\\ts_lib.o, obj\\delphi13_parser.o, obj\\delphi13_scanner.o
      Win64, COFF, by bcc64x (C++Builder)
  obj\\win32\\ts_lib.obj, obj\\win32\\delphi13_parser.obj, obj\\win32\\delphi13_scanner.obj
      Win32, OMF, by bcc32c

Then dcc64 or dcc32 builds delphi\\TsWalk.dpr with nothing else: no C
compiler, and no DLLs at run time.

{VERSIONS}, both MIT (licenses\\).
"""
DLLS_TXT = f"""TreeSitter4D {VER}: the C, compiled, as DLLs

  win64\\tree-sitter.dll, win64\\tree-sitter-delphi13.dll    by bcc64x
  win32\\tree-sitter.dll, win32\\tree-sitter-delphi13.dll    by bcc32c

tree-sitter.dll exports the tree-sitter API (plain C names);
tree-sitter-delphi13.dll exports tree_sitter_delphi13. Put the pair beside
the executable. For delphi\\TreeSitter.Api.pas, define TS_DLL. Any other
binding that loads tree-sitter.dll and a grammar DLL can use them too.

The Win64 DLLs need the Universal C Runtime (part of Windows 10 and later);
the Win32 ones only KERNEL32 and USER32.

{VERSIONS}, both MIT (licenses\\).
"""
OBJECTS = {f'obj/{n}': OBJ / n for n in ('ts_lib.o', 'delphi13_parser.o', 'delphi13_scanner.o')} | \
          {f'obj/win32/{n}': OBJ / 'win32' / n
           for n in ('ts_lib.obj', 'delphi13_parser.obj', 'delphi13_scanner.obj')}
DLLS = {f'win64/{n}': OBJ / n for n in ('tree-sitter.dll', 'tree-sitter-delphi13.dll')} | \
       {f'win32/{n}': OBJ / 'win32' / n for n in ('tree-sitter.dll', 'tree-sitter-delphi13.dll')}

missing = [str(p.relative_to(ROOT)) for p in (OBJECTS | DLLS).values() if not p.exists()]
if missing:
    sys.exit('not built yet (build-c.cmd dll, then build-c.cmd win32 dll): ' + ', '.join(missing))


def pack(name, files, readme):
    path = OUT / name
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.writestr('README.txt', readme.replace('\n', '\r\n'))
        for arc, src in {**files, **LICENCES}.items():
            z.write(src, arc)
    return path


made = [pack(f'TreeSitter4D-{VER}-objects.zip', OBJECTS, OBJECTS_TXT),
        pack(f'TreeSitter4D-{VER}-dlls.zip', DLLS, DLLS_TXT)]
sums = ''.join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n" for p in made)
(OUT / 'SHA256SUMS.txt').write_bytes(sums.encode('ascii'))
for p in made:
    print(f"{p.name:40} {p.stat().st_size:>10,} bytes")
print(sums, end='')
