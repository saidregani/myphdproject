import numpy as np, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.size':7.5,'font.family':'serif','axes.linewidth':0.6})
d=np.load('../word/traj.npy'); t=d[0]; X=d[1:]; m=t>100; Xs=X[:,m][:, ::4]
fig=plt.figure(figsize=(3.5,3.1))
ax=fig.add_subplot(2,2,1); ax.plot(Xs[0],Xs[1],'C0',lw=0.12); ax.set_xlabel(r'$x_1$ (A)',labelpad=1); ax.set_ylabel(r'$x_2$ (A)',labelpad=1); ax.set_title('(a)',fontsize=7.5,pad=2)
ax=fig.add_subplot(2,2,2); ax.plot(Xs[0],Xs[2],'C0',lw=0.12); ax.set_xlabel(r'$x_1$ (A)',labelpad=1); ax.set_ylabel(r'$x_3$ (rad/s)',labelpad=1); ax.set_title('(b)',fontsize=7.5,pad=2)
ax=fig.add_subplot(2,2,3); ax.plot(Xs[1],Xs[2],'C0',lw=0.12); ax.set_xlabel(r'$x_2$ (A)',labelpad=1); ax.set_ylabel(r'$x_3$ (rad/s)',labelpad=1); ax.set_title('(c)',fontsize=7.5,pad=2)
ax=fig.add_subplot(2,2,4,projection='3d'); ax.plot(Xs[0],Xs[1],Xs[2],'C0',lw=0.08)
ax.set_xlabel('$x_1$',labelpad=-6); ax.set_ylabel('$x_2$',labelpad=-6); ax.set_zlabel('$x_3$',labelpad=-6)
ax.tick_params(labelsize=5,pad=-2); ax.set_title('(d)',fontsize=7.5,pad=0); ax.view_init(25,-50)
for a_ in fig.axes[:3]: a_.grid(alpha=0.3,lw=0.3); a_.tick_params(labelsize=6.5,width=0.5,length=2)
fig.tight_layout(pad=0.3,h_pad=0.6,w_pad=0.6); fig.savefig('fig1.png',dpi=400)
