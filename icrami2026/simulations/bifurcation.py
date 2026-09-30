# Bifurcation diagram and largest Lyapunov exponent vs eps2 for the dimensionless DFIG model
import numpy as np, json
g,s,e1,e3=-1.0,8.0,0.0,0.0
E2=np.linspace(-100,0,401)
M=len(E2)
def F(x):
    z1,z2,y=x
    return np.array([-z1-y*z2+g*y+e1, -z2+y*z1+E2, s*z1-s*y+e3])
def JV(x,v):
    z1,z2,y=x; a,b,c=v
    return np.array([-a-y*b+(-z2+g)*c, y*a-b+z1*c, s*a-s*c])
x=np.tile(np.array([[0.3],[0.6],[1.0]]),(1,M)); v=np.ones((3,M))/np.sqrt(3)
dt=0.001; ntr=int(150/dt); n=int(300/dt); L=np.zeros(M)
pts=[[] for _ in range(M)]; yprev2=None; yprev=None
for k in range(ntr+n):
    G=lambda x,v:(F(x),JV(x,v))
    k1=G(x,v);k2=G(x+dt/2*k1[0],v+dt/2*k1[1]);k3=G(x+dt/2*k2[0],v+dt/2*k2[1]);k4=G(x+dt*k3[0],v+dt*k3[1])
    x=x+dt/6*(k1[0]+2*k2[0]+2*k3[0]+k4[0]); v=v+dt/6*(k1[1]+2*k2[1]+2*k3[1]+k4[1])
    if k%20==0:
        nv=np.linalg.norm(v,axis=0)
        if k>=ntr: L+=np.log(nv)
        v/=nv
    if k>=ntr:
        if yprev2 is not None:
            m=(yprev>yprev2)&(yprev>=x[2])
            for i in np.where(m)[0]:
                if len(pts[i])<300: pts[i].append(float(yprev[i]))
        yprev2=yprev; yprev=x[2].copy()
L/=n*dt
json.dump({'E2':E2.tolist(),'L':L.tolist(),'pts':pts},open('bif.json','w'))
print('done', L.max(), L.min())
