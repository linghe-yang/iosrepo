"""Stage original APK UI assets without renaming/repainting any images or strings.

Resource fidelity is independently checked; it is not a claim of UI/behavior parity.
"""
import hashlib,json,plistlib,shutil,html
from pathlib import Path
ROOT=Path(__file__).resolve().parent
VERSION=json.loads((ROOT/'version.json').read_text(encoding='utf8'))
WORK=ROOT.parents[2]
SPEC=WORK/'tunelab_analysis/migration/original_spec'
DEST=ROOT/'resources/Original'
identity=json.loads((SPEC/'identity.json').read_text(encoding='utf8'))
DEST.mkdir(parents=True,exist_ok=True)
shutil.copytree(SPEC/'apk_resources',DEST/'apk',dirs_exist_ok=True)
for name in ['identity.json','activities.json','layouts.json','controls.json','menus.json','settings_items.json','callbacks.json','native_api.json','resource_manifest.json','summary.json']:
    shutil.copy2(SPEC/name,DEST/name)
icon=DEST/'apk/res/mipmap-xxxhdpi/ic_launcher.png'
shutil.copy2(icon,ROOT/'resources/Icon.png')
info={'CFBundleExecutable':'TuneLab','CFBundleIdentifier':'com.realtimespecialties.tunelab.ios','CFBundleName':'TuneLab','CFBundleDisplayName':identity['launcher_label'],'CFBundlePackageType':'APPL','CFBundleVersion':str(VERSION['build']),'CFBundleShortVersionString':VERSION['ios_short_version'],'MinimumOSVersion':'16.0','LSRequiresIPhoneOS':True,'UIDeviceFamily':[1,2],'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UILaunchScreen':{},'NSMicrophoneUsageDescription':'TuneLab uses the microphone to measure piano pitch and inharmonicity.','CFBundleIcons':{'CFBundlePrimaryIcon':{'CFBundleIconFiles':['Icon']}},'CFBundleIcons~ipad':{'CFBundlePrimaryIcon':{'CFBundleIconFiles':['Icon']}}}
platform=SPEC/'platform_android35'
info['TuneLabPortVersion']=VERSION['version']
if (platform/'Roboto-Regular.ttf').exists() and (platform/'Roboto-NOTICE.txt').exists():
    fonts=ROOT/'resources/AndroidPlatform';fonts.mkdir(exist_ok=True)
    shutil.copy2(platform/'Roboto-Regular.ttf',fonts/'Roboto-Regular.ttf')
    (fonts/'Roboto-NOTICE.txt').write_text(html.unescape((platform/'Roboto-NOTICE.txt').read_text(encoding='utf8')),encoding='utf8')
    info['UIAppFonts']=['AndroidPlatform/Roboto-Regular.ttf']
(ROOT/'resources/Info.plist').write_bytes(plistlib.dumps(info,sort_keys=False))
checks=[]
for relative,item in json.loads((SPEC/'resource_manifest.json').read_text()).items():
    p=DEST/'apk'/Path(relative).relative_to('apk_resources')
    assert len(p.read_bytes())==item['bytes'] and hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256']
    checks.append(relative)
report={'resource_files_verified':len(checks),'original_launcher_name':identity['launcher_label'],'icon_exact_original_sha256':hashlib.sha256(icon.read_bytes()).hexdigest(),'ios_icon_bytes_identical':icon.read_bytes()==(ROOT/'resources/Icon.png').read_bytes(),'text_and_images_regenerated':False,'all_ui_pixel_verified':False,'all_behaviors_ported':False,'new_release_ready':False}
report['ios_port_version']=VERSION['version']
(ROOT/'verification').mkdir(exist_ok=True)
(ROOT/'verification/original_assets.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf8')
print(json.dumps(report,ensure_ascii=False,indent=2))
