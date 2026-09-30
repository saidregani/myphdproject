import numpy as np, json, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.integrate import solve_ivp
plt.rcParams.update({'font.size':8,'font.family':'serif','axes.linewidth':0.6,'lines.linewidth':0.5})
g,s,e=-1.0,8.0,(0.0,-85.0,0.0)
f=lambda t,x:[-x[0]-x[2]*x[1]+g*x[2]+e[0], -x[1]+x[2]*x[0]+e[1], s*x[0]-s*x[2]+e[2]]
sol=solve_ivp(f,(0,300),[0.3,0.6,1.0],rtol=1e-9,atol=1e-9,max_step=0.002,dense_output=False)
m=sol.t>100; z=sol.y[:,m]
d=json.load(open('bif.json')); E=np.array(d['E2']); L=np.array(d['L'])
fig=plt.figure(figsize=(3.5,3.0))
ax=fig.add_subplot(2,2,1); ax.plot(z[0],z[1],'C0',lw=0.2); ax.set_xlabel(r'$z_1$'); ax.set_ylabel(r'$z_2$'); ax.set_title('(a)',fontsize=8)
ax=fig.add_subplot(2,2,2); ax.plot(z[0],z[2],'C0',lw=0.2); ax.set_xlabel(r'$z_1$'); ax.set_ylabel(r'$z_3$'); ax.set_title('(b)',fontsize=8)
ax=fig.add_subplot(2,2,3)
for Ei,p in zip(E,d['pts']):
    if len(p): ax.plot([Ei]*len(p),p,',',color='k',ms=0.3,alpha=0.5)
ax.set_xlabel(r'$\varepsilon_2$'); ax.set_ylabel(r'local maxima of $z_3$'); ax.set_title('(c)',fontsize=8); ax.set_xlim(-100,0)
ax=fig.add_subplot(2,2,4); ax.plot(E,L,'C3',lw=0.8); ax.axhline(0,color='k',lw=0.4,ls='--')
ax.set_xlabel(r'$\varepsilon_2$'); ax.set_ylabel(r'$\lambda_{\max}$'); ax.set_title('(d)',fontsize=8); ax.set_xlim(-100,0)
for a in fig.axes: a.grid(alpha=0.3,lw=0.3); a.tick_params(labelsize=7,width=0.5,length=2)
fig.tight_layout(pad=0.3,h_pad=0.4,w_pad=0.4); fig.savefig('../paper/fig1.png',dpi=400)
print('zrange',z.min(1),z.max(1))
