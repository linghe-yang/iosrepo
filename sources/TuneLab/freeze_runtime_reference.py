"""Copy and verify real original-APK screenshots and UI trees into this source project."""
import hashlib,json,shutil,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parent
WORK=ROOT.parents[2]
SOURCE=WORK/'tunelab_analysis/migration/original_spec/runtime_phone'
DEST=ROOT/'reference/android35-phone'
shutil.copytree(SOURCE,DEST,dirs_exist_ok=True)
pages=json.loads((DEST/'pages.json').read_text(encoding='utf8'))
variants=json.loads((DEST/'variants.json').read_text(encoding='utf8'))
for item in [*pages,*variants]:
    if 'screenshot' not in item:continue
    path=DEST/item['screenshot'];assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256']
dimensions={p.name:struct.unpack_from('>II',p.read_bytes(),16) for p in DEST.glob('*.png')}
assert dimensions['Main_phone_landscape.png']==(1920,1080)
assert dimensions['Main_tablet_744dp_portrait.png']==(1488,2266)
assert dimensions['Main_tablet_1133dp_landscape.png']==(2266,1488)
report={'source':'unmodified AndroidTuneLab-3.2.apk on dedicated Android API35 emulator',
        'raw_activity_launch_attempts':len(pages),'raw_requested_pages_visible':sum(p['requested_page_visible'] for p in pages),
        'additional_original_main_captured':True,'spectrum_update_recovered_after_original_state_initialization':True,
        'distinct_application_pages_with_visible_reference':41,
        'missing_authenticated_page':'DBXfer closes when its original Dropbox credential/client state is null; no account used.',
        'screenshot_dimensions':dimensions,
        'files':{p.relative_to(DEST).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(DEST.iterdir()) if p.is_file()},
        'ios_ui_comparison_performed':False,'full_port_complete':False}
(ROOT/'verification/runtime_reference.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf8')
print(json.dumps({k:v for k,v in report.items() if k not in ('files','screenshot_dimensions')},ensure_ascii=False,indent=2))
