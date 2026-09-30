"""Case B: MPPT reference tracking of a 2-MW-class DFIG (physical units) under turbulent wind."""
import numpy as np, json
from ctrl import MPC
NOM=dict(Rs=2.6e-3,Rr=2.9e-3,Lm=2.5e-3,Ls=2.587e-3,Lr=2.587e-3,np=2,J=127.0,D=1e-3,Vll=690.0,fs=50.0)
rho,R,G,lopt=1.225,40.0,80.0,8.1
def Cp(lam):
    li=1/(1/lam-0.035); return np.maximum(0.5176*(116/li-5)*np.exp(-21/li)+0.0068*lam,0)
Cpmax=float(Cp(np.array(lopt)))
def co(p):
    ws=2*np.pi*p['fs']; psi=np.sqrt(2)*p['Vll']/np.sqrt(3)/ws
    sig=1-p['Lm']**2/(p['Ls']*p['Lr'])
    a=dict(ws=ws,psi=psi,sig=sig,
      a1=-p['Rs']*p['Lm']**2/(sig*p['Ls']**2*p['Lr'])-p['Rr']/(sig*p['Lr']),
      a2=-p['Lm']*psi/(sig*p['Lr']*p['Ls']), a3=-p['Lm']/(sig*p['Ls']*p['Lr']), a4=1/(sig*p['Lr']),
      a5=p['Rs']*p['Lm']*psi/(sig*p['Ls']**2*p['Lr']), a6=3*p['np']**2*p['Lm']*psi/(2*p['J']*p['Ls']),
      a7=p['D']/p['J'], np=p['np'], J=p['J'], Lm=p['Lm'], Ls=p['Ls'])
    a['uds']=-ws*psi; a['uqs']=0.0
    a['c1']=a['a3']*a['uds']; a['c2']=a['a5']+a['a3']*a['uqs']      # u_dr, u_qr supplied by controller
    return a
def Ta(v,x3,a):   # aerodynamic torque referred to generator shaft
    Wm=np.maximum(x3,1.0)/a['np']; lam=R*Wm/(G*np.maximum(v,0.5))
    return 0.5*rho*np.pi*R**2*Cp(np.clip(lam,2,13))*v**3/Wm
def F(x,a,v):
    x1,x2,x3=x; ws=a['ws']
    a8=-a['np']*Ta(v,x3,a)/a['J']
    return np.array([a['a1']*x1+(ws-x3)*x2+a['a2']*x3+a['c1'],
                     -(ws-x3)*x1+a['a1']*x2+a['c2'],
                     a['a6']*x1-a['a7']*x3-a8])
def wind(T,dt,seed=3):
    t=np.arange(0,T+dt,dt); rng=np.random.default_rng(seed)
    w=rng.normal(0,1,len(t)); turb=np.zeros_like(t); tf=0.5
    for k in range(1,len(t)): turb[k]=turb[k-1]+dt/tf*(-turb[k-1]+0.9*np.sqrt(2*tf/dt)*w[k])
    v=9.0+1.3*np.sin(2*np.pi*0.05*t)+0.7*np.sin(2*np.pi*0.13*t+1.0)+0.4*np.sin(2*np.pi*0.31*t+2.0)+turb
    return t,v
def lowpass(x,dt,tf):
    y=np.zeros_like(x); y[0]=x[0]
    for k in range(1,len(x)): y[k]=y[k-1]+dt/tf*(x[k]-y[k-1])
    return y
def refs(t,v,a):
    dt=t[1]-t[0]; vf=lowpass(v,dt,2.0)
    x3r=a['np']*G*lopt*vf/R; dx3r=np.gradient(x3r,dt)
    a8=-a['np']*Ta(v,x3r,a)/a['J']
    x1r=(dx3r+a['a7']*x3r+a8)/a['a6']; x2r=np.full_like(t,a['psi']/a['Lm'])
    xr=np.vstack([x1r,x2r,x3r]).T
    return xr, np.gradient(xr,dt,axis=0)
def run(ctrl, pert=None, T=40.0, Ts=1e-3, sub=4, prm=None, noise=0.0):
    prm=prm or {}
    an=co(NOM); p=dict(NOM); 
    for k,f in (pert or {}).items():
        if k=='Lm':   # scale magnetising inductance, keep leakage inductances -> Ls,Lr > Lm preserved
            lls,llr=p['Ls']-p['Lm'],p['Lr']-p['Lm']; p['Lm']*=f; p['Ls']=p['Lm']+lls; p['Lr']=p['Lm']+llr
        else: p[k]*=f
    ap=co(p)
    t,v=wind(T,Ts); xr,dxr=refs(t,v,an)
    Umax=np.array([200*an['a4'],200*an['a4'],2000*an['np']/an['J']])   # |u_dr|,|u_qr|<=200 V ; |dT|<=2 kN m
    sc=np.array([1e3,1e3,prm.get('sc3',100.)])     # error scaling for MPC/PI (A, A, rad/s)
    mpc=MPC(Ts,prm.get('N',10),np.diag([1.0,prm.get('qI',3.0)]),prm.get('r',1e-6))
    # identical LMI gain K=[k_e,k_i] used by all controllers (fair ablation)
    Kc=-mpc.K[0,0]; Kp,Ki=-mpc.K[0,0],-mpc.K[0,1]
    x=np.array([0.0,0.0,0.9*xr[0,2]]); I=np.zeros(3); h=Ts/sub
    X=[];Ulog=[]; rng=np.random.default_rng(1)
    for k in range(len(t)-1):
        xm=x*(1+noise*rng.normal(0,1,3))
        e=xm-xr[k]
        ff=-F(xm,an,v[k])+dxr[k]
        if ctrl=='mpc':
            vv=np.array([mpc.solve(np.array([e[i],I[i]])/sc[i], (-Umax[i]-ff[i])/sc[i], (Umax[i]-ff[i])/sc[i])*sc[i] for i in range(3)])
            u=np.clip(ff+vv,-Umax,Umax); I+=np.where(np.abs(u)<Umax-1e-9, e/sc*Ts, 0)   # conditional integration
        elif ctrl=='fl':
            u=np.clip(ff-Kc*e,-Umax,Umax)
        elif ctrl=='pi':
            ucmd=np.asarray(Kp)*(-e)-np.asarray(Ki)*I
            u=np.clip(ucmd,-Umax,Umax); I+=np.where(ucmd==u,e*Ts,0)
        for j in range(sub):
            vj=v[k]
            f=lambda xx: F(xx,ap,vj)+u
            k1=f(x);k2=f(x+h/2*k1);k3=f(x+h/2*k2);k4=f(x+h*k3); x=x+h/6*(k1+2*k2+2*k3+k4)
        X.append(x.copy()); Ulog.append(u.copy())
        if not np.all(np.isfinite(x)): break
    X=np.array(X); Ulog=np.array(Ulog); n=len(X)
    return dict(t=t[1:n+1],x=X,xr=xr[1:n+1],u=Ulog,v=v[1:n+1],a=an,Umax=Umax)
def Ps(x1,a): return -1.5*a['ws']*a['psi']*a['Lm']/a['Ls']*x1
def metrics(o,t0=5.0):
    m=o['t']>=t0; e=o['x'][m]-o['xr'][m]; a=o['a']
    rm=np.sqrt((e**2).mean(0)); P=Ps(o['x'][m,0],a); Pr=Ps(o['xr'][m,0],a)
    return dict(rmse_idr=float(rm[0]), rmse_iqr=float(rm[1]), rmse_w=float(rm[2]),
                rmse_P_pct=float(100*np.sqrt(((P-Pr)**2).mean())/2e6),
                urmax=float(np.abs(o['u'][:,:2]).max()/a['a4']), dTmax=float(np.abs(o['u'][:,2]).max()*a['J']/a['np']),
                dTrms=float(np.sqrt((o['u'][m,2]**2).mean())*a['J']/a['np']))
if __name__=='__main__':
    a=co(NOM); print({k:a[k] for k in ['sig','a1','a2','a3','a4','a5','a6','a7','psi']}, 'tau',-1/a['a1'],'Cpmax',Cpmax)
    for c in ['mpc','fl','pi']:
        o=run(c,T=20.0); print(c,metrics(o),flush=True)
