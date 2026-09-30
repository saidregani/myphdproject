import json, numpy as np, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.size':7.5,'font.family':'serif','axes.linewidth':0.6})
d=json.load(open('caseA.json')); zt=np.array(d['zt'])
fig,axs=plt.subplots(4,1,figsize=(3.5,3.9),gridspec_kw=dict(height_ratios=[1,1,1,1.6]))
o=d['traj']['mpc_0.0']; t=np.array(o['t']); z=np.array(o['z'])
for i in range(3):
    axs[i].plot(t,z[:,i],'C0',lw=0.7); axs[i].axhline(zt[i],color='k',lw=0.5,ls='-.')
    axs[i].axvline(6,color='gray',lw=0.5); axs[i].set_ylabel(f'$z_{i+1}$'); axs[i].set_xlim(0,10); axs[i].set_xticklabels([])
axs[2].set_xticklabels([]); 
sty={'mpc':('C0','-','FL--MPC (proposed)'),'pi':('C2','--','PI'),'fl':('C3',':','FL only')}
ax=axs[3]
for c in ['mpc','pi','fl']:
    for dl,al in [('0.2',1.0)]:
        o=d['traj'][f'{c}_{dl}']; t=np.array(o['t']); z=np.array(o['z']); m=t>=6
        ax.semilogy(t[m]-6,np.linalg.norm(z[m]-zt,axis=1),color=sty[c][0],ls=sty[c][1],lw=0.9,label=sty[c][2])
ax.set_xlim(0,3); ax.set_ylim(1e-4,100); ax.set_xlabel(r'normalized time after activation $\tilde t-\tilde t_{on}$'); ax.set_ylabel(r'$\|z-z^\ast\|$')
ax.legend(fontsize=6,loc='upper right',framealpha=0.9)
for a in axs: a.grid(alpha=0.3,lw=0.3); a.tick_params(labelsize=7,width=0.5,length=2)
axs[2].set_xlabel(r'normalized time $\tilde t$',labelpad=0); axs[2].set_xticks([0,2,4,6,8,10]); axs[2].set_xticklabels(['0','2','4','6','8','10'])
fig.subplots_adjust(left=0.15,right=0.96,top=0.99,bottom=0.09,hspace=0.12)
p=axs[3].get_position(); axs[3].set_position([p.x0,p.y0,p.width,p.height-0.02])
axs[0].text(0.01,0.93,'(a)',transform=axs[0].transAxes,va='top',fontsize=7)
axs[3].text(0.01,0.1,'(b) +20 % mismatch',transform=axs[3].transAxes,va='bottom',fontsize=7)
fig.savefig('../paper/fig4.png',dpi=400)
