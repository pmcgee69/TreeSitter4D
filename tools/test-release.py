"""Tests a release as someone with only Delphi would use it: a fresh folder
holding the repository's delphi\\ sources and the zips' contents, nothing
else; dcc64 and dcc32 build the walker from the objects, and with TS_DLL
against the DLLs; each runs over the RTL's source\\rtl\\common and must report

    99 files, 1537727 nodes, 37 misgrouped <

    python tools\\test-release.py 0.1.0 [dist dir] [rtl folder]

The RTL folder defaults to Delphi 13's (Studio 37.0).
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
if len(sys.argv) < 2:
    sys.exit(__doc__)
VER = sys.argv[1]
DIST = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / 'dist'
RTL = sys.argv[3] if len(sys.argv) > 3 else \
    r'C:\Program Files (x86)\Embarcadero\Studio\37.0\source\rtl\common'
EXPECT = '99 files, 1537727 nodes, 37 misgrouped <'

T = pathlib.Path(tempfile.mkdtemp(prefix='ts4d-release-'))
(T / 'delphi').mkdir()
for f in ('TreeSitter.Api.pas', 'TreeSitter.pas', 'TsWalk.dpr'):
    shutil.copy(ROOT / 'delphi' / f, T / 'delphi' / f)
zipfile.ZipFile(DIST / f'TreeSitter4D-{VER}-objects.zip').extractall(T)
zipfile.ZipFile(DIST / f'TreeSitter4D-{VER}-dlls.zip').extractall(T / 'dlls')
print('in', T)

failed = 0
for dcc, plat in (('dcc64', 'win64'), ('dcc32', 'win32')):
    for mode in ('objects', 'dlls'):
        out = T / f'out-{plat}-{mode}'
        (out / 'dcu').mkdir(parents=True)
        args = [dcc, '-Q', '-B', f'-E{out}', f'-NU{out / "dcu"}', '-NSSystem;Winapi', 'TsWalk.dpr']
        if mode == 'dlls':
            args.insert(3, '-DTS_DLL')
            for d in (T / 'dlls' / plat).glob('*.dll'):
                shutil.copy(d, out / d.name)
        r = subprocess.run(args, cwd=T / 'delphi', capture_output=True, text=True)
        exe = out / 'TsWalk.exe'
        if exe.exists():
            lines = subprocess.run([str(exe), RTL], capture_output=True, text=True,
                                   timeout=600).stdout.strip().splitlines()
            got = lines[-1] if lines else '(no output)'
        else:
            got = ' / '.join(ln for ln in r.stdout.splitlines() if 'rror' in ln)[:300] or 'not built'
        ok = got.startswith(EXPECT)
        failed += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {plat} {mode:8} {got}")
print('all four as expected' if not failed else f'{failed} of 4 failed')
sys.exit(1 if failed else 0)
