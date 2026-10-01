import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
plt.rcParams.update({'font.family':'serif','mathtext.fontset':'dejavuserif'})
fs=6.5
fig,ax=plt.subplots(figsize=(3.5,2.3)); ax.set_xlim(0,100); ax.set_ylim(0,66); ax.axis('off')
def box(x,y,w,h,txt,fc):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle='round,pad=0.3,rounding_size=1.5',fc=fc,ec='k',lw=0.6))
    ax.text(x+w/2,y+h/2,txt,ha='center',va='center',fontsize=fs)
def arr(p,q):
    ax.annotate('',xy=q,xytext=p,arrowprops=dict(arrowstyle='-|>',lw=0.6,mutation_scale=6,color='k'))
def line(xs,ys): ax.plot(xs,ys,'k',lw=0.6)
box(2,50,22,13,'Wind speed\n$v(t)$','#f2f2f2')
box(30,50,44,13,'MPPT + outer speed loop\n$\\omega_{r,ref}\\rightarrow i^*_{dr}$,  $i^*_{qr}=\\psi_s/L_m$','#fdf1dc')
box(19,27,40,15,'Constrained MPC\n(2 channels, horizon $N$;\n$P,K$ from LMI)','#e3f2e6')
box(65,27,33,15,'Feedback lin.\n$u_{1,2}=-\\hat F_{1,2}$\n$+\\dot x_d+v$','#e6eef9')
box(34,2,48,14,'DFIG + wind turbine\n$\\dot x=F(x,v)+[u_1,u_2,0]^T$','#f2f2f2')
arr((24,56.5),(30,56.5))
line([58,58],[50,46]); line([39,82],[46,46]); arr((39,46),(39,42)); arr((82,46),(82,42))
ax.text(60,46.8,'$i^*_{dr},\\ i^*_{qr}$',fontsize=fs)
arr((59,34.5),(65,34.5)); ax.text(62,35.5,'$v$',fontsize=fs,ha='center')
line([90,90],[27,9]); arr((90,9),(82,9)); ax.text(91.5,17,'$u_{dr},u_{qr}$',fontsize=fs)
line([34,6],[9,9]); line([6,6],[9,34.5]); arr((6,34.5),(19,34.5))
line([6,74],[22,22]); arr((74,22),(74,27)); line([6,6],[34.5,46]); line([6,34],[46,46]); arr((34,46),(34,50))
ax.text(8,23,'$x=[i_{dr},i_{qr},\\omega_r]^T$',fontsize=fs)
fig.savefig('../paper/fig3.png',dpi=400,bbox_inches='tight',pad_inches=0.02)
