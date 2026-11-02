from pathlib import Path
import ctypes, hashlib, json, math, random, subprocess, sys
r=Path(sys.argv[1]).resolve();w=Path(__file__).resolve().parent/'generated';w.mkdir(exist_ok=True)
subprocess.run(['gcc','-O2','-std=c11','-fPIC','-shared','src/bf16/bf16.c','src/fixed/fixed.c','-o',str(w/'diagnostic.so')],cwd=r,check=True)
lib=ctypes.CDLL(str(w/'diagnostic.so'))
lib.bf16_sqrt.argtypes=[ctypes.c_uint16];lib.bf16_sqrt.restype=ctypes.c_uint16
lib.bf16_mul.argtypes=[ctypes.c_uint16,ctypes.c_uint16];lib.bf16_mul.restype=ctypes.c_uint16
lib.q_mul.argtypes=[ctypes.c_int32,ctypes.c_int32];lib.q_mul.restype=ctypes.c_int32
def value(u):
 e=(u>>7)&255;f=u&127
 if e==255:return float('nan') if f else (-float('inf') if u&32768 else float('inf'))
 x=math.ldexp(f,-133) if e==0 else math.ldexp(128+f,e-134)
 return -x if u&32768 else x
worst=(0,None)
for a in range(0x80,0x7f80):
 y=value(lib.bf16_sqrt(a));ref=math.sqrt(value(a));err=abs(y-ref)/ref
 if err>worst[0]:worst=(err,hex(a))
# Exhaust all normalized significand pairs for representative exponent pairs.
exps=[1,32,64,126,127,128,190,222,254]
normalmax=(0,None); undermax=(0,None);normal=under=overflow=0
for ea in exps:
 for eb in exps:
  for ma in range(128):
   for mb in range(128):
    a=(ea<<7)|ma;b=(eb<<7)|mb;got=lib.bf16_mul(a,b);e=(got>>7)&255
    ref=value(a)*value(b)
    if e==255:overflow+=1;continue
    err=abs(value(got)-ref)/ref
    if e==0:
     under+=1
     if err>undermax[0]:undermax=(err,[hex(a),hex(b),hex(got)])
    else:
     normal+=1
     if err>normalmax[0]:normalmax=(err,[hex(a),hex(b),hex(got)])
rng=random.Random(20261102)
edges=[-2147483648,-2147483647,-1048576,-524288,-3,-1,0,1,3,524288,1048576,2147483647]
pairs=[(a,b) for a in edges for b in edges]+[(rng.randrange(-2**31,2**31),rng.randrange(-2**31,2**31)) for _ in range(100000)]
fail=0;wrapped=0;max_num=0
for a,b in pairs:
 product=a*b;rounded=(product+(1<<19))//(1<<20)
 wrapped+=not(-2**31<=rounded<2**31)
 bits=rounded&0xffffffff;expected=bits if bits<2**31 else bits-2**32
 fail+=lib.q_mul(a,b)!=expected
 max_num=max(max_num,abs(rounded*(1<<20)-product))
result={'sqrt_positive_normals':32512,'sqrt_max_relative_error':worst[0],'sqrt_worst_input':worst[1],
'mul_sample_exponent_fields':exps,'mul_pairs':len(exps)**2*128**2,'mul_normal_results':normal,'mul_normal_max_relative_error':normalmax,'mul_underflow_results':under,'mul_underflow_max_relative_error':undermax,'mul_overflow_results':overflow,
'fixed_pairs':len(pairs),'fixed_mismatches':fail,'fixed_wrapped_results':wrapped,'fixed_max_rounding_error_stored_units':max_num/2**20,'fixed_max_rounding_error_real_units':max_num/2**40,
'source_sha256':{f:hashlib.sha256((r/f).read_bytes()).hexdigest() for f in ['src/bf16/bf16.c','src/fixed/fixed.c']}}
(w/'error-analysis.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
assert fail==0
