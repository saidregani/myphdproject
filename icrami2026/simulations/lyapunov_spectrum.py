import numpy as np
from scipy.integrate import solve_ivp
def f(t,x,g,s,e):
    z1,z2,y=x
    return [-z1-y*z2+g*y+e[0], -z2+y*z1+e[1], s*z1-s*y+e[2]]
def jac(x,g,s):
    z1,z2,y=x
    return np.array([[-1,-y,-z2+g],[y,-1,z1],[s,0,-s]])
def spectrum(g,s,e,T=500,dt=0.1):
    x=solve_ivp(f,(0,200),[0.3,0.6,1.0],args=(g,s,e),rtol=1e-9,atol=1e-9).y[:,-1]
    Q=np.eye(3); S=np.zeros(3)
    G=lambda t,z: np.concatenate([f(t,z[:3],g,s,e),(jac(z[:3],g,s)@z[3:].reshape(3,3)).ravel()])
    for k in range(int(T/dt)):
        z=solve_ivp(G,(0,dt),np.concatenate([x,Q.ravel()]),rtol=1e-9,atol=1e-9).y[:,-1]
        x=z[:3]; Q,R=np.linalg.qr(z[3:].reshape(3,3)); S+=np.log(np.abs(np.diag(R)))
    return S/T
for (g,s,e) in [(-1,8,(-4,-88,5)),(-1,8,(-4,-80,5)),(-1,8,(0,-85,0)),(-1,10,(0,-85,0))]:
    L=spectrum(g,s,e); print(g,s,e,L.round(4),'sum',L.sum().round(3),'trace',-2-s)
