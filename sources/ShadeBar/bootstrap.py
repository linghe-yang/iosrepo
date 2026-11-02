"""Run with Python 3.12+ on Linux/WSL to prepare project-local build tools."""
import hashlib
from pathlib import Path
import subprocess
import tarfile
import urllib.request

ROOT=Path(__file__).resolve().parent
TOOLS=ROOT/'tools'
ARCHIVE_SHA='a72a7a577e2fbe2838b6b5e9c72034fa7d114af96f0e1d4b016f18730ce4056e'
SDK_REV='0222fd5413cf4b9af096f37b4621afa2688572f7'
ABI_REV='43b2ca59ad3f6a55735b1f7b5cba8c34b55bd8f9'

def run(*args): subprocess.run(args,check=True)

def clone(url,path,revision,sparse=None):
    if path.exists():
        actual=subprocess.check_output(['git','-C',str(path),'rev-parse','HEAD'],text=True).strip()
        if actual!=revision: raise RuntimeError(f'{path} already exists with a different revision; left untouched')
        return
    run('git','clone','--filter=blob:none','--no-checkout',url,str(path))
    run('git','-C',str(path),'config','core.autocrlf','false')
    if sparse:
        run('git','-C',str(path),'sparse-checkout','init','--cone')
        run('git','-C',str(path),'sparse-checkout','set',sparse)
    run('git','-C',str(path),'checkout',revision)

def main():
    TOOLS.mkdir(exist_ok=True)
    archive=TOOLS/'iOSToolchain-x86_64.tar.xz'
    if not archive.exists():
        urllib.request.urlretrieve('https://github.com/L1ghtmann/llvm-project/releases/download/test-210562a/iOSToolchain-x86_64.tar.xz',archive)
    assert hashlib.sha256(archive.read_bytes()).hexdigest()==ARCHIVE_SHA
    if not (TOOLS/'linux/iphone/bin/clang').exists():
        with tarfile.open(archive) as tar: tar.extractall(TOOLS,filter='data')
    clone('https://github.com/theos/sdks.git',TOOLS/'sdks',SDK_REV,'iPhoneOS16.5.sdk')
    clone('https://github.com/p0358/allemande.git',TOOLS/'allemande',ABI_REV)
    print('Project-local tools ready. Next: bash build.sh; python3 package.py')

if __name__=='__main__': main()
