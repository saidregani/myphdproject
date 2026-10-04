import numpy as np, matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.integrate import solve_ivp
from scipy.optimize import fsolve
from coef import a, ws
def f(t,x):
    x1,x2,x3=x
    return [a['a1']*x1+(ws-x3)*x2+a['a2']*x3+a['c1'],
            -(ws-x3)*x1+a['a1']*x2+a['c2'],
            a['a6']*x1-a['a7']*x3-a['a8']]
def jac(x):
    x1,x2,x3=x
    return np.array([[a['a1'],ws-x3,-x2+a['a2']],[-(ws-x3),a['a1'],x1],[a['a6'],0,-a['a7']]])
x0=[0.3,0.6,3.6]; T=300
sol=solve_ivp(f,(0,T),x0,method='LSODA',rtol=1e-9,atol=1e-9,max_step=1e-3,dense_output=False)
t,X=sol.t,sol.y
print('final state',X[:,-1]); print('ranges (t>100):',X[:,t>100].min(1),X[:,t>100].max(1))
# equilibria
for g in [X[:,-1],[0,0,ws],[1e3,1e3,300],[-1e3,-1e3,-300]]:
    e,info,ier,msg=fsolve(lambda x:f(0,x),g,full_output=1)
    if ier==1: print('equilibrium',e,'eig',np.round(np.linalg.eigvals(jac(e)),4))
# Lyapunov spectrum (QR) on t in [100, 400]
x=X[:,-1].copy(); Q=np.eye(3); S=np.zeros(3); dt=0.05; n=int(200/dt)
G=lambda t,z: np.concatenate([f(t,z[:3]),(jac(z[:3])@z[3:].reshape(3,3)).ravel()])
for k in range(n):
    z=solve_ivp(G,(0,dt),np.concatenate([x,Q.ravel()]),method='LSODA',rtol=1e-9,atol=1e-9,max_step=1e-3).y[:,-1]
    x=z[:3]; Q,R=np.linalg.qr(z[3:].reshape(3,3)); S+=np.log(abs(np.diag(R)))
L=S/(n*dt); print('Lyapunov exponents',L,'sum',L.sum(),'trace',2*a['a1']-a['a7'])
np.save('traj.npy',np.vstack([t,X]))
