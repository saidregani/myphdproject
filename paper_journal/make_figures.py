import numpy as np, matplotlib, sys, os
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
for f in ['regular', 'bold', 'italic']:
    fm.fontManager.addfont(f'/usr/share/texmf/fonts/opentype/public/tex-gyre/texgyretermes-{f}.otf')
plt.rcParams.update({'font.family': 'TeX Gyre Termes', 'mathtext.fontset': 'stix', 'font.size': 9,
    'axes.linewidth': 0.6, 'axes.grid': True, 'grid.linewidth': 0.3, 'grid.alpha': 0.5,
    'legend.fontsize': 8, 'legend.frameon': False, 'xtick.major.width': 0.6, 'ytick.major.width': 0.6})
D, O = sys.argv[1], sys.argv[2]
RED, BLUE, GREEN = '#d62728', '#1f77b4', '#2ca02c'
DASH = (0, (3, 2))
W = 6.3
cache = {}
def load(s, c):
    if (s, c) not in cache:
        cache[s, c] = np.genfromtxt(os.path.join(D, f'res_{s}_{c}.csv'), delimiter=',', names=True)
    return cache[s, c]
def save(fig, name):
    fig.savefig(f'{O}/{name}.pdf'); fig.savefig(f'{O}/{name}.png', dpi=150); plt.close(fig)
def inset(ax, t, curves, zoom, box):
    ia = ax.inset_axes(list(box)); m = (t >= zoom[0]) & (t <= zoom[1])
    for y, kw in curves: ia.plot(t[m], y[m], **kw)
    ia.set_xlim(*zoom[:2])
    if len(zoom) > 2: ia.set_ylim(*zoom[2:])
    ia.tick_params(labelsize=6.5, length=2, pad=1); ia.grid(True, lw=0.2)
    ax.indicate_inset_zoom(ia, edgecolor='0.4', lw=0.5)

# ---- wind profiles -----------------------------------------------------------
st, tu = load('step', 'FPANN'), load('nominal', 'FPANN')
fig, ax = plt.subplots(1, 2, figsize=(W, 2.0))
ax[0].plot(st['t'], st['v'], 'k', lw=0.9); ax[0].set_title('(a) step profile', fontsize=9, pad=3)
ax[1].plot(tu['t'], tu['v'], 'k', lw=0.6); ax[1].set_title('(b) turbulent profile', fontsize=9, pad=3)
for a in ax: a.set_xlim(0, 40); a.set_xlabel('$t$ (s)'); a.set_ylabel('$v$ (m/s)'); a.set_ylim(5, 12)
fig.tight_layout(pad=0.3, w_pad=1.0); save(fig, 'wind')

# ---- step wind: references vs measured ----------------------------------------
d = st; t = d['t']; z = np.zeros_like(t)
def panel(ax, ref, meas, lab, unit, s=1.0, ylim=None, zoom=None, zbox=None, loc='upper left'):
    ax.plot(t, meas/s, color=RED, lw=0.7, zorder=2)
    ax.plot(t, ref/s, color='k', lw=1.0, ls=DASH, zorder=3)
    ax.set_ylabel(f'${lab}$ ({unit})'); ax.set_xlim(0, t[-1])
    if ylim: ax.set_ylim(*ylim)
    ax.plot([], [], color='k', lw=1.0, ls=DASH, label=f'${lab}^*$')
    ax.plot([], [], color=RED, lw=1.2, label=f'${lab}$ (measured)')
    ax.legend(ncol=2, loc=loc)
    if zoom:
        inset(ax, t, [(meas/s, dict(color=RED, lw=0.6)), (ref/s, dict(color='k', lw=1.0, ls=DASH))], zoom, zbox)
fig, ax = plt.subplots(3, 2, figsize=(W, 5.2), sharex=True)
panel(ax[0, 0], d['Wr'], d['Wm'], r'\Omega', 'rad/s', ylim=(1.3, 2.55), zoom=(24.6, 27.0, 2.0, 2.26), zbox=(0.05, 0.47, 0.22, 0.33))
panel(ax[0, 1], 1200 + z, d['Vdcm'], 'V_{dc}', 'V', ylim=(1180, 1225), zoom=(24.95, 25.4, 1190, 1210), zbox=(0.6, 0.06, 0.35, 0.36))
panel(ax[1, 0], d['isqr'], d['isqm'], 'i_{sq}', 'kA', 1e3, ylim=(-3.2, 0.7), zoom=(24.9, 25.8, -2.6, -0.3), zbox=(0.4, 0.55, 0.22, 0.36), loc='upper right')
panel(ax[1, 1], z, d['isdm'], 'i_{sd}', 'A', ylim=(-60, 60))
panel(ax[2, 0], d['igdr'], d['igdm'], 'i_{gd}', 'kA', 1e3, ylim=(0, 3.4), zoom=(24.9, 25.8, 0.3, 2.5), zbox=(0.05, 0.5, 0.22, 0.33))
panel(ax[2, 1], z, d['igqm'], 'i_{gq}', 'A', ylim=(-150, 150))
for a in ax[2]: a.set_xlabel('$t$ (s)')
fig.tight_layout(pad=0.3, h_pad=0.4, w_pad=1.0); save(fig, 'tracking_step')

# ---- robustness case: speed, Cp, powers --------------------------------------
r = load('robust', 'FPANN'); t = r['t']
Pmax = 0.5*1.225*np.pi*40**2*0.48*1.1*r['v']**3
Pw = r['Tw']*r['W']
fig, ax = plt.subplots(3, 1, figsize=(W, 4.8), sharex=True)
ax[0].plot(t, r['Wm'], color=RED, lw=1.0, label=r'$\Omega$ (measured)', zorder=2)
ax[0].plot(t, r['Wr'], color='k', lw=1.0, ls=DASH, label=r'$\Omega^*$', zorder=3)
ax[0].set_ylabel(r'$\Omega$ (rad/s)'); ax[0].legend(ncol=2, loc='upper right')
inset(ax[0], t, [(r['Wm'], dict(color=RED, lw=0.8)), (r['Wr'], dict(color='k', lw=1.0, ls=DASH))], (14, 18), (0.3, 0.08, 0.22, 0.38))
ax[1].plot(t, r['Cp'], color=RED, lw=0.7, label='$C_p$'); ax[1].axhline(0.48*1.1, color='k', ls=':', lw=0.8, label=r'$C_{p,\max}$')
ax[1].set_ylim(0.3, 0.6); ax[1].set_ylabel('$C_p$'); ax[1].legend(ncol=2, loc='lower right')
ax[2].plot(t, Pmax/1e6, color='k', lw=0.6, label=r'$P_{\max}$ (available)')
ax[2].plot(t, Pw/1e6, color=BLUE, lw=0.9, label='$P_w$ (captured)')
ax[2].plot(t, r['Pg']/1e6, color=RED, lw=0.6, label='$P_g$ (injected)')
ax[2].set_ylabel('power (MW)'); ax[2].legend(ncol=3, loc='upper right'); ax[2].set_ylim(0, 2.6)
ax[2].set_xlabel('$t$ (s)'); ax[2].set_xlim(0, t[-1])
fig.tight_layout(pad=0.3, h_pad=0.4); save(fig, 'mppt')

# ---- effect of the network -----------------------------------------------------
fig, ax = plt.subplots(3, 1, figsize=(W, 5.4))
for k, (s, ttl) in enumerate([('step', '(a) step wind, nominal parameters'),
                              ('robust', '(b) turbulent wind, parameter mismatch')]):
    for c, col, lab in [('FP', BLUE, 'without ANN'), ('FPANN', RED, 'with ANN')]:
        q = load(s, c); ax[k].plot(q['t'], (q['W'] - q['Wr'])*1e3, color=col, lw=0.8, label=lab)
    ax[k].set_title(ttl, fontsize=9, pad=3); ax[k].set_ylabel(r'$\Omega-\Omega^*$ (mrad/s)')
    ax[k].set_xlim(0, 40); ax[k].legend(ncol=2, loc='lower right')
ax[0].set_ylim(-35, 25); ax[1].set_ylim(-20, 20)
q0, q1 = load('step', 'FP'), load('step', 'FPANN')
inset(ax[0], q0['t'], [((q0['W'] - q0['Wr'])*1e3, dict(color=BLUE, lw=0.8)), ((q1['W'] - q1['Wr'])*1e3, dict(color=RED, lw=0.8))],
      (25, 31, -35, 12), (0.68, 0.55, 0.28, 0.4))
for s, ls in [('step', '-'), ('nominal', '--'), ('robust', ':')]:
    for c, col in [('FP', BLUE), ('FPANN', RED)]:
        q = load(s, c); tt = q['t']; dt = tt[1] - tt[0]; m = tt >= 1
        ax[2].plot(tt[m], np.cumsum(np.abs(q['W'] - q['Wr'])[m])*dt, color=col, ls=ls, lw=1.0)
ax[2].plot([], [], 'k-', label='step'); ax[2].plot([], [], 'k--', label='turbulent'); ax[2].plot([], [], 'k:', label='robustness')
ax[2].set_title('(c) cumulative IAE (blue: without ANN, red: with ANN)', fontsize=9, pad=3)
ax[2].set_ylabel(r'$\int|\Omega-\Omega^*|\,dt$ (rad)'); ax[2].set_xlabel('$t$ (s)'); ax[2].set_xlim(0, 40)
ax[2].legend(ncol=3, loc='upper left')
fig.tight_layout(pad=0.3, h_pad=0.5); save(fig, 'ann_effect')

# ---- network output -----------------------------------------------------------
fig, ax = plt.subplots(1, 1, figsize=(W, 2.1))
lump = (r['Tw'] - r['Twh']) + 1.5*26*9.18*(0.95 - 1.0)*r['isq']
k = int(round(1.0/(t[1] - t[0]))); lump_f = np.convolve(lump, np.ones(k)/k, 'same')
ax.plot(t, lump_f/1e3, 'k', lw=0.9, label=r'$\Delta$ (actual, 1-s average)')
ax.plot(t, r['Dh']/1e3, color=RED, lw=1.0, label=r'$\hat\Delta$ (network output)')
ax.set_ylabel('torque (kN$\\cdot$m)'); ax.set_xlabel('$t$ (s)'); ax.set_xlim(0, 40)
ax.legend(ncol=2, loc='upper right'); ax.set_ylim(min(lump_f.min(), r['Dh'].min())/1e3 - 20, 420)
fig.tight_layout(pad=0.3); save(fig, 'network')

# ---- grid voltage dip -------------------------------------------------------------
tf = np.linspace(24.95, 25.30, 8000); th = 2*np.pi*50*tf
kd = np.where((tf >= 25) & (tf < 25.15), 0.5, 1.0)
vga = 563.4*kd*(np.cos(th) + 0.02*np.cos(5*th) + 0.015*np.cos(7*th))
iga = np.interp(tf, t, r['igd'])*np.cos(th) - np.interp(tf, t, r['igq'])*np.sin(th)
m = (t >= 24.95) & (t <= 25.30)
fig, ax = plt.subplots(3, 1, figsize=(W, 4.3), sharex=True)
ax[0].plot(tf, vga, 'k', lw=0.7); ax[0].set_ylabel('$v_{ga}$ (V)'); ax[0].set_ylim(-700, 700)
ax[1].plot(tf, iga/1e3, color=RED, lw=0.7); ax[1].set_ylabel('$i_{ga}$ (kA)')
ax[2].plot(t[m], r['Vdcm'][m], color=RED, lw=0.7, label='$V_{dc}$ (measured)')
ax[2].plot(t[m], 1200 + 0*t[m], 'k', lw=1.0, ls=DASH, label='$V_{dc}^*$')
ax[2].set_ylabel('$V_{dc}$ (V)'); ax[2].legend(ncol=2, loc='upper right'); ax[2].set_ylim(1180, 1225)
ax[2].set_xlabel('$t$ (s)'); ax[2].set_xlim(24.95, 25.30)
for a in ax: a.axvspan(25.0, 25.15, color='0.9', lw=0, zorder=0)
fig.tight_layout(pad=0.3, h_pad=0.4); save(fig, 'grid')
print('ok')
