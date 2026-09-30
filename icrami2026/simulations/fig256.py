import pickle, numpy as np, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt, caseB as B
plt.rcParams.update({'font.size':7.5,'font.family':'serif','axes.linewidth':0.6})
d=pickle.load(open('B_mpc_nom.pkl','rb')); o=d['o']; a=o['a']; t=o['t']
pi=pickle.load(open('B_pi_nom.pkl','rb'))['o']
def fmt(ax):
    ax.grid(alpha=0.3,lw=0.3); ax.tick_params(labelsize=7,width=0.5,length=2)
# Fig 2 wind
tt,v=B.wind(30,1e-3); vf=B.lowpass(v,1e-3,2.0)
fig,ax=plt.subplots(figsize=(3.5,1.45)); ax.plot(tt,v,'C0',lw=0.4,label='$v(t)$'); ax.plot(tt,vf,'k',lw=0.9,label='low-pass filtered (MPPT)')
ax.set_xlabel('time (s)'); ax.set_ylabel('wind speed (m/s)'); ax.set_xlim(0,30); ax.legend(fontsize=6,loc='upper right',ncol=2); fmt(ax)
fig.tight_layout(pad=0.3); fig.savefig('../paper/fig2.png',dpi=400)
# Fig 5 states
fig,axs=plt.subplots(3,1,figsize=(3.5,3.2),sharex=True)
lab=[r'$i_{dr}$ (kA)',r'$i_{qr}$ (kA)',r'$\omega_r$ (rad/s)']; scl=[1e-3,1e-3,1]
for i in range(3):
    axs[i].plot(t,o['xr'][:,i]*scl[i],'r',lw=1.2,label='reference')
    axs[i].plot(t,o['x'][:,i]*scl[i],'C0',lw=0.6,label='FL--MPC')
    axs[i].set_ylabel(lab[i]); fmt(axs[i])
axs[1].set_ylim(0.6,0.85)
axs[0].legend(fontsize=6,loc='lower right',ncol=2); axs[2].set_xlabel('time (s)'); axs[2].set_xlim(0,30)
ins=axs[0].inset_axes([0.40,0.50,0.33,0.36]); m=(t>12)&(t<14)
ins.plot(t[m],o['xr'][m,0]*1e-3,'r',lw=1.0); ins.plot(t[m],o['x'][m,0]*1e-3,'C0',lw=0.5); ins.plot(t[m],pi['x'][m,0]*1e-3,'C2--',lw=0.5)
ins.tick_params(labelsize=5,length=1.5); ins.text(0.02,0.04,'zoom; green: PI',transform=ins.transAxes,fontsize=5)
fig.tight_layout(pad=0.3,h_pad=0.2); fig.savefig('../paper/fig5.png',dpi=400)
# Fig 6 power
P=B.Ps(o['x'][:,0],a)/1e6; Pr=B.Ps(o['xr'][:,0],a)/1e6; Ppi=B.Ps(pi['x'][:,0],a)/1e6
fig,axs=plt.subplots(2,1,figsize=(3.5,2.3),sharex=True,gridspec_kw=dict(height_ratios=[2,1]))
axs[0].plot(t,Pr,'r',lw=1.2,label='$P_{s,ref}$'); axs[0].plot(t,P,'C0',lw=0.6,label='$P_s$ (FL--MPC)')
axs[0].set_ylabel('$P_s$ (MW)'); axs[0].legend(fontsize=6,loc='upper right',ncol=2); fmt(axs[0])
axs[1].plot(t,(Ppi-Pr)*1e3,'C2',lw=0.5,label='PI'); axs[1].plot(t,(P-Pr)*1e3,'C0',lw=0.6,label='FL--MPC')
axs[1].set_ylabel('error (kW)'); axs[1].set_xlabel('time (s)'); axs[1].set_ylim(-250,250); axs[1].legend(fontsize=6,loc='upper right',ncol=2); fmt(axs[1])
axs[1].set_xlim(0,30)
fig.tight_layout(pad=0.3,h_pad=0.2); fig.savefig('../paper/fig6.png',dpi=400)
