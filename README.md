# LZO

Python bindings for [LZO data compression library](http://www.oberhumer.com/opensource/lzo/)

## Install

```sh
pip install git+https://github.com/System233/lzo
```

## Examples

```python
import lzo
data=b'0123456789'
encoded=lzo.lzo1.compress(data)
decoded=lzo.lzo1.decompress(encoded,len(data))
print("Test lzo1:",data==decoded)


encoded=lzo.lzo1x.compress_1(data)
# optional
# encoded=lzo.lzo1x.optimize(encoded,len(data))
decoded=lzo.lzo1x.decompress(encoded,len(data))
print("Test lzo1x:",data==decoded)

# thread safe
lzo1z=lzo.Lzo1z()
encoded=lzo1z.compress_999(data)
decoded=lzo1z.decompress(encoded,len(data))
print("Test lzo1z:",data==decoded)
```

## API References
```python
class Lzo1:
    def compress(self,data:bytes)->bytes;
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def compress_99(self,data:bytes)->bytes;

class Lzo1a:
    def compress(self,data:bytes)->bytes;
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def compress_99(self,data:bytes)->bytes;

class Lzo1b:
    BEST_SPEED:int;
    BEST_COMPRESSION:int;
    DEFAULT_COMPRESSION:int;
    def compress(self,data:bytes,level:int)->bytes;
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes;
    def compress_99(self,data:bytes)->bytes;
    def compress_999(self,data:bytes)->bytes;
    def compress_1(self,data:bytes)->bytes;
    def compress_2(self,data:bytes)->bytes;
    def compress_3(self,data:bytes)->bytes;
    def compress_4(self,data:bytes)->bytes;
    def compress_5(self,data:bytes)->bytes;
    def compress_6(self,data:bytes)->bytes;
    def compress_7(self,data:bytes)->bytes;
    def compress_8(self,data:bytes)->bytes;
    def compress_9(self,data:bytes)->bytes;

    
class Lzo1c:
    BEST_SPEED:int;
    BEST_COMPRESSION:int;
    DEFAULT_COMPRESSION:int;
    def compress(self,data:bytes,level:int)->bytes;
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes;
    def compress_99(self,data:bytes)->bytes;
    def compress_999(self,data:bytes)->bytes;
    def compress_1(self,data:bytes)->bytes;
    def compress_2(self,data:bytes)->bytes;
    def compress_3(self,data:bytes)->bytes;
    def compress_4(self,data:bytes)->bytes;
    def compress_5(self,data:bytes)->bytes;
    def compress_6(self,data:bytes)->bytes;
    def compress_7(self,data:bytes)->bytes;
    def compress_8(self,data:bytes)->bytes;
    def compress_9(self,data:bytes)->bytes;

class Lzo1f:
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes;
    def compress_999(self,data:bytes)->bytes;
    def compress_1(self,data:bytes)->bytes;

    
class Lzo1x:
    def compress_1(self,data:bytes)->bytes;
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes;
    def decompress_dict_safe(self,data:bytes,dst_len:lzo_uint,dict:bytes)->bytes;
    def compress_999(self,data:bytes)->bytes;
    def compress_dict_999(self,data:bytes,dict:bytes)->bytes;
    def compress_level_999(self,data:bytes,level:int,callback_func:object)->bytes;
    def compress_1_11(self,data:bytes)->bytes;
    def compress_1_12(self,data:bytes)->bytes;
    def compress_1_15(self,data:bytes)->bytes;
    def optimize(self,data:bytes,dst_len:lzo_uint)->bytes;

class Lzo1y:
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes;
    def compress_1(self,data:bytes)->bytes;
    def compress_999(self,data:bytes)->bytes;
    def decompress_dict_safe(self,data:bytes,dst_len:lzo_uint,dict:bytes)->bytes;
    def compress_dict_999(self,data:bytes,dict:bytes)->bytes;
    def compress_level_999(self,data:bytes,level:int,callback_func:object)->bytes;
    def optimize(self,data:bytes,dst_len:lzo_uint)->bytes;

class Lzo1z:
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes;
    def compress_999(self,data:bytes)->bytes;
    def compress_dict_999(self,data:bytes,dict:bytes)->bytes;
    def compress_level_999(self,data:bytes,level:int,callback_func:object)->bytes;
    def decompress_dict_safe(self,data:bytes,dst_len:lzo_uint,dict:bytes)->bytes;
    
class Lzo2a:
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes;
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes;
    def compress_999(self,data:bytes)->bytes;

# Default LZO instances
lzo1:Lzo1;
lzo1a:Lzo1a;
lzo1b:Lzo1b;
lzo1c:Lzo1c; 
lzo1f:Lzo1f; 
lzo1x:Lzo1x; 
lzo1y:Lzo1y; 
lzo1z:Lzo1z; 
lzo2a:Lzo2a;
```