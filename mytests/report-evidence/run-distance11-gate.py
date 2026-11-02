from pathlib import Path
import csv, datetime, hashlib, json, subprocess, sys, os
r=Path(sys.argv[1]).resolve(); evidence=Path(__file__).resolve().parent
baseline=evidence
w=evidence/('near5-final-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'));w.mkdir()
(w/'probe.c').write_bytes((baseline/'rubik-depth11-probe.c').read_bytes())
prefix=os.environ.get('CROSS_COMPILE', 'riscv-none-elf-')
subprocess.run([prefix+'gcc','-march=rv32i_zicsr','-mabi=ilp32','-mno-relax','-O2','-ffreestanding','-fno-pic','-I.','-c',str(w/'probe.c'),'-o',str(w/'probe.o')],cwd=r,check=True)
subprocess.run([prefix+'ld','-T','common/linker.ld','--no-warn-rwx-segments','-o',str(w/'probe.elf'),str(w/'probe.o'),'build/rubik/impl_asm.o',*[f'build/common/{x}.o' for x in ['start','perf','rt','print']]],cwd=r,check=True)
files=[r/'src/rubik'/f for f in ['rubik.S','rubik_transition_tables.inc','rubik_distance_11_states.inc','rubik_distance_up_to_5.inc']]+[r/'build/rubik/impl_asm.o',w/'probe.elf',r/'third_party/rv32emu/build/rv32emu']
(w/'manifest.json').write_text(json.dumps({str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
with (w/'raw.csv').open('w') as out,(w/'stderr.txt').open('w') as err:
 subprocess.run(['third_party/rv32emu/build/rv32emu',str(w/'probe.elf')],cwd=r,stdout=out,stderr=err,timeout=1800,check=True)
expected=(evidence/'distance11-states.txt').read_text().splitlines()
rows=list(csv.reader((w/'raw.csv').open()));assert len(rows)==len(expected)==2644
source=[[1,4,2,0,3,5,6],[0,1,2,4,5,6,3],[0,2,5,3,1,4,6]]
twist=[[1,2,0,2,1,0,0],[0,0,0,1,2,1,2],[0,0,0,0,0,0,0]]
names=['R','R2',"R'",'B','B2',"B'",'D','D2',"D'"]
fail=[]; counts=[]; correct=0
for i,row in enumerate(rows):
 assert len(row)==5
 idx,state,n,used,out=row;assert int(idx)==i and state==expected[i]
 p=[int(c)-1 for c in state[:7]];o=[int(c)-1 for c in state[7:]];tokens=out.split(' ')
 valid=int(n)==11 and len(tokens)==11 and all(t in names for t in tokens)
 if valid:
  for token in tokens:
   m=names.index(token);face=m//3
   for _ in range(m%3+1):
    p=[p[j] for j in source[face]]
    o=[(o[j]+twist[face][k])%3 for k,j in enumerate(source[face])]
  valid=p==list(range(7)) and o==[0]*7
 correct+=valid;counts.append((int(used),state))
 if not valid or int(used)>7500000:fail.append({'state':state,'instructions':int(used),'correct':valid})
report={'cases':len(rows),'correct':correct,'over_budget':sum(c>7500000 for c,s in counts),'max_instructions':max(counts)[0],'worst_state':max(counts)[1],'failures':fail}
(w/'verification.json').write_text(json.dumps(report,indent=2))
(w/'size.txt').write_text(subprocess.check_output([prefix+'size','-A','build/rubik/impl_asm.o'],cwd=r,text=True))
print(json.dumps(report,indent=2)); print('Evidence:',w)
assert not fail
