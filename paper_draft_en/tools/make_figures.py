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
KAP = 1.5*26*9.18
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
def refmeas(ax, t, ref, meas, lab, unit, s=1.0, loc='upper left', lw=0.7):
    ax.plot(t, meas/s, color=RED, lw=lw, zorder=2)
    ax.plot(t, ref/s, color='k', lw=1.0, ls=DASH, zorder=3)
    ax.plot([], [], color='k', lw=1.0, ls=DASH, label=f'${lab}^*$')
    ax.plot([], [], color=RED, lw=1.2, label=f'${lab}$ (measured)')
    ax.set_ylabel(f'${lab}$ ({unit})'); ax.legend(ncol=2, loc=loc)

st, nm, rb = load('step', 'FPANN'), load('nominal', 'FPANN'), load('robust', 'FPANN')

# ---- Fig. speed tracking ---------------------------------------------------------
fig, ax = plt.subplots(4, 1, figsize=(W, 7.0))
t = st['t']; refmeas(ax[0], t, st['Wr'], st['Wm'], r'\Omega', 'rad/s', lw=1.0)
ax[0].set_ylim(1.4, 2.5); ax[0].set_title('(a) step wind, with ANN', fontsize=9, pad=3)
inset(ax[0], t, [(st['Wm'], dict(color=RED, lw=0.8)), (st['Wr'], dict(color='k', lw=1.0, ls=DASH))], (24.6, 28.0, 1.9, 2.27), (0.68, 0.45, 0.28, 0.45))
t = rb['t']; refmeas(ax[1], t, rb['Wr'], rb['Wm'], r'\Omega', 'rad/s', loc='upper right', lw=1.0)
ax[1].set_title('(b) turbulent wind with parameter mismatch, with ANN', fontsize=9, pad=3)
inset(ax[1], t, [(rb['Wm'], dict(color=RED, lw=0.8)), (rb['Wr'], dict(color='k', lw=1.0, ls=DASH))], (14, 18), (0.3, 0.08, 0.22, 0.38))
for c, col, lab in [('FP', BLUE, 'without ANN'), ('FPANN', RED, 'with ANN')]:
    q = load('robust', c); ax[2].plot(q['t'], (q['W'] - q['Wr'])*1e3, color=col, lw=0.8, label=lab)
ax[2].set_ylabel(r'$\Omega-\Omega^*$ (mrad/s)'); ax[2].legend(ncol=2, loc='lower right'); ax[2].set_ylim(-20, 20)
ax[2].set_title('(c) speed error, turbulent wind with parameter mismatch', fontsize=9, pad=3)
for s, ls in [('step', '-'), ('nominal', '--'), ('robust', ':')]:
    for c, col in [('FP', BLUE), ('FPANN', RED)]:
        q = load(s, c); tt = q['t']; dt = tt[1] - tt[0]; m = tt >= 1
        ax[3].plot(tt[m], np.cumsum(np.abs(q['W'] - q['Wr'])[m])*dt, color=col, ls=ls, lw=1.0)
ax[3].plot([], [], 'k-', label='step'); ax[3].plot([], [], 'k--', label='turbulent'); ax[3].plot([], [], 'k:', label='mismatch')
ax[3].set_title('(d) cumulative IAE (blue: without ANN, red: with ANN)', fontsize=9, pad=3)
ax[3].set_ylabel(r'$\int|\Omega-\Omega^*|\,dt$ (rad)'); ax[3].legend(ncol=3, loc='upper left')
for a in ax: a.set_xlim(0, 40)
ax[3].set_xlabel('$t$ (s)')
fig.tight_layout(pad=0.3, h_pad=0.5); save(fig, 'speed')

# ---- Fig. power coefficient and powers ------------------------------------------
t = nm['t']
Pmax = 0.5*1.225*np.pi*40**2*0.48*nm['v']**3
fig, ax = plt.subplots(2, 1, figsize=(W, 3.6), sharex=True)
ax[0].plot(t, nm['Cp'], color=RED, lw=0.7, label='$C_p$'); ax[0].axhline(0.48, color='k', ls=':', lw=0.8, label=r'$C_{p,\max}$')
ax[0].set_ylim(0.3, 0.55); ax[0].set_ylabel('$C_p$'); ax[0].legend(ncol=2, loc='lower right')
ax[1].plot(t, Pmax/1e6, color='k', lw=0.6, label=r'$P_{\max}$ (available)')
ax[1].plot(t, nm['Tw']*nm['W']/1e6, color=BLUE, lw=0.9, label='$P_w$ (captured)')
ax[1].plot(t, nm['Pg']/1e6, color=RED, lw=0.6, label='$P_g$ (injected)')
ax[1].set_ylabel('power (MW)'); ax[1].legend(ncol=3, loc='upper right'); ax[1].set_ylim(0, 2.6)
ax[1].set_xlabel('$t$ (s)'); ax[1].set_xlim(0, 40)
fig.tight_layout(pad=0.3, h_pad=0.4); save(fig, 'power_cp')

# ---- Fig. currents (step wind) ---------------------------------------------------
t = st['t']; z = np.zeros_like(t)
fig, ax = plt.subplots(2, 2, figsize=(W, 3.9), sharex=True)
refmeas(ax[0, 0], t, st['isqr']/1e3, st['isqm']/1e3, 'i_{sq}', 'kA', loc='upper right'); ax[0, 0].set_ylim(-3.2, 0.7)
inset(ax[0, 0], t, [(st['isqm']/1e3, dict(color=RED, lw=0.6)), (st['isqr']/1e3, dict(color='k', lw=1.0, ls=DASH))], (24.9, 25.8, -2.6, -0.3), (0.05, 0.5, 0.25, 0.36))
refmeas(ax[0, 1], t, z, st['isdm'], 'i_{sd}', 'A'); ax[0, 1].set_ylim(-60, 60)
refmeas(ax[1, 0], t, st['igdr']/1e3, st['igdm']/1e3, 'i_{gd}', 'kA'); ax[1, 0].set_ylim(0, 4.2)
inset(ax[1, 0], t, [(st['igdm']/1e3, dict(color=RED, lw=0.6)), (st['igdr']/1e3, dict(color='k', lw=1.0, ls=DASH))], (24.9, 25.8, 0.3, 2.5), (0.68, 0.6, 0.25, 0.36))
refmeas(ax[1, 1], t, z, st['igqm'], 'i_{gq}', 'A'); ax[1, 1].set_ylim(-150, 150)
for a in ax.flat: a.set_xlim(0, 40)
for a in ax[1]: a.set_xlabel('$t$ (s)')
fig.tight_layout(pad=0.3, h_pad=0.4, w_pad=1.0); save(fig, 'currents')

# ---- Fig. torque -------------------------------------------------------------------
t = st['t']
fig, ax = plt.subplots(2, 1, figsize=(W, 3.9))
ax[0].plot(t, -KAP*st['isqm']/1e6, color=RED, lw=0.6, label='$-T_e$ (measured)', zorder=2)
ax[0].plot(t, -KAP*st['isqr']/1e6, color='k', lw=1.0, ls=DASH, label='$-T_e^*$', zorder=3)
ax[0].plot(t, st['Tw']/1e6, color=BLUE, lw=0.9, label='$T_w$', zorder=1)
ax[0].set_ylabel('torque (MN$\\cdot$m)'); ax[0].legend(ncol=3, loc='upper left'); ax[0].set_ylim(0, 1.3)
ax[0].set_title('(a) step wind: electromagnetic and aerodynamic torques', fontsize=9, pad=3); ax[0].set_xlim(0, 40)
inset(ax[0], t, [(-KAP*st['isqm']/1e6, dict(color=RED, lw=0.6)), (-KAP*st['isqr']/1e6, dict(color='k', lw=1.0, ls=DASH))], (18, 18.3, 0.85, 0.92), (0.4, 0.08, 0.25, 0.3))
t = rb['t']
lump = (rb['Tw'] - rb['Twh']) + KAP*(0.95 - 1.0)*rb['isq']
k = int(round(1.0/(t[1] - t[0]))); lump_f = np.convolve(lump, np.ones(k)/k, 'same')
ax[1].plot(t, lump_f/1e3, 'k', lw=0.9, label=r'$\Delta$ (actual, 1-s average)')
ax[1].plot(t, rb['Dh']/1e3, color=RED, lw=1.0, label=r'$\hat\Delta$ (network output)')
ax[1].set_ylabel('torque (kN$\\cdot$m)'); ax[1].set_xlabel('$t$ (s)'); ax[1].set_xlim(0, 40)
ax[1].legend(ncol=2, loc='upper right'); ax[1].set_ylim(min(lump_f.min(), rb['Dh'].min())/1e3 - 20, 420)
ax[1].set_title('(b) turbulent wind with parameter mismatch: lumped uncertainty and RBF estimate', fontsize=9, pad=3)
fig.tight_layout(pad=0.3, h_pad=0.5); save(fig, 'torque')

# ---- Fig. DC link and voltage dip ---------------------------------------------------
fig, ax = plt.subplots(4, 1, figsize=(W, 6.0))
t = st['t']; refmeas(ax[0], t, 1200 + 0*t, st['Vdcm'], 'V_{dc}', 'V'); ax[0].set_ylim(1180, 1225); ax[0].set_xlim(0, 40)
ax[0].set_title('(a) step wind', fontsize=9, pad=3); ax[0].set_xlabel('$t$ (s)')
t = rb['t']
tf = np.linspace(24.95, 25.30, 8000); th = 2*np.pi*50*tf
kd = np.where((tf >= 25) & (tf < 25.15), 0.5, 1.0)
vga = 563.4*kd*(np.cos(th) + 0.02*np.cos(5*th) + 0.015*np.cos(7*th))
iga = np.interp(tf, t, rb['igd'])*np.cos(th) - np.interp(tf, t, rb['igq'])*np.sin(th)
m = (t >= 24.95) & (t <= 25.30)
ax[1].plot(tf, vga, 'k', lw=0.7); ax[1].set_ylabel('$v_{ga}$ (V)'); ax[1].set_ylim(-700, 700)
ax[1].set_title('(b)–(d) 50 % grid voltage dip (shaded), parameter mismatch', fontsize=9, pad=3)
ax[2].plot(tf, iga/1e3, color=RED, lw=0.7); ax[2].set_ylabel('$i_{ga}$ (kA)')
refmeas(ax[3], t[m], 1200 + 0*t[m], rb['Vdcm'][m], 'V_{dc}', 'V', loc='upper right'); ax[3].set_ylim(1180, 1225)
for a in ax[1:]: a.set_xlim(24.95, 25.30); a.axvspan(25.0, 25.15, color='0.9', lw=0, zorder=0)
ax[3].set_xlabel('$t$ (s)')
fig.tight_layout(pad=0.3, h_pad=0.5); save(fig, 'dclink')

# ---- Fig. active and reactive powers ------------------------------------------------
t = rb['t']
fig, ax = plt.subplots(2, 1, figsize=(W, 3.6))
ax[0].plot(t, rb['Pg']/1e6, color=RED, lw=0.6, label='$P_g$ (MW)')
ax[0].plot(t, rb['Qg']/1e6, color=GREEN, lw=0.6, label='$Q_g$ (Mvar)')
ax[0].set_xlim(0, 40); ax[0].set_ylim(-0.3, 2.0); ax[0].legend(ncol=2, loc='upper right'); ax[0].set_ylabel('grid powers')
ax[0].set_title('(a) turbulent wind with parameter mismatch', fontsize=9, pad=3); ax[0].set_xlabel('$t$ (s)')
m = (t >= 24.9) & (t <= 25.4)
ax[1].plot(t[m], rb['Pg'][m]/1e6, color=RED, lw=0.8, label='$P_g$ (MW)')
ax[1].plot(t[m], rb['Qg'][m]/1e6, color=GREEN, lw=0.8, label='$Q_g$ (Mvar)')
ax[1].axvspan(25.0, 25.15, color='0.9', lw=0, zorder=0); ax[1].set_xlim(24.9, 25.4); ax[1].set_ylim(-0.3, 1.2)
ax[1].legend(ncol=2, loc='upper right'); ax[1].set_ylabel('grid powers'); ax[1].set_xlabel('$t$ (s)')
ax[1].set_title('(b) enlarged view of the voltage dip (shaded)', fontsize=9, pad=3)
fig.tight_layout(pad=0.3, h_pad=0.5); save(fig, 'pq')

# ---- Fig. grid-current waveform and spectrum ----------------------------------------
t = nm['t']; dt = t[1] - t[0]
i0 = np.argmin(abs(t - 20)); n = int(round(0.2/dt)); iw = slice(i0, i0 + n); th = 2*np.pi*50*t[iw]
ia = nm['igd'][iw]*np.cos(th) - nm['igq'][iw]*np.sin(th)
F = np.abs(np.fft.rfft(ia))/n*2; h = np.array([F[10*k] for k in range(1, 21)]); hp = 100*h/h[0]
thd = 100*np.sqrt((h[1:]**2).sum())/h[0]
tf = np.linspace(20, 20.04, 2000); thf = 2*np.pi*50*tf
iaf = np.interp(tf, t, nm['igd'])*np.cos(thf) - np.interp(tf, t, nm['igq'])*np.sin(thf)
fig, ax = plt.subplots(1, 2, figsize=(W, 2.5), gridspec_kw=dict(width_ratios=[1, 1.15]))
ax[0].plot((tf - 20)*1e3, iaf/1e3, color=RED, lw=0.9); ax[0].set_xlabel('$t-20$ s (ms)'); ax[0].set_ylabel('$i_{ga}$ (kA)')
ax[0].set_title('(a) phase-$a$ grid current', fontsize=9, pad=3); ax[0].set_xlim(0, 40)
hh = np.arange(2, 21)
ax[1].bar(hh, hp[1:], color=RED, width=0.6, label='simulated')
lim = np.where(hh < 11, 4.0, np.where(hh < 17, 2.0, 1.5))*np.where(hh % 2 == 0, 0.25, 1.0)
ax[1].hlines(lim, hh - 0.42, hh + 0.42, colors='k', lw=1.0, label='IEEE 519 limit')
ax[1].set_xlabel('harmonic order'); ax[1].set_ylabel('% of fundamental'); ax[1].set_xlim(1.4, 20.6); ax[1].set_ylim(0, 4.6)
ax[1].set_xticks(range(2, 21, 2)); ax[1].legend(loc='upper right')
ax[1].set_title(f'(b) spectrum, THD = {thd:.2f} %', fontsize=9, pad=3)
fig.tight_layout(pad=0.3, w_pad=1.2); save(fig, 'thd')
print('ok', round(thd, 2), np.round(hp[[4, 6]], 2))
