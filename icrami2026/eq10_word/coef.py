import numpy as np
Rs=5.0536e-5; Rr=1.8781e-4; Ls=0.0833; Lr=0.0844; Lm=0.0811
ws=100*np.pi; psi=1.7933; npp=2; J=31.18; D=71.85; TL=-11337.0; udr=2.539; uqr=-2.936
uds=-ws*psi; uqs=0.0          # stator flux on q axis, Rs neglected in the flux relation
sig=1-Lm**2/(Ls*Lr)
a=dict(sig=sig,
 a1=-Rs*Lm**2/(sig*Ls**2*Lr)-Rr/(sig*Lr), a2=-Lm*psi/(sig*Lr*Ls), a3=-Lm/(sig*Ls*Lr),
 a4=1/(sig*Lr), a5=Rs*Lm*psi/(sig*Ls**2*Lr), a6=3*npp**2*Lm*psi/(2*J*Ls), a7=D/J, a8=npp*TL/J)
a['c1']=a['a3']*uds+a['a4']*udr; a['c2']=a['a5']+a['a3']*uqs+a['a4']*uqr
if __name__=='__main__':
    for k,v in a.items(): print(f'{k:4s} = {v: .6g}')
    tau=-1/a['a1']; print('tau',tau,' c1+a2*ws',a['c1']+a['a2']*ws)
    k=a['a7']/(tau*a['a6'])
    print('gamma',a['a2']/k,'s',tau*a['a7'],'eps1',tau*(a['c1']+a['a2']*ws)/k,'eps2',tau*a['c2']/k,'eps3',-tau**2*(a['a7']*ws+a['a8']))
