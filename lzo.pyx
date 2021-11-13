#cython:language_level=3

from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from libc.string cimport memcpy 
from cpython.bytes cimport PyBytes_FromStringAndSize

cdef extern from "lzo/lzoconf.h":
    ctypedef unsigned char* lzo_bytep;
    ctypedef signed long lzo_int
    ctypedef unsigned long lzo_uint
    ctypedef void* lzo_voidp
    ctypedef lzo_int* lzo_intp
    ctypedef lzo_uint* lzo_uintp
    ctypedef lzo_uint lzo_xint
    ctypedef lzo_callback_t* lzo_callback_p
    ctypedef lzo_voidp(*lzo_alloc_func_t)(lzo_callback_p self, lzo_uint items, lzo_uint size);
    ctypedef void(*lzo_free_func_t)(lzo_callback_p self, lzo_voidp ptr);
    ctypedef void(*lzo_progress_func_t)(lzo_callback_p self, lzo_uint, lzo_uint, int);
    ctypedef struct lzo_callback_t:
        lzo_alloc_func_t nalloc;
        lzo_free_func_t nfree;
        lzo_progress_func_t nprogress;
        lzo_voidp user1;
        lzo_xint user2;
        lzo_xint user3;

    cdef enum:
        LZO_E_OK
        LZO_E_ERROR
        LZO_E_OUT_OF_MEMORY
        LZO_E_NOT_COMPRESSIBLE
        LZO_E_INPUT_OVERRUN
        LZO_E_OUTPUT_OVERRUN
        LZO_E_LOOKBEHIND_OVERRUN
        LZO_E_EOF_NOT_FOUND
        LZO_E_INPUT_NOT_CONSUMED
        LZO_E_NOT_YET_IMPLEMENTED
        LZO_E_INVALID_ARGUMENT
        LZO_E_INVALID_ALIGNMENT
        LZO_E_OUTPUT_NOT_CONSUMED
        LZO_E_INTERNAL_ERROR

ctypedef int(*lzo_compress_p)(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
ctypedef int(*lzo_compress_level_p)(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem,int compression_level);
ctypedef int (*lzo_decompress_p)(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
ctypedef int(*lzo_compress_dict_p)(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem,const lzo_bytep dict, lzo_uint dict_len);
ctypedef int(*lzo_compress_dict_level_p)(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem,const lzo_bytep dict, lzo_uint dict_len,lzo_callback_p cb, int compression_level);
ctypedef int (*lzo_decompress_dict_p)(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem,const lzo_bytep dict, lzo_uint dict_len);
ctypedef int (*lzo_optimize_p)(lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);


ERROR_MESSAGE_MAP={
        LZO_E_OK:"OK",
        LZO_E_ERROR:"Error",
        LZO_E_OUT_OF_MEMORY:"Out Of Memory",
        LZO_E_NOT_COMPRESSIBLE:"Not Compressible",
        LZO_E_INPUT_OVERRUN:"Input Overrun",
        LZO_E_OUTPUT_OVERRUN:"Output Overrun",
        LZO_E_LOOKBEHIND_OVERRUN:"Lookbehind Overrun",
        LZO_E_EOF_NOT_FOUND:"EOF Not Found",
        LZO_E_INPUT_NOT_CONSUMED:"Input Not Consumed",
        LZO_E_NOT_YET_IMPLEMENTED:"Not Yet Implemented",
        LZO_E_INVALID_ARGUMENT:"Invalid Argument",
        LZO_E_INVALID_ALIGNMENT:"Invalid Alignment",
        LZO_E_OUTPUT_NOT_CONSUMED:"Output Not Consumed",
        LZO_E_INTERNAL_ERROR:"Internal Error",
}

cdef class FunctionWrapper:
    def __init__(self,func:object):
        self.func=func;
    def __call__(self,*args):
        self.func(*args);
class LZOError(Exception):
    def __init__(self,code):
        super().__init__(ERROR_MESSAGE_MAP.get(code,'Unknown error'))
        self.code=code
cdef void lzo_progress_func(lzo_callback_p self, lzo_uint x, lzo_uint y, int progress):
    callback=<FunctionWrapper>(self.user1);
    callback(progress)
cdef class Lzo(object):
    cdef int MEM_COMPRESS;
    cdef int MEM_DECOMPRESS;
    cdef lzo_bytep MEM_WORK;
    def __init__(self,mem_compress:int=0,mem_decompress:int=0):
        self.MEM_COMPRESS=mem_compress;
        self.MEM_DECOMPRESS=mem_decompress;
        self.MEM_WORK=NULL;
    cdef lzo_bytep __get_work_memory(self):
        if not self.MEM_WORK:
            self.MEM_WORK=<lzo_bytep>PyMem_Malloc(self.MEM_COMPRESS)
        return self.MEM_WORK
    def get_need_memory(self,bytes data)->int:
        return len(data)+len(data)//16+64+3
    def __dealloc__(self):
        if self.MEM_WORK:
            PyMem_Free(self.MEM_WORK)
            self.MEM_WORK=NULL;
    def __check_error(self,code:int)->bool:
        if code==LZO_E_OK:
            return True
        raise LZOError(code)
    cdef bytes __optimize(self,lzo_optimize_p optimize,bytes data,lzo_uint dst_len):
        cdef lzo_bytep dst=<lzo_bytep>PyMem_Malloc(dst_len);
        cdef lzo_bytep src=<lzo_bytep>PyMem_Malloc(len(data));
        cdef lzo_bytep src_p=data;
        memcpy(src,src_p,len(data));
        try:
            err=optimize(src,len(data),dst,&dst_len,NULL);
            self.__check_error(err)
            return PyBytes_FromStringAndSize(<char*>src,len(data));
        finally:
            PyMem_Free(src)
            PyMem_Free(dst)
    cdef bytes __compress(self,lzo_compress_p compress,bytes data):
        cdef lzo_uint dst_len=self.get_need_memory(data);
        cdef lzo_bytep dst=<lzo_bytep>PyMem_Malloc(dst_len);
        try:
            err=compress(data,len(data),dst,&dst_len,self.__get_work_memory());
            self.__check_error(err)
            return PyBytes_FromStringAndSize(<char*>dst,dst_len);
        finally:
            PyMem_Free(dst)
    cdef bytes __compress_level(self,lzo_compress_level_p compress,bytes data,int level):
        cdef lzo_uint dst_len=self.get_need_memory(data);
        cdef lzo_bytep dst=<lzo_bytep>PyMem_Malloc(dst_len);
        try:
            err=compress(data,len(data),dst,&dst_len,self.__get_work_memory(),level);
            self.__check_error(err)
            return PyBytes_FromStringAndSize(<char*>dst,dst_len);
        finally:
            PyMem_Free(dst)
    cdef bytes __compress_dict(self,lzo_compress_dict_p compress,bytes data,bytes dict):
        cdef lzo_uint dst_len=self.get_need_memory(data);
        cdef lzo_bytep dst=<lzo_bytep>PyMem_Malloc(dst_len);
        try:
            err=compress(data,len(data),dst,&dst_len,self.__get_work_memory(),data,len(data));
            self.__check_error(err)
            return PyBytes_FromStringAndSize(<char*>dst,dst_len);
        finally:
            PyMem_Free(dst)
    cdef bytes __compress_dict_level(self,lzo_compress_dict_level_p compress,bytes data,bytes dict,object callback_func,int level):
        cdef lzo_uint dst_len=self.get_need_memory(data);
        cdef lzo_bytep dst=<lzo_bytep>PyMem_Malloc(dst_len);
        cdef lzo_callback_t callback;
        cdef wrapper=FunctionWrapper(callback_func);
        callback.nalloc=NULL;
        callback.nfree=NULL;
        callback.nprogress=lzo_progress_func;
        callback.user1=<void*>wrapper;
        callback.user2=0;
        callback.user3=0;
        try:
            err=compress(data,len(data),dst,&dst_len,self.__get_work_memory(),data,len(data),&callback,level);
            self.__check_error(err)
            return PyBytes_FromStringAndSize(<char*>dst,dst_len);
        finally:
            PyMem_Free(dst)
    cdef bytes __decompress(self,lzo_decompress_p decompress, bytes data,lzo_uint dst_len):
        cdef lzo_bytep dst=<lzo_bytep>PyMem_Malloc(dst_len);
        try:
            err=decompress(data,len(data),dst,&dst_len,NULL);
            self.__check_error(err)
            return PyBytes_FromStringAndSize(<char*>dst,dst_len);
        finally:
            PyMem_Free(dst);

    cdef bytes __decompress_dict(self,lzo_decompress_dict_p decompress, bytes data,lzo_uint dst_len,bytes dict):
        cdef lzo_bytep dst=<lzo_bytep>PyMem_Malloc(dst_len);
        try:
            err=decompress(data,len(data),dst,&dst_len,NULL,dict,len(dict));
            self.__check_error(err)
            return PyBytes_FromStringAndSize(<char*>dst,dst_len);
        finally:
            PyMem_Free(dst);


cdef extern from "lzo/lzo1.h":
    int lzo1_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1_decompress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1_99_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    cdef enum:
        LZO1_MEM_COMPRESS
        LZO1_MEM_DECOMPRESS
        LZO1_99_MEM_COMPRESS

cdef class Lzo1(Lzo):
    def __init__(self):
        super().__init__(max(LZO1_MEM_COMPRESS,LZO1_99_MEM_COMPRESS),LZO1_MEM_DECOMPRESS);
    def compress(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1_compress,data);
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1_decompress,data,dst_len);
    def compress_99(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1_99_compress,data);

cdef extern from "lzo/lzo1a.h":
    int lzo1a_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1a_decompress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1a_99_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    cdef enum:
        LZO1A_MEM_COMPRESS
        LZO1A_MEM_DECOMPRESS
        LZO1A_99_MEM_COMPRESS
        
cdef class Lzo1a(Lzo):
    def __init__(self):
        super().__init__(max(LZO1A_MEM_COMPRESS,LZO1A_99_MEM_COMPRESS),LZO1A_MEM_DECOMPRESS);
    def compress(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1a_compress,data);
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1a_decompress,data,dst_len);
    def compress_99(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1a_99_compress,data);


cdef extern from "lzo/lzo1b.h":
    int lzo1b_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem,int compression_level);
    int lzo1b_decompress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_decompress_safe(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_99_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_999_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_1_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_2_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_3_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_4_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_5_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_6_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_7_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_8_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1b_9_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    cdef enum:
        LZO1B_MEM_COMPRESS
        LZO1B_MEM_DECOMPRESS
        LZO1B_99_MEM_COMPRESS
        LZO1B_999_MEM_COMPRESS
        LZO1B_BEST_SPEED
        LZO1B_BEST_COMPRESSION
        LZO1B_DEFAULT_COMPRESSION

cdef class Lzo1b(Lzo):
    cdef readonly int BEST_SPEED
    cdef readonly int BEST_COMPRESSION
    cdef readonly int DEFAULT_COMPRESSION
    def __cinit__(cls):
        cls.BEST_SPEED=LZO1B_BEST_SPEED
        cls.BEST_COMPRESSION=LZO1B_BEST_COMPRESSION
        cls.DEFAULT_COMPRESSION=LZO1B_DEFAULT_COMPRESSION
    def __init__(self):
        super().__init__(max(LZO1B_MEM_COMPRESS,LZO1B_99_MEM_COMPRESS,LZO1B_999_MEM_COMPRESS),LZO1B_MEM_DECOMPRESS);
    def compress(self,data:bytes,level:int)->bytes:return self.__compress_level(<lzo_compress_level_p>lzo1b_compress,data,level);
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1b_decompress,data,dst_len);
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1b_decompress_safe,data,dst_len);
    def compress_99(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_99_compress,data);
    def compress_999(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_999_compress,data);
    def compress_1(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_1_compress,data);
    def compress_2(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_2_compress,data);
    def compress_3(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_3_compress,data);
    def compress_4(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_4_compress,data);
    def compress_5(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_5_compress,data);
    def compress_6(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_6_compress,data);
    def compress_7(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_7_compress,data);
    def compress_8(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_8_compress,data);
    def compress_9(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1b_9_compress,data);

    
cdef extern from "lzo/lzo1c.h":
    int lzo1c_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem,int compression_level);
    int lzo1c_decompress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_decompress_safe(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_99_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_999_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_1_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_2_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_3_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_4_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_5_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_6_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_7_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_8_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1c_9_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);

    cdef enum:
        LZO1C_MEM_COMPRESS
        LZO1C_MEM_DECOMPRESS
        LZO1C_99_MEM_COMPRESS
        LZO1C_999_MEM_COMPRESS
        LZO1C_BEST_SPEED
        LZO1C_BEST_COMPRESSION
        LZO1C_DEFAULT_COMPRESSION

cdef class Lzo1c(Lzo):
    cdef readonly int BEST_SPEED
    cdef readonly int BEST_COMPRESSION
    cdef readonly int DEFAULT_COMPRESSION
    def __cinit__(cls):
        cls.BEST_SPEED=LZO1C_BEST_SPEED
        cls.BEST_COMPRESSION=LZO1C_BEST_COMPRESSION
        cls.DEFAULT_COMPRESSION=LZO1C_DEFAULT_COMPRESSION
    def __init__(self):
        super().__init__(max(LZO1C_MEM_COMPRESS,LZO1C_99_MEM_COMPRESS,LZO1C_999_MEM_COMPRESS),LZO1C_MEM_DECOMPRESS);
    def compress(self,data:bytes,level:int)->bytes:return self.__compress_level(<lzo_compress_level_p>lzo1c_compress,data,level);
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1c_decompress,data,dst_len);
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1c_decompress_safe,data,dst_len);
    def compress_99(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_99_compress,data);
    def compress_999(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_999_compress,data);
    def compress_1(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_1_compress,data);
    def compress_2(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_2_compress,data);
    def compress_3(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_3_compress,data);
    def compress_4(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_4_compress,data);
    def compress_5(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_5_compress,data);
    def compress_6(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_6_compress,data);
    def compress_7(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_7_compress,data);
    def compress_8(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_8_compress,data);
    def compress_9(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1c_9_compress,data);

    
cdef extern from "lzo/lzo1f.h":
    int lzo1f_decompress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1f_decompress_safe(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1f_999_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    int lzo1f_1_compress(const lzo_bytep src, lzo_uint src_len, lzo_bytep dst, lzo_uintp dst_len,lzo_voidp wrkmem);
    cdef enum:
        LZO1F_MEM_COMPRESS
        LZO1F_MEM_DECOMPRESS
        LZO1F_999_MEM_COMPRESS

cdef class Lzo1f(Lzo):
    def __init__(self):
        super().__init__(max(LZO1F_MEM_COMPRESS,LZO1F_999_MEM_COMPRESS),LZO1F_MEM_DECOMPRESS);
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1f_decompress,data,dst_len);
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1f_decompress_safe,data,dst_len);
    def compress_999(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1f_999_compress,data);
    def compress_1(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1f_1_compress,data);

    
cdef extern from "lzo/lzo1x.h":
    int lzo1x_decompress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1x_decompress_safe(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1x_1_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1x_1_11_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1x_1_12_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1x_1_15_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1x_999_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1x_999_compress_dict(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem, const lzo_bytep dict, lzo_uint dict_len);
    int lzo1x_999_compress_level(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem, const lzo_bytep dict, lzo_uint dict_len, lzo_callback_p cb, int compression_level);
    int lzo1x_decompress_dict_safe(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem, const lzo_bytep dict, lzo_uint dict_len);
    int lzo1x_optimize(lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    cdef enum:
        LZO1X_MEM_COMPRESS
        LZO1X_MEM_DECOMPRESS
        LZO1X_MEM_OPTIMIZE
        LZO1X_1_MEM_COMPRESS
        LZO1X_1_11_MEM_COMPRESS
        LZO1X_1_12_MEM_COMPRESS
        LZO1X_1_15_MEM_COMPRESS
        LZO1X_999_MEM_COMPRESS

cdef class Lzo1x(Lzo):
    def __init__(self):
        super().__init__(max(LZO1X_MEM_COMPRESS,LZO1X_MEM_OPTIMIZE,LZO1X_1_MEM_COMPRESS,LZO1X_1_11_MEM_COMPRESS,LZO1X_1_12_MEM_COMPRESS,LZO1X_1_15_MEM_COMPRESS,LZO1X_999_MEM_COMPRESS),LZO1X_MEM_DECOMPRESS);
    def compress_1(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1x_1_compress,data);
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1x_decompress,data,dst_len);
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1x_decompress_safe,data,dst_len);
    def decompress_dict_safe(self,data:bytes,dst_len:lzo_uint,dict:bytes)->bytes:return self.__decompress_dict(<lzo_decompress_dict_p>lzo1x_decompress_dict_safe,data,dst_len,dict);
    def compress_999(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1x_999_compress,data);
    def compress_dict_999(self,data:bytes,dict:bytes)->bytes:return self.__compress_dict(<lzo_compress_dict_p>lzo1x_999_compress_dict,data,dict);
    def compress_level_999(self,data:bytes,level:int,callback_func:object)->bytes:return self.__compress_dict_level(<lzo_compress_dict_level_p>lzo1x_999_compress_level,data,dict,callback_func,level);
    def compress_1_11(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1x_1_11_compress,data);
    def compress_1_12(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1x_1_12_compress,data);
    def compress_1_15(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1x_1_15_compress,data);
    def optimize(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__optimize(<lzo_optimize_p>lzo1x_optimize,data,dst_len);


cdef extern from "lzo/lzo1y.h":
    int lzo1y_decompress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1y_decompress_safe(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1y_1_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1y_999_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1y_999_compress_dict(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem, const lzo_bytep dict, lzo_uint dict_len);
    int lzo1y_999_compress_level(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem, const lzo_bytep dict, lzo_uint dict_len, lzo_callback_p cb, int compression_level);
    int lzo1y_decompress_dict_safe(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem , const lzo_bytep dict, lzo_uint dict_len);
    int lzo1y_optimize(lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    cdef enum:
        LZO1Y_MEM_COMPRESS
        LZO1Y_MEM_DECOMPRESS
        LZO1Y_MEM_OPTIMIZE
        LZO1Y_999_MEM_COMPRESS

cdef class Lzo1y(Lzo):
    def __init__(self):
        super().__init__(max(LZO1Y_MEM_COMPRESS,LZO1Y_MEM_OPTIMIZE,LZO1Y_999_MEM_COMPRESS),LZO1Y_MEM_DECOMPRESS);
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1y_decompress,data,dst_len);
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1y_decompress_safe,data,dst_len);
    def compress_1(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1y_1_compress,data);
    def compress_999(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1y_999_compress,data);
    def decompress_dict_safe(self,data:bytes,dst_len:lzo_uint,dict:bytes)->bytes:return self.__decompress_dict(<lzo_decompress_dict_p>lzo1y_decompress_dict_safe,data,dst_len,dict);
    def compress_dict_999(self,data:bytes,dict:bytes)->bytes:return self.__compress_dict(<lzo_compress_dict_p>lzo1y_999_compress_dict,data,dict);
    def compress_level_999(self,data:bytes,level:int,callback_func:object)->bytes:return self.__compress_dict_level(<lzo_compress_dict_level_p>lzo1y_999_compress_level,data,dict,callback_func,level);
    def optimize(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__optimize(<lzo_optimize_p>lzo1y_optimize,data,dst_len);

cdef extern from "lzo/lzo1z.h":
    int lzo1z_decompress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1z_decompress_safe(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1z_999_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo1z_999_compress_dict(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem, const lzo_bytep dict, lzo_uint dict_len);
    int lzo1z_999_compress_level(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem, const lzo_bytep dict, lzo_uint dict_len, lzo_callback_p cb, int compression_level);
    int lzo1z_decompress_dict_safe(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem , const lzo_bytep dict, lzo_uint dict_len);
    cdef enum:
        LZO1Z_MEM_DECOMPRESS
        LZO1Z_999_MEM_COMPRESS

cdef class Lzo1z(Lzo):
    def __init__(self):
        super().__init__(LZO1Z_999_MEM_COMPRESS,LZO1Z_MEM_DECOMPRESS);
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1z_decompress,data,dst_len);
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo1z_decompress_safe,data,dst_len);
    def compress_999(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo1z_999_compress,data);
    def compress_dict_999(self,data:bytes,dict:bytes)->bytes:return self.__compress_dict(<lzo_compress_dict_p>lzo1z_999_compress_dict,data,dict);
    def compress_level_999(self,data:bytes,level:int,callback_func:object)->bytes:return self.__compress_dict_level(<lzo_compress_dict_level_p>lzo1z_999_compress_level,data,dict,callback_func,level);
    def decompress_dict_safe(self,data:bytes,dst_len:lzo_uint,dict:bytes)->bytes:return self.__decompress_dict(<lzo_decompress_dict_p>lzo1z_decompress_dict_safe,data,dst_len,dict);
    
cdef extern from "lzo/lzo2a.h":
    int lzo2a_decompress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo2a_decompress_safe(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    int lzo2a_999_compress(const lzo_bytep src, lzo_uint  src_len, lzo_bytep dst, lzo_uintp dst_len, lzo_voidp wrkmem);
    cdef enum:
        LZO2A_MEM_DECOMPRESS
        LZO2A_999_MEM_COMPRESS
cdef class Lzo2a(Lzo):
    def __init__(self):
        super().__init__(LZO2A_999_MEM_COMPRESS,LZO2A_MEM_DECOMPRESS);
    def get_need_memory(self,bytes data)->int:
        return len(data)+len(data)//8+128+3
    def decompress(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo2a_decompress,data,dst_len);
    def decompress_safe(self,data:bytes,dst_len:lzo_uint)->bytes:return self.__decompress(<lzo_decompress_p>lzo2a_decompress_safe,data,dst_len);
    def compress_999(self,data:bytes)->bytes:return self.__compress(<lzo_compress_p>lzo2a_999_compress,data);


cdef extern from "lzo/lzoconf.h":
    void lzo_init();

lzo_init();

lzo1=Lzo1();
lzo1a=Lzo1a();
lzo1b=Lzo1b();
lzo1c=Lzo1c(); 
lzo1f=Lzo1f(); 
lzo1x=Lzo1x(); 
lzo1y=Lzo1y(); 
lzo1z=Lzo1z(); 
lzo2a=Lzo2a();

#__all__=[
#    "lzo1","lzo1a","lzo1b","lzo1c","lzo1f","lzo1x","lzo1y","lzo1z","lzo2a",
#    "Lzo1","Lzo1a","Lzo1b","Lzo1c","Lzo1f","Lzo1x","Lzo1y","Lzo1z","Lzo2a"
#]