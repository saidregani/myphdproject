"""Chaos suppression (case A) and MPPT tracking (case B) with u1 = u_dr, u2 = u_qr only."""
import numpy as np, json, sys, pickle
from model import P0, TURB, coef, perturb, F, Ta, Ps
from ctrl import MPC
LAM, LAMI = 10.0, 25.0          # outer speed loop
UMAX = 200.0                    # |u_dr|, |u_qr| <= 200 V
TS = 1e-3; SUB = 4
MPCW = dict(N=10, Q=np.diag([1.0, 3.0]), r=1e-6)
SC = 100.0                      # current scaling for the QP (A)
MISM = {'nom': (1, 1, 1), 'M1': (1.2, 0.9, 1.2), 'M2': (0.8, 1.1, 0.8)}

def dTa_dt(v, x3, a, dv, dx3):
    hx = 1e-3*max(abs(x3), 1.0); hv = 1e-4*max(abs(v), 1.0)
    return ((Ta(v, x3+hx, a)-Ta(v, x3-hx, a))/(2*hx))*dx3 + ((Ta(v+hv, x3, a)-Ta(v-hv, x3, a))/(2*hv))*dv

def controller(ctrl, x, a, a8, da8, wref, dwref, ddwref, iqref, diqref, st, mpc, ke, ki):
    """returns u = [u_dr, u_qr] (V) and the inner reference i_dr*"""
    e3 = x[2]-wref
    Fn = F(x, a, a8)
    if ctrl == 'pi':
        idr = -(LAM*e3 + LAMI*st['I3'])/a['a6']; didr = 0.0
    else:
        # feed-forward on the reference (keeps the natural damping a7): e3' = -(LAM+a7) e3 - LAMI I3
        idr = (dwref + a['a7']*wref + a8 - LAM*e3 - LAMI*st['I3'])/a['a6']
        didr = (ddwref + a['a7']*dwref + da8 - LAM*(Fn[2]-dwref) - LAMI*e3)/a['a6']
    e = np.array([x[0]-idr, x[1]-iqref])
    h = np.array([-Fn[0]+didr, -Fn[1]+diqref])          # u = (h + v)/a4
    A4 = a['a4']; lim = A4*UMAX
    if ctrl == 'mpc':
        v = np.array([SC*mpc.solve(np.array([e[i], st['I'][i]])/SC, (-lim-h[i])/SC, (lim-h[i])/SC) for i in range(2)])
        u = np.clip((h+v)/A4, -UMAX, UMAX)
        st['I'] += np.where(np.abs(u) < UMAX-1e-9, e/SC*TS, 0)
    elif ctrl == 'fl':
        u = np.clip((h-ke*e)/A4, -UMAX, UMAX)
    else:
        ucmd = (-ke*e - ki*st['I'])/A4
        u = np.clip(ucmd, -UMAX, UMAX)
        st['I'] += np.where(ucmd == u, e*TS, 0)
    st['I3'] += e3*TS
    return u, idr

def step(x, ap, a8p, u):
    h = TS/SUB; A4 = ap['a4']
    f = lambda xx: F(xx, ap, a8p) + np.array([A4*u[0], A4*u[1], 0.0])
    for _ in range(SUB):
        k1 = f(x); k2 = f(x+h/2*k1); k3 = f(x+h/2*k2); k4 = f(x+h*k3); x = x+h/6*(k1+2*k2+2*k3+k4)
    return x

def caseA(ctrl, mism='nom', T=16.0, t_on=10.0):
    an = coef(P0); pp = perturb(P0, MISM[mism]); ap = coef(pp)
    a8n = an['np']*P0['TL']/an['J']; a8p = ap['np']*P0['TL']/ap['J']
    wstar = 1.05*an['ws']; iqstar = an['psi']/an['Lm']
    mpc = MPC(TS, MPCW['N'], MPCW['Q'], MPCW['r']); ke, ki = -mpc.K[0, 0], -mpc.K[0, 1]
    x = np.array([0.3, 0.6, 3.6]); st = dict(I=np.zeros(2), I3=0.0)
    n = int(T/TS); out = dict(t=np.zeros(n), x=np.zeros((n, 3)), u=np.zeros((n, 2)))
    for k in range(n):
        t = k*TS
        if t < t_on: u = np.array([P0['udr0'], P0['uqr0']])
        else: u, _ = controller(ctrl, x, an, a8n, 0.0, wstar, 0.0, 0.0, iqstar, 0.0, st, mpc, ke, ki)
        x = step(x, ap, a8p, u)
        out['t'][k] = t+TS; out['x'][k] = x; out['u'][k] = u
    xstar = np.array([(an['a7']*wstar+a8n)/an['a6'], iqstar, wstar])
    m = out['t'] >= t_on; ew = out['x'][m, 2]-wstar; tt = out['t'][m]
    bad = np.where((np.abs(ew) > 0.01*wstar))[0]
    ts = float(tt[bad[-1]]-t_on) if len(bad) else 0.0
    res = dict(IAE_w=float(np.sum(np.abs(ew))*TS), ts=ts, ef=float(abs(ew[-1])),
               ei=float(np.abs(out['x'][-1, :2]-ap_star(ap, a8p, wstar, iqstar)[:2]).max()),
               umax=float(np.abs(out['u'][m]).max()))
    return out, res, xstar

def ap_star(a, a8, w, iq):
    return np.array([(a['a7']*w+a8)/a['a6'], iq, w])

def wind():
    W = np.loadtxt('../matlab_single/wind_profile.csv', delimiter=',', skiprows=1)
    return W[:, 0], W[:, 1]

def caseB(ctrl, mism='nom'):
    pn = dict(P0); pn['D'] = TURB['Dn']                  # normal operation: nominal damping
    an = coef(pn); ap = coef(perturb(pn, MISM[mism]))
    t, v = wind(); dt = t[1]-t[0]
    vf = v.copy()
    for k in range(1, len(v)): vf[k] = vf[k-1]+dt/2.0*(v[k]-vf[k-1])
    wref = TURB['G']*TURB['lopt']*vf/TURB['R']; dwref = np.gradient(wref, dt); ddwref = np.gradient(dwref, dt)
    dv = np.gradient(v, dt)
    a8ref = -an['np']*Ta(v, wref, an)/an['J']
    idref = (dwref+an['a7']*wref+a8ref)/an['a6']                # MPPT feed-forward (torque balance)
    iqref = an['psi']/an['Lm']
    mpc = MPC(TS, MPCW['N'], MPCW['Q'], MPCW['r']); ke, ki = -mpc.K[0, 0], -mpc.K[0, 1]
    x = np.array([0.0, 0.0, 0.9*wref[0]]); st = dict(I=np.zeros(2), I3=0.0)
    n = len(t)-1; X = np.zeros((n, 3)); U = np.zeros((n, 2))
    for k in range(n):
        a8 = -an['np']*Ta(v[k], x[2], an)/an['J']
        dx3 = F(x, an, a8)[2]
        da8 = -an['np']*dTa_dt(v[k], x[2], an, dv[k], dx3)/an['J']
        u, _ = controller(ctrl, x, an, a8, da8, wref[k], dwref[k], ddwref[k], iqref, 0.0, st, mpc, ke, ki)
        a8p = -ap['np']*Ta(v[k], x[2], ap)/ap['J']
        x = step(x, ap, a8p, u); X[k] = x; U[k] = u
    tk = t[1:]; m = tk >= 5.0
    xr = np.vstack([idref, np.full_like(t, iqref), wref]).T[1:]
    P = Ps(X[:, 0], an); Pr = Ps(xr[:, 0], an)
    bad = np.where(np.abs(X[:, 2]-xr[:, 2]) > 0.02*xr[0, 2])[0]
    res = dict(rmse_w=float(np.sqrt(np.mean((X[m, 2]-xr[m, 2])**2))),
               rmse_idr=float(np.sqrt(np.mean((X[m, 0]-xr[m, 0])**2))),
               rmse_P_kW=float(np.sqrt(np.mean((P[m]-Pr[m])**2))/1e3),
               Pmax_kW=float(Pr.max()/1e3), Pmin_kW=float(Pr.min()/1e3),
               t_reach=float(tk[bad[-1]]) if len(bad) else 0.0, umax=float(np.abs(U).max()),
               wmin=float(xr[:, 2].min()), wmax=float(xr[:, 2].max()))
    return dict(t=tk, x=X, xr=xr, u=U, v=v[1:], vf=vf[1:]), res

if __name__ == '__main__':
    case, ctrl, mism = sys.argv[1], sys.argv[2], sys.argv[3]
    if case == 'A': out, res, xs = caseA(ctrl, mism); out['xstar'] = xs
    else: out, res = caseB(ctrl, mism)
    print(case, ctrl, mism, res, flush=True)
    pickle.dump(dict(out=out, res=res), open(f'{case}_{ctrl}_{mism}.pkl', 'wb'))
