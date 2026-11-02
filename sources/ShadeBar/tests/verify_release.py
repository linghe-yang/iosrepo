"""Regression checks for the failed launch path and the new desktop app package."""
import hashlib
import io
import json
from pathlib import Path
import plistlib
import struct
import sys
import tarfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from package import signature_check

def main():
    manifest=json.loads((ROOT/'build/package_manifest.json').read_text())
    for name,expected in manifest['sources'].items():
        source=(ROOT/name).read_text(encoding='utf-8-sig').encode('utf-8')
        assert hashlib.sha256(source).hexdigest()==expected, f'Source changed after packaging: {name}'
    package=(ROOT/'packages'/manifest['package']).read_bytes()
    assert hashlib.sha256(package).hexdigest()==manifest['sha256']
    assert package.startswith(b'!<arch>\n')
    members={}; pos=8
    while pos<len(package):
        header=package[pos:pos+60];size=int(header[48:58]);name=header[:16].decode().strip().rstrip('/')
        members[name]=package[pos+60:pos+60+size];pos+=60+size+size%2
    contents={};modes={}
    for archive in ('data.tar.gz','control.tar.gz'):
        with tarfile.open(fileobj=io.BytesIO(members[archive]),mode='r:gz') as tar:
            for item in tar:
                assert item.uid==0 and item.gid==0
                if item.isfile(): contents[(archive,item.name)]=tar.extractfile(item).read();modes[(archive,item.name)]=item.mode
    payload={name:data for (archive,name),data in contents.items() if archive=='data.tar.gz'}
    app='./var/jb/Applications/ShadeBar.app/'
    info=plistlib.loads(payload[app+'Info.plist'])
    assert info['CFBundlePackageType']=='APPL' and info['CFBundleExecutable']=='ShadeBarApp'
    assert info['UIDeviceFamily']==[1,2] and len(info['UISupportedInterfaceOrientations'])==4
    assert info['CFBundleIdentifier']=='com.linghe.shadebar.app'
    for icons in ('CFBundleIcons','CFBundleIcons~ipad'):
        for icon in info[icons]['CFBundlePrimaryIcon']['CFBundleIconFiles']:
            png=payload[app+icon+'.png'];assert png.startswith(b'\x89PNG\r\n\x1a\n')
            width,height=struct.unpack_from('>II',png,16);assert width==height==int(icon.split('-')[1])
    path='./var/jb/Library/MobileSubstrate/DynamicLibraries/'
    assert set(name for name in payload if name.startswith(path))=={path+'ShadeBootstrap.dylib',path+'ShadeBootstrap.plist'}
    assert plistlib.loads(payload[path+'ShadeBootstrap.plist'])=={'Filter':{'Bundles':['com.apple.springboard']}}
    boot=signature_check(payload[path+'ShadeBootstrap.dylib'])
    render=signature_check(payload[app+'Frameworks/ShadeRenderer.dylib'])
    application=signature_check(payload[app+'ShadeBarApp'],0,2)
    assert boot['cpu_subtype']==render['cpu_subtype']=='0x80000002'
    assert not any(s.startswith('__objc') or s=='__cfstring' for s in boot['sections'])
    assert not any('UIKit' in p or 'ShadeRenderer' in p or 'libobjc' in p for p in boot['dependencies'])
    assert not {'__mod_init_func','__init_offsets'}.intersection(render['sections'])
    assert b'setHandler:\0' not in payload[app+'Frameworks/ShadeRenderer.dylib']
    renderer_bytes=payload[app+'Frameworks/ShadeRenderer.dylib']
    assert b'FBSOrientationObserver\0' not in renderer_bytes
    assert b'_isWindowServerHostingManaged\0' not in renderer_bytes
    assert b'_isSystemWindow\0' not in renderer_bytes
    assert b'initWithWindowScene:\0' in renderer_bytes
    for selector in (b'isAnySwitcherVisible\0',b'isMainSwitcherVisible\0',b'appSwitcherVisible:\0'):
        assert selector in renderer_bytes
    assert b'resize:\0' not in renderer_bytes and b'finish\0' not in renderer_bytes
    for symbol in (b'ShadeFloatingIcon\0',b'ShadeQuickPanel\0',b'pinch:\0',b'openPanel\0',b'closePanel\0',b'moveIcon:\0'):
        assert symbol in renderer_bytes
    for data in (payload[path+'ShadeBootstrap.dylib'],renderer_bytes,payload[app+'ShadeBarApp']):
        assert b'/var/mobile/Library/ShadeBar/settings.plist\0' in data
    app_bytes=payload[app+'ShadeBarApp']
    assert b'UISlider\0' in app_bytes and b'ShadeProfileSettings\0' in app_bytes
    assert b'_applicationIconImageForBundleIdentifier:format:scale:\0' in app_bytes
    assert b'toggleApplication:\0' in app_bytes and b'iconForBundle:\0' in app_bytes
    assert b'toggleOverlayOption:\0' in app_bytes
    assert b'profile.%@.%@\0' in app_bytes and b'profile.%@.%@\0' in renderer_bytes
    assert not any('Preferences.framework' in p for p in application['dependencies'])
    assert not any('PreferenceBundles/' in p or 'PreferenceLoader/' in p for p in payload)
    for script in ('postinst','prerm'):
        data=contents[('control.tar.gz','./'+script)]
        assert data.startswith(b'#!/bin/sh\n') and b'\r' not in data
        assert modes[('control.tar.gz','./'+script)]==0o755
        assert b'/var/jb/Applications/ShadeBar.app' in data
    result={'native_abi_and_signatures_passed':True,'bootstrap_has_no_objc_classes_or_renderer_dependency':True,'renderer_has_no_constructor_or_setHandler_callback':True,'scene_window_creation_present':True,'unmanaged_window_override_removed':True,'on_screen_resize_controls_removed':True,'all_three_binaries_use_shared_settings_path':True,'app_icons_ipad_and_orientation_metadata_passed':True,'preferences_bundle_removed':True,'installation_scripts_passed':True,'code_pages_verified':sum(x['code_pages_verified'] for x in (boot,render,application)),'device_tested':False}
    result['per_application_profile_ui_and_shared_key_format_present']=True
    result['percentage_sliders_present']=True
    result['application_icons_and_per_app_switch_present']=True
    result['app_switcher_visibility_detection_present']=True
    result['on_screen_resize_handles_removed']=result.pop('on_screen_resize_controls_removed')
    result['floating_icon_quick_panel_and_pinch_gesture_present']=True
    result['desktop_overlay_options_present']=True
    (ROOT/'build/release_verification.json').write_text(json.dumps(result,indent=2))
    print('PASS: native ABI, isolated startup, removed crashing callback, desktop icons, iPad orientations, scripts, signed package')

if __name__=='__main__':main()
