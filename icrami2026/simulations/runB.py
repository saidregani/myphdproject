import sys, pickle, caseB as B
c, sc = sys.argv[1], sys.argv[2]
SC={'nom':None,'m1':dict(Rs=1.2,Rr=1.2,Lm=0.9,J=1.2),'m2':dict(Rs=0.8,Rr=0.8,Lm=1.1,J=0.8)}
o=B.run(c,SC[sc],T=30.0)
m=B.metrics(o); print(c,sc,m,flush=True)
pickle.dump(dict(o=o,m=m),open(f'B_{c}_{sc}.pkl','wb'))
