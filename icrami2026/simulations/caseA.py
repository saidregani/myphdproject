"""Case A: chaos suppression in the dimensionless DFIG model, control on u1, u2 only.
Cascade: outer loop on z3 (slip speed) generates the reference of z1 (torque current);
inner loops (FL-MPC / FL only / PI) act on u1 and u2 (rotor voltages)."""
import numpy as np, json
from ctrl import MPC
g0,s0,e0=-1.0,8.0,np.array([0.0,-85.0,0.0])
tau=0.0321; ws=2*np.pi*50
z3s=0.2*ws*tau                                  # 20 % super-synchronous
zt=np.array([z3s, (-z3s+g0*z3s+e0[0])/z3s, z3s])  # admissible target: u1*=0, sustained by u2 only
U=120.0
LAM,LAMI=10.0,25.0                              # outer speed loop gains (poles -5, -5)
def F(z,g,s,e,c=1.0):
    z1,z2,y=z
    return np.array([-c*z1-y*z2+g*y+e[0], -c*z2+y*z1+e[1], s*z1-s*y+e[2]])
def run(ctrl, dlt=0.0, T=16.0, t_on=6.0, Ts=0.01, sub=5, prm=None):
    prm=prm or {}
    gp,sp,ep,cp_=g0*(1+dlt), s0*(1+dlt), e0*(1+dlt), 1.0*(1+dlt)
    z=np.array([0.3,0.6,1.0]); n=int(T/Ts); h=Ts/sub
    mpc=MPC(Ts,prm.get('N',15),np.diag([1.0,prm.get('qI',10.0)]),prm.get('r',1e-4))
    ke,ki=-mpc.K[0,0],-mpc.K[0,1]
    I=np.zeros(2); I3=0.0
    out={'t':[], 'z':[], 'u':[]}
    for k in range(n):
        t=k*Ts
        if t<t_on: u=np.zeros(2)
        else:
            e3=z[2]-zt[2]
            Fn=F(z,g0,s0,e0)
            if ctrl=='pi':                      # model-free cascade PI
                z1d=zt[0]-(LAM*e3+LAMI*I3)/s0; dz1d=0.0
            else:                               # outer loop with model: z3' = -LAM e3 - LAMI I3 when z1 = z1d
                z1d=z[2]-e0[2]/s0-(LAM*e3+LAMI*I3)/s0
                dz3=Fn[2]
                dz1d=dz3-(LAM*dz3+LAMI*e3)/s0
            e=np.array([z[0]-z1d, z[1]-zt[1]])
            ff=np.array([-Fn[0]+dz1d, -Fn[1]])
            if ctrl=='mpc':
                v=np.array([mpc.solve(np.array([e[i],I[i]]), -U-ff[i], U-ff[i]) for i in range(2)]); u=ff+v
                I+=np.where(np.abs(u)<U-1e-9, e*Ts, 0)
            elif ctrl=='fl':
                u=np.clip(ff-ke*e,-U,U)
            elif ctrl=='pi':
                ucmd=-ke*e-ki*I; u=np.clip(ucmd,-U,U)
                I+=np.where(ucmd==u, e*Ts, 0)
            I3+=e3*Ts
        uu=np.array([u[0],u[1],0.0])            # no actuator on the speed equation
        for j in range(sub):
            f=lambda zz: F(zz,gp,sp,ep,cp_)+uu
            k1=f(z);k2=f(z+h/2*k1);k3=f(z+h/2*k2);k4=f(z+h*k3); z=z+h/6*(k1+2*k2+2*k3+k4)
        out['t'].append(t+Ts); out['z'].append(z.tolist()); out['u'].append(uu.tolist())
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
