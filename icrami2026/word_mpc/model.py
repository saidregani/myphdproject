"""DFIG model of Eq. (10)/(18) with the parameter set of Table I (Word file)."""
import numpy as np
P0=dict(Rs=5.0536e-5,Rr=1.8781e-4,Ls=0.0833,Lr=0.0844,Lm=0.0811,ws=100*np.pi,psi=1.7933,np=2,
        J=31.18,D=71.85,TL=-11337.0,udr0=2.539,uqr0=-2.936)
# turbine (MPPT case, normal operation)
TURB=dict(rho=1.225,R=20.0,G=86.0,lopt=8.1,Dn=0.1)     # G includes the pole pairs: w_r = G*lambda*v/R
def coef(p):
    sig=1-p['Lm']**2/(p['Ls']*p['Lr']); ws=p['ws']; psi=p['psi']
    a=dict(sig=sig,ws=ws,psi=psi,np=p['np'],J=p['J'],Lm=p['Lm'],Ls=p['Ls'],
      a1=-p['Rs']*p['Lm']**2/(sig*p['Ls']**2*p['Lr'])-p['Rr']/(sig*p['Lr']),
      a2=-p['Lm']*psi/(sig*p['Lr']*p['Ls']), a3=-p['Lm']/(sig*p['Ls']*p['Lr']), a4=1/(sig*p['Lr']),
      a5=p['Rs']*p['Lm']*psi/(sig*p['Ls']**2*p['Lr']), a6=3*p['np']**2*p['Lm']*psi/(2*p['J']*p['Ls']),
      a7=p['D']/p['J'])
    a['uds']=-ws*psi; a['uqs']=0.0
    a['k1']=a['a3']*a['uds']; a['k2']=a['a5']+a['a3']*a['uqs']     # constant terms without u1,u2
    return a
def perturb(p,f):
    """f = (fR, fLm, fJ): Rs,Rr *fR ; Lm *fLm with constant leakage ; J *fJ"""
    q=dict(p); lls,llr=q['Ls']-q['Lm'],q['Lr']-q['Lm']
    q['Rs']*=f[0]; q['Rr']*=f[0]; q['Lm']*=f[1]; q['Ls']=q['Lm']+lls; q['Lr']=q['Lm']+llr; q['J']*=f[2]
    return q
def F(x,a,a8):
    """drift of (18) without the control terms a4*u1, a4*u2"""
    x1,x2,x3=x; ws=a['ws']
    return np.array([a['a1']*x1+(ws-x3)*x2+a['a2']*x3+a['k1'],
                     -(ws-x3)*x1+a['a1']*x2+a['k2'],
                     a['a6']*x1-a['a7']*x3-a8])
def Cp(lam):
    li=1/(1/lam-0.035); return np.maximum(0.5176*(116/li-5)*np.exp(-21/li)+0.0068*lam,0)
def Ta(v,x3,a):
    """aerodynamic torque on the generator shaft"""
    T=TURB; Wm=np.maximum(x3,1.0)/a['np']; lam=T['R']*x3/(T['G']*np.maximum(v,0.5))
    lam=np.clip(lam,2,13)
    return 0.5*T['rho']*np.pi*T['R']**2*Cp(lam)*v**3/Wm
def Ps(x1,a):   # generated stator active power
    return -1.5*a['ws']*a['psi']*a['Lm']/a['Ls']*x1
