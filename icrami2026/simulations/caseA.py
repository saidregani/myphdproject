"""Case A: chaos suppression in the dimensionless DFIG model (control switched on at t_on)."""
import numpy as np, json, sys
from ctrl import MPC
g0,s0,e0=-1.0,8.0,np.array([0.0,-85.0,0.0])
tau=0.0321; ws=2*np.pi*50
z3s=0.2*ws*tau                                  # 20 % super-synchronous
zt=np.array([z3s, (-z3s+g0*z3s+e0[0])/z3s, z3s])  # admissible target: u1*=u3*=0 at nominal
U=120.0
def F(z,g,s,e,c=1.0):
    z1,z2,y=z
    return np.array([-c*z1-y*z2+g*y+e[0], -c*z2+y*z1+e[1], s*z1-s*y+e[2]])
def run(ctrl, dlt=0.0, T=16.0, t_on=6.0, Ts=0.01, sub=5, prm=None):
    prm=prm or {}
    # plant parameters perturbed by factor (1+dlt); controller uses nominal
    gp,sp,ep,cp_=g0*(1+dlt), s0*(1+dlt), e0*(1+dlt), 1.0*(1+dlt)
    z=np.array([0.3,0.6,1.0]); n=int(T/Ts); h=Ts/sub
    mpc=MPC(Ts,prm.get('N',15),np.diag([1.0,prm.get('qI',10.0)]),prm.get('r',1e-4))
    # identical LMI gain K=[k_e,k_i] used by all controllers (fair ablation)
    Kc=-mpc.K[0,0]; Kp,Ki=-mpc.K[0,0],-mpc.K[0,1]; I=np.zeros(3)
    out={'t':[], 'z':[], 'u':[]}
    for k in range(n):
        t=k*Ts
        if t<t_on: u=np.zeros(3)
        else:
            e=z-zt; ff=-F(z,g0,s0,e0)          # xd_dot = 0
            if ctrl=='mpc':
                v=np.array([mpc.solve(np.array([e[i],I[i]]), -U-ff[i], U-ff[i]) for i in range(3)]); u=ff+v
                I+=np.where(np.abs(u)<U-1e-9, e*Ts, 0)   # conditional integration (anti-windup)
            elif ctrl=='fl':
                u=np.clip(ff-Kc*e,-U,U)
            elif ctrl=='pi':
                ucmd=-Kp*e-Ki*I; u=np.clip(ucmd,-U,U)
                I+=np.where(ucmd==u, e*Ts, 0)   # clamping anti-windup
        for j in range(sub):
            f=lambda zz: F(zz,gp,sp,ep,cp_)+u
            k1=f(z);k2=f(z+h/2*k1);k3=f(z+h/2*k2);k4=f(z+h*k3); z=z+h/6*(k1+2*k2+2*k3+k4)
        out['t'].append(t+Ts); out['z'].append(z.tolist()); out['u'].append(u.tolist())
        if not np.all(np.isfinite(z)) or np.abs(z).max()>1e6: break
    return out
def metrics(o, t_on=6.0):
    t=np.array(o['t']); z=np.array(o['z']); u=np.array(o['u'])
    m=t>=t_on; e=np.linalg.norm(z[m]-zt,axis=1); tt=t[m]
    dt=tt[1]-tt[0]; iae=float(np.sum(e)*dt)
    band=0.02*np.linalg.norm(zt); out=np.where(e>band)[0]
    ts=float(tt[out[-1]]-t_on) if len(out) else 0.0
    if len(out) and out[-1]==len(e)-1: ts=float('nan')
    return dict(IAE=iae, ts=ts, umax=float(np.abs(u[m]).max()), urms=float(np.sqrt((u[m]**2).mean())), efinal=float(e[-1]))
if __name__=='__main__':
    res={}; traj={}
    for d in [0.0,-0.2,0.2]:
        for c in ['mpc','fl','pi']:
            o=run(c,d); res[f'{c}_{d}']=metrics(o); print(c,d,res[f'{c}_{d}'],flush=True)
            traj[f'{c}_{d}']=o
    json.dump({'res':res,'traj':traj,'zt':zt.tolist()},open('caseA.json','w'))
