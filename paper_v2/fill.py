"""Fill main.tpl.tex with the results printed by PMSG_WECS.m (log) and the CSV files.
usage: python3 fill.py <log> <csv_dir>"""
import re, sys, os, numpy as np
log, D = sys.argv[1], sys.argv[2]
txt = open(log).read()
T = {}
for sc, key in [('NOMINAL', 'nom'), ('ROBUST', 'rob')]:
    blk = txt.split(sc)[1].split('\n')[2:12]
    for line in blk:
        f = line.split()
        if len(f) == 4:
            for c, v in zip(['PI', 'FP', 'FPANN'], f[1:]):
                T[f'{key}.{c}.{f[0]}'] = float(v)
def fmt(k, v):
    m = k.split('.')[-1]
    if m == 'IAE_W': return f'{v:.3f}'
    if m in ('RMS_isq',): return f'{v:.3f}'
    if m in ('dV_max',): return f'{v:.2f}' if v < 1 else f'{v:.1f}'
    if m == 'dV_dip': return f'{v:.1f}'
    if m == 'E_kWh': return f'{v:.3f}'
    if m == 'eta_mppt': return f'{v:.1f}'
    if m == 'Te_std': return f'{v:.3f}'
    return f'{v:.3g}'
V = {k: fmt(k, v) for k, v in T.items()}
pct = lambda a, b: f'{100*(1 - a/b):.0f}'
V['pct_fp_pi_nom'] = pct(T['nom.FP.IAE_W'], T['nom.PI.IAE_W'])
V['pct_fp_pi_rob'] = pct(T['rob.FP.IAE_W'], T['rob.PI.IAE_W'])
V['pct_ann_fp_nom'] = pct(T['nom.FPANN.IAE_W'], T['nom.FP.IAE_W'])
V['pct_ann_fp_rob'] = pct(T['rob.FPANN.IAE_W'], T['rob.FP.IAE_W'])
V['pct_te'] = f"{100*(T['rob.FPANN.Te_std']/T['rob.FP.Te_std'] - 1):.0f}"
V['dip_avg'] = f"{np.mean([T['rob.PI.dV_dip'], T['rob.FP.dV_dip'], T['rob.FPANN.dV_dip']]):.0f}"
d = np.genfromtxt(os.path.join(D, 'res_robust_FPANN.csv'), delimiter=',', names=True)
V['vmin'] = f"{d['v'].min():.1f}"; V['vmax'] = f"{d['v'].max():.1f}"
m = d['t'] > 5
lump = (d['Tw'] - d['Twh']) + 1.5*26*9.18*(0.95 - 1)*d['isq']
V['lump_mean'] = f"{lump[m].mean()/1e3:.0f}"
V['lump_pct'] = f"{100*lump[m].mean()/d['Tw'][m].mean():.0f}"
s = open('main.tpl.tex').read()
for k, v in V.items():
    s = s.replace('{{' + k + '}}', v)
left = re.findall(r'\{\{[^}]*\}\}', s)
open('main.tex', 'w').write(s)
print('unfilled:', left)
for k in sorted(V): print(k, V[k])
