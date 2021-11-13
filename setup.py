
from setuptools import setup, Extension
from Cython.Build import cythonize
import os,glob,urllib.request,gzip,tarfile
from io import BytesIO

PACKAGE = "lzo"
VERSION = "1.0.0"
LZO_VERSION=os.environ.get('LZO_VERSION') or '2.10'
LZO_SRC_PATH=os.environ.get("LZO_SRC_PATH") or '.'

def download(url,file):
    print('Downloading ',url)
    if os.path.exists(file):
        return
    urllib.request.urlretrieve(url,file,lambda x,y,z:print("[%s%s]%3s%%"%('='*int(100*x*y/z),' '*int(100-100*x*y/z),int(100*x*y/z)),end='\r'))
    print()

def extract(file):
    print('Extracting ',file)
    with open(file,'rb')as fp:
        data=gzip.decompress(fp.read())
    with BytesIO(data) as io:
        with tarfile.open(fileobj=io) as tar:
            tar.extractall()

def download_and_extract():
    name='lzo.tar.gz'
    dest='lzo-%s'%(LZO_VERSION)
    if not os.path.exists(dest):
        download('https://www.oberhumer.com/opensource/lzo/download/lzo-%s.tar.gz'%(LZO_VERSION),name)
        extract(name)
    return dest

def check_source_dir():
    return os.path.exists(os.path.join(LZO_SRC_PATH,'include/lzo/lzoconf.h'))
ERROR_MESSAGE='Please set LZO_SRC_PATH or LZO_VERSION (like "2.10") environment variable and try again.'
if __name__=="__main__":
    try:
        if not check_source_dir():
            LZO_SRC_PATH=download_and_extract()
            if not check_source_dir():
                assert check_source_dir()
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise Exception(ERROR_MESSAGE)
    setup(
        name=PACKAGE,
        version=VERSION,
        ext_modules=cythonize([
            Extension(
                name='lzo',
                sources=['lzo.pyx',*glob.glob(os.path.join(LZO_SRC_PATH,'src/*.c'))],
                include_dirs=[os.path.join(LZO_SRC_PATH,'include')]
            ),
        ])
    )