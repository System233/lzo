import lzo

RULES=[
    {
        "module":[
            lzo.lzo1b,
            lzo.lzo1c
        ],
        "tests":[
            [[
                'compress_99',
                'compress_999',
                'compress_1',
                'compress_2',
                'compress_3',
                'compress_4',
                'compress_5',
                'compress_6',
                'compress_7',
                'compress_8',
                'compress_9'
                ],['decompress','decompress_safe']]
        ],
        "level_tests":[
            ['compress',['decompress','decompress_safe']],
        ]
    },
    {
        "module":[
            lzo.lzo1,
            lzo.lzo1a
        ],
        "tests":[
            [['compress','compress_99'],'decompress'],
        ]
    },
    {
        "module":lzo.lzo1f,
        "tests":[
            [['compress_1','compress_999'],['decompress','decompress_safe']],
        ]
    },
    {
        "module":lzo.lzo1x,
        "optimizer":'optimize',
        "tests":[
            [[
                'compress_1',
                'compress_1_11',
                'compress_1_12',
                'compress_1_15',
                'compress_999'
            ],['decompress','decompress_safe']],
        ]
    },
    {
        "module":lzo.lzo1y,
        "optimizer":'optimize',
        "tests":[
            [[
                'compress_1',
                'compress_999'
            ],['decompress','decompress_safe']],
        ]
    },
    {
        "module":[lzo.lzo1z,lzo.lzo2a],
        "tests":[
            [[
                'compress_999'
            ],['decompress','decompress_safe']],
        ]
    }
]
import sys

test_cases=([b'0123456789'*i for i in range(1,10000,1000)])
def isiterable(obj):
    return any(map(lambda x:isinstance(obj,x),[list,tuple]))
def asiterbale(obj)->list:
    if isiterable(obj):
        return obj
    return [obj]
FAIL_MESSAGE=[]
def test_rule(rule:dict):
    modules=rule.get('module',[])
    optimizers=rule.get('optimizer',[])
    tests=rule.get('tests',[])
    level_tests=rule.get('level_tests',[])
    modules=asiterbale(modules)
    optimizers=asiterbale(optimizers)
    def test(executor,tests):
        ERROR_COUNT=0
        for module in modules:
            for compressors,decompressors in tests:
                compressors=asiterbale(compressors)
                decompressors=asiterbale(decompressors)
                for compressor in compressors:
                    comp_func=getattr(module,compressor)
                    for decompressor in decompressors:
                        decomp_func=getattr(module,decompressor)
                        for index,case in enumerate(test_cases):
                            optimizer_iter=iter(optimizers)
                            optimizer=None
                            try:
                                while True:
                                    optimizer_func=getattr(module,optimizer) if optimizer else None
                                    print('Testing %s [%s/%s/%s] on case %i (len=%s)'%(module,compressor,optimizer,decompressor,index,len(case)),end=' ')
                                    sys.stdout.flush()
                                    result=executor(case,module,comp_func,optimizer_func,decomp_func)
                                    print('PASS' if result else 'FAIL')
                                    sys.stdout.flush()
                                    if not result:
                                        FAIL_MESSAGE.append('[FAIL] module %s [%s/%s/%s] on case %i (len=%s)'%(module,compressor,optimizer,decompressor,index,len(case)));
                                        ERROR_COUNT+=1
                                    optimizer=next(optimizer_iter)
                            except StopIteration:
                                pass
        return ERROR_COUNT;
    def normal_executor(case,module,compressor,optimizer,decompressor):
        encoded=compressor(case)
        if optimizer:
            encoded=optimizer(encoded,len(case))
        decoded=decompressor(encoded,len(case))
        return decoded==case
    def level_executor(case,module,compressor,optimizer,decompressor):
        def executor(level):
            encoded=compressor(case,level)
            if optimizer:
                encoded=optimizer(encoded,len(case))
            decoded=decompressor(encoded,len(case))
            return decoded==case
        return all([executor(level) for level in range(module.BEST_SPEED,module.BEST_COMPRESSION+1)])
    error=0
    error+=test(normal_executor,tests)
    error+=test(level_executor,level_tests)
    return error
TEST_RESULT=[test_rule(rule) for rule in RULES]
print(TEST_RESULT)
print('ALL CASES PASSED' if not all(TEST_RESULT) else '[Test Fail]\n%s'%('\n'.join(FAIL_MESSAGE)))