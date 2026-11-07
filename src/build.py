import re, json, sys, unicodedata
sys.path.insert(0,'.')
from fixes import FIX, REPL
CATS={"film":"Film","muzika":"Muzika","istorija":"Istorija","geografija":"Geografija","nauka":"Nauka","kultura":"Kultura","sport":"Sport","razno":"Razno"}
html=open('../index.html').read()
out=[]
# existing bank (from index.html, or from questions.js after first build)
base=json.load(open('osnovna.json',encoding='utf-8'))
for q in base: out.append(q)
import os
for f,cat in CATS.items():
    if not os.path.exists(f+'.txt'): continue
    for line in open(f+'.txt',encoding='utf-8'):
        line=line.strip()
        if not line: continue
        for k,v in FIX.items():
            if k in line.split('|')[0]: line=v; break
        if line is None: continue
        for a,b in REPL: line=line.replace(a,b)
        p=[x.strip() for x in line.split('|')]
        out.append([cat]+p)
bad=[];seen={};final=[]
norm=lambda s:re.sub(r'\s+','',s.lower())
for q in out:
    if len(q)!=6: bad.append(('fields',q)); continue
    opts=q[2:]
    if any(o.lower() in('a','b','c','d') for o in opts) or 'izbaci' in q[1]: continue
    if len(set(map(str.lower,opts)))<4 or any(not o for o in opts): bad.append(('opts',q)); continue
    if re.search('[Ѐ-ӿ]',' '.join(q)) and 'Ђ' not in q[2]: bad.append(('cyr',q)); continue
    k=norm(q[1])
    if k in seen: bad.append(('dup',q,seen[k])); continue
    seen[k]=q; final.append(q)
for b in bad: print(b)
from collections import Counter
print(Counter(q[0] for q in final), len(final))
with open('../questions.js','w',encoding='utf-8') as f:
    f.write('// Pitanja: [oblast, pitanje, TAČAN, netačan, netačan, netačan]. Generiše src/build.py.\nconst BANK = [\n')
    f.write(',\n'.join(json.dumps(q,ensure_ascii=False) for q in final))
    f.write('\n];\n')
