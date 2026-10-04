import pickle, numpy as np, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from model import coef, P0, TURB, Ps
plt.rcParams.update({'font.size':7.5,'font.family':'serif','axes.linewidth':0.6})
def fmt(ax): ax.grid(alpha=0.3,lw=0.3); ax.tick_params(labelsize=7,width=0.5,length=2)
L=lambda f: pickle.load(open(f,'rb'))
# ---- Fig 4: chaos suppression
A=L('A_mpc_nom.pkl')['out']; Api=L('A_pi_nom.pkl')['out']; xs=A['xstar']
fig,axs=plt.subplots(3,1,figsize=(3.5,3.4),sharex=True)
lab=[r'$x_1=i_{dr}$ (A)',r'$x_2=i_{qr}$ (A)',r'$x_3=\omega_r$ (rad/s)']
for i in range(3):
    axs[i].plot(A['t'],A['x'][:,i],'C0',lw=0.5,label='FL--MPC')
    axs[i].axhline(xs[i],color='k',ls='-.',lw=0.5); axs[i].axvline(10,color='gray',lw=0.5)
    axs[i].set_ylabel(lab[i]); fmt(axs[i])
axs[2].set_xlabel('time (s)'); axs[2].set_xlim(0,14)
fig.tight_layout(pad=0.3,h_pad=0.2); fig.savefig('fig4.png',dpi=400)
# ---- Fig 5: MPPT tracking
B=L('B_mpc_nom.pkl')['out']; Bpi=L('B_pi_nom.pkl')['out']; t=B['t']
fig,axs=plt.subplots(3,1,figsize=(3.5,3.2),sharex=True)
lab=[r'$i_{dr}$ (A)',r'$i_{qr}$ (A)',r'$\omega_r$ (rad/s)']
for i in range(3):
    axs[i].plot(t,B['xr'][:,i],'r',lw=1.1,label='reference'); axs[i].plot(t,B['x'][:,i],'C0',lw=0.5,label='FL--MPC')
    axs[i].set_ylabel(lab[i]); fmt(axs[i])
axs[1].set_ylim(10,35); axs[0].set_ylim(-700,700); axs[0].legend(fontsize=6,loc='upper right',ncol=2)
axs[2].set_xlabel('time (s)'); axs[2].set_xlim(0,30)
fig.tight_layout(pad=0.3,h_pad=0.2); fig.savefig('fig5.png',dpi=400)
# ---- Fig 6: power
pn=dict(P0); pn['D']=TURB['Dn']; a=coef(pn)
P=Ps(B['x'][:,0],a)/1e3; Pr=Ps(B['xr'][:,0],a)/1e3; Ppi=Ps(Bpi['x'][:,0],a)/1e3
fig,axs=plt.subplots(2,1,figsize=(3.5,2.3),sharex=True,gridspec_kw=dict(height_ratios=[2,1]))
axs[0].plot(t,Pr,'r',lw=1.1,label='$P_{s,ref}$'); axs[0].plot(t,P,'C0',lw=0.5,label='$P_s$ (FL--MPC)')
axs[0].set_ylabel('$P_s$ (kW)'); axs[0].set_ylim(0,550); axs[0].legend(fontsize=6,loc='upper right',ncol=2); fmt(axs[0])
axs[1].plot(t,P-Pr,'C0',lw=0.5)
axs[1].set_ylabel('error (kW)'); axs[1].set_ylim(-30,30); fmt(axs[1])
axs[1].set_xlabel('time (s)'); axs[1].set_xlim(0,30)
fig.tight_layout(pad=0.3,h_pad=0.2); fig.savefig('fig6.png',dpi=400)
