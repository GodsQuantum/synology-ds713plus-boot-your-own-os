#!/usr/bin/env python3
import argparse, pathlib, sys
p=argparse.ArgumentParser()
p.add_argument('stock'); p.add_argument('candidate')
p.add_argument('--bios-base',type=lambda x:int(x,0),default=0x11000)
p.add_argument('--bios-end',type=lambda x:int(x,0),default=0x210fff)
p.add_argument('--erase',type=int,default=4096); p.add_argument('--layout',required=True)
a=p.parse_args(); s=pathlib.Path(a.stock).read_bytes(); c=pathlib.Path(a.candidate).read_bytes()
if len(s)!=len(c): sys.exit('size mismatch')
d=[i for i,(x,y) in enumerate(zip(s,c)) if x!=y]
if not d: sys.exit('no differences')
first,last=d[0],d[-1]; start=(first//a.erase)*a.erase; end=((last//a.erase)+1)*a.erase-1
if start<a.bios_base or end>a.bios_end: sys.exit(f'aligned patchzone crosses BIOS boundary: {start:#x}-{end:#x}')
pathlib.Path(a.layout).write_text(f'{start:08x}:{end:08x} patchzone\n')
print(f'DIFF_BYTES_TOTAL={len(d)}'); print(f'DIFF_FIRST_PHYSICAL=0x{first:06x}'); print(f'DIFF_LAST_PHYSICAL=0x{last:06x}')
print(f'PATCH_START=0x{start:06x}'); print(f'PATCH_END=0x{end:06x}'); print(f'PATCH_SIZE={end-start+1}'); print('PATCH_INSIDE_BIOS=YES')
