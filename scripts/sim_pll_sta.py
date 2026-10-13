import numpy as np, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
k1,k2,L=30.,150.,2*np.pi*10
gm=np.sqrt(2/np.pi)
f=lambda g:((1-g)**2*k1**4+8*L*g*k1**2+16*L**2)/(8*k1**2*(2*g-1))
gs=np.linspace(gm,1,200); print('k2 min =',f(gs).max(), 'at gamma', gs[f(gs).argmax()])
P=0.5*np.array([[4*k2+k1**2,-k1],[-k1,2]])
lq=min(np.linalg.eigvalsh(np.array([[k1*(2*d+g*k1**2+4*g*k2-2*k2)/2,-(4*d+g*k1**2+k1**2)/4],[-(4*d+g*k1**2+k1**2)/4,k1/2]]))[0] for g in (gm,1) for d in (-L,L))
lp=np.linalg.eigvalsh(P); kap=lq*np.sqrt(lp[0])/lp[1]
print('lamQ',lq,'lamP',lp,'kappa',kap,'c_max',(8*k2+k1**2)*np.pi/8)
# simulation
dt=1e-5; T=1.0; n=int(T/dt); t=np.arange(n)*dt
w0=2*np.pi*50; wff=w0
w=w0+2*np.pi*2*(t>0.3)+2*np.pi*5*(t-0.6)*(t>0.6)  # step 2 Hz at 0.3 s, ramp 5 Hz/s from 0.6 s
th=0.; thh=-1.0; z=0.; Vm=1.
psi=np.zeros(n); wh=np.zeros(n)
for i in range(n):
    th+=w[i]*dt
    va=Vm*np.cos(th); vb=Vm*np.cos(th-2*np.pi/3); vc=Vm*np.cos(th+2*np.pi/3)
    al=2/3*(va-0.5*vb-0.5*vc); be=2/3*(np.sqrt(3)/2*(vb-vc))
    e=(-al*np.sin(thh)+be*np.cos(thh))/np.hypot(al,be)
    W=k1*np.sqrt(abs(e))*np.sign(e)+z+wff
    z+=k2*np.sign(e)*dt; thh+=W*dt
    psi[i]=np.angle(np.exp(1j*(th-thh))); wh[i]=W
V0=0.5*(4*k2+k1**2)*1.0
print('V0',V0,'T bound',2*np.sqrt(V0)/kap)
i=np.argmax(np.abs(psi)<1e-3); print('t conv',t[i])
for a,b in [(0.29,0.3),(0.55,0.6),(0.95,1.0)]:
    m=(t>a)&(t<b); print(a,b,'max|psi|',np.abs(psi[m]).max(),'max|w-wh|/2pi',np.abs(w[m]-wh[m]).max()/2/np.pi)
fig,ax=plt.subplots(2,1,figsize=(7,4.5),sharex=True)
ax[0].plot(t,psi,lw=.8); ax[0].set_ylabel(r'$\psi=\theta-\hat\theta$ (rad)'); ax[0].grid(alpha=.3)
ax[1].plot(t,w/2/np.pi,'k--',lw=1,label=r'$\omega/2\pi$'); ax[1].plot(t,wh/2/np.pi,lw=.6,alpha=.8,label=r'$\hat\omega/2\pi$')
ax[1].set_ylim(45,56); ax[1].set_ylabel('Fréquence (Hz)'); ax[1].set_xlabel('t (s)'); ax[1].legend(loc='lower right'); ax[1].grid(alpha=.3)
fig.tight_layout(); fig.savefig('figures/sim_pll_sta.pdf')
