import numpy as np, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.size':8,'font.family':'serif'})
d=np.load('traj.npy'); t=d[0]; X=d[1:]
m=t>100; Xs=X[:,m][:, ::5]
fig=plt.figure(figsize=(7,5.2))
ax=fig.add_subplot(2,2,1); ax.plot(Xs[0],Xs[1],lw=0.15); ax.set_xlabel(r'$x_1=i_{dr}$ (A)'); ax.set_ylabel(r'$x_2=i_{qr}$ (A)'); ax.set_title('(a)')
ax=fig.add_subplot(2,2,2); ax.plot(Xs[0],Xs[2],lw=0.15); ax.set_xlabel(r'$x_1=i_{dr}$ (A)'); ax.set_ylabel(r'$x_3=\omega_r$ (rad/s)'); ax.set_title('(b)')
ax=fig.add_subplot(2,2,3); ax.plot(Xs[1],Xs[2],lw=0.15); ax.set_xlabel(r'$x_2=i_{qr}$ (A)'); ax.set_ylabel(r'$x_3=\omega_r$ (rad/s)'); ax.set_title('(c)')
ax=fig.add_subplot(2,2,4,projection='3d'); ax.plot(Xs[0],Xs[1],Xs[2],lw=0.1); ax.set_xlabel('$x_1$'); ax.set_ylabel('$x_2$'); ax.set_zlabel('$x_3$'); ax.set_title('(d)')
for a_ in fig.axes[:3]: a_.grid(alpha=0.3)
fig.tight_layout(); fig.savefig('eq10_attractor.png',dpi=300)
fig,axs=plt.subplots(3,1,figsize=(7,5),sharex=True)
lab=[r'$i_{dr}$ (A)',r'$i_{qr}$ (A)',r'$\omega_r$ (rad/s)']
for i in range(3): axs[i].plot(t,X[i],lw=0.4); axs[i].set_ylabel(lab[i]); axs[i].grid(alpha=0.3)
axs[2].axhline(100*np.pi,color='r',ls='--',lw=0.7,label=r'$\omega_s=100\pi$'); axs[2].legend(loc='lower right')
axs[2].set_xlabel('time (s)'); axs[2].set_xlim(0,300)
fig.tight_layout(); fig.savefig('eq10_time.png',dpi=300)
