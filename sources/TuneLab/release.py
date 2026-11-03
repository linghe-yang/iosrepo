"""Publish only a concrete, checked complete app; retire the obsolete prototype afterward.

This never substitutes the prototype binary or changes its version number.
"""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    version=json.loads((ROOT/'version.json').read_text(encoding='utf8'))
    status=json.loads((ROOT/'verification/fidelity_status.json').read_text(encoding='utf8'))
    missing=[]
    if not (ROOT/'build/TuneLab').is_file():missing.append('完整应用可执行文件 build/TuneLab 不存在（布局对象/数值 dylib 不是应用）')
    if not status.get('all_ui_parity_complete'):missing.append('全部原 UI 与交互移植尚未完成')
    if not status.get('all_algorithm_parity_complete'):missing.append('全部原声音算法及状态机接入尚未完成')
    manifest=ROOT/'verification/release_candidate.json'
    if not manifest.exists():missing.append('没有经过检查的完整 DEB 发布清单')
    if missing:
        print(json.dumps({'publishable':False,'development_version':version['version'],'reason':missing,'old_package_will_not_be_relabelled':True},ensure_ascii=False,indent=2))
        raise SystemExit(2)
    candidate=json.loads(manifest.read_text(encoding='utf8'))
    assert candidate['version']==version['version']
    # Reuse the repository's actual DEB parser: filenames are not version metadata.
    sys.path.insert(0,str(REPO/'tools'))
    from update_repo import control,fields
    for item in candidate['packages']:
        path=REPO/item['path'];assert path.resolve().is_relative_to((REPO/'debs').resolve())
        data=path.read_bytes();assert hashlib.sha256(data).hexdigest()==item['sha256']
        metadata=fields(control(data));assert metadata['Version']==version['version']
        assert metadata['Package']==item['package'] and metadata['Architecture']==item['architecture']
    if args.check:print('Complete release candidate and internal DEB versions verified.');return
    # Only after a real checked successor exists may the obsolete packages leave the index.
    retired=REPO/'retired/PianoLab-0.1.0';retired.mkdir(parents=True,exist_ok=True)
    for name in ['com.linghe.pianolab_0.1.0~beta1_iphoneos-arm64.deb','com.linghe.pianolab.rootful_0.1.0~beta1_iphoneos-arm.deb']:
        old=REPO/'debs'/name;target=retired/name
        assert old.resolve().is_relative_to((REPO/'debs').resolve()) and target.resolve().is_relative_to(retired.resolve())
        if old.exists():
            if target.exists():assert old.read_bytes()==target.read_bytes();old.unlink()
            else:old.replace(target)
    subprocess.run([sys.executable,str(REPO/'tools/update_repo.py')],check=True)
    subprocess.run([sys.executable,str(REPO/'tools/update_repo.py'),'--check'],check=True)
if __name__=='__main__':main()
