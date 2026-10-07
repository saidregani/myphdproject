function [u, S, lg] = ctrl_fpbc_ann(m, S, P)
%CTRL_FPBC_ANN  Flatness-based control (outer loops) + passivity-based
%control (inner current loops) of the complete PMSG chain, with the
%controller gains tuned online by RBF neural networks.
%
% Outer loops (flatness): flat outputs y1 = Omega (rotor speed) and
%   y2 = W = 0.5*C*Vdc^2 + 0.75*Lf*|i_g|^2 (energy stored in DC bus + filter).
%   Every state/input is an algebraic function of y and its derivatives, so
%   the reference input is obtained by inversion + a tracking law on y.
% Inner loops (PBC): L de/dt = -(R + Ra(t)) e + w L J e - Ki z, z = int(e),
%   J skew-symmetric -> V = 0.5 e'Le + 0.5 Ki z'z, dV/dt = -(R+Ra)|e|^2.
% ANN: tunes only the proportional/damping gains, kept in [gmin, gmax] > 0,
%   so the storage-function argument above holds for any tuned value.
Ts = P.Ts;
[wr, dwr, S] = mppt_ref(m.vw, S, P);
we = P.p*m.w;
Jm = [0 1; -1 0];

%% Speed loop - flatness (flat output y1 = Omega)
% J dOmega/dt = Tw - Te - B Omega  =>  Te = Tw - B Omega - J*nu1
% nu1 = dOmega*/dt + k11 (Omega* - Omega) + k12 int(Omega* - Omega)
ew  = wr - m.w;
enw = ew/(0.02*P.wn);
[gw, S.nn_w] = rbf_gain(S.nn_w, enw, (enw - S.en_w)/Ts*0.5, Ts);  S.en_w = enw;
lam = m.w*P.R/max(m.vw, 0.1);                       % aerodynamic torque
Twh = P.kTw*0.5*P.rho*pi*P.R^2*aero_cp(lam, P.beta)*m.vw^3/max(m.w, 0.05);
nu1 = dwr + gw*S.k11*ew + S.k12*S.zw;
Te  = Twh - P.B*m.w - P.J*nu1;
Tes = clamp(Te, P.Te_min, P.Te_max);
if Te == Tes || sign(-ew) ~= sign(Te - Tes), S.zw = S.zw + Ts*ew; end  % anti-windup

%% Machine-side current loop - passivity-based (rectifier MLI)
isr  = [0; clamp(Tes/(1.5*P.p*P.psi), -P.Imax_s, P.Imax_s)];
disr = (isr - S.is_f)/S.tau_d;  S.is_f = S.is_f + Ts*disr;
is  = [m.isd; m.isq];
es  = is - isr;
en  = norm(es)/(0.05*S.Ibs);
[gs, S.nn_s] = rbf_gain(S.nn_s, en, (en - S.en_s)/Ts*2e-3, Ts);  S.en_s = en;
vs  = -P.Ls*disr - P.Rs*isr + we*P.Ls*Jm*isr + [0; we*P.psi] ...
      + gs*S.Ra0*es + S.Kis*S.zs;
vsl = sat_vec(vs, m.Vdc/sqrt(3));
if norm(vs - vsl) < 1e-9, S.zs = S.zs + Ts*es; end

%% DC-bus loop - flatness (flat output y2 = stored energy)
% dy2/dt = P_msc - P_grid - 1.5 Rf |i_g|^2  =>  P_grid = P_msc - 1.5Rf|i_g|^2 - nu2
Pmsc = 1.5*(S.u(1)*m.isd + S.u(2)*m.isq);
ig   = [m.igd; m.igq];
y2   = 0.5*P.C*m.Vdc^2 + 0.75*P.Lf*(ig'*ig);
y2r  = 0.5*P.C*P.Vdc_ref^2 + 0.75*P.Lf*(S.ig_f'*S.ig_f);  % y2 at Vdc = Vdc*
ey   = y2r - y2;
env  = (P.Vdc_ref - m.Vdc)/(0.01*P.Vdc_ref);
[gv, S.nn_v] = rbf_gain(S.nn_v, env, (env - S.en_v)/Ts*0.02, Ts);  S.en_v = env;
nu2  = gv*S.k21*ey + S.k22*S.zv;          % dy2*/dt ~ 0 (slow i_g*)
Pgr  = Pmsc - 1.5*P.Rf*(ig'*ig) - nu2;
igd  = 2*Pgr/(3*m.vg(1));
igdl = clamp(igd, -P.Imax_g, P.Imax_g);
if igd == igdl, S.zv = S.zv + Ts*ey; end

%% Grid-side current loop - passivity-based (onduleur MLI + filtre L)
igr  = [igdl; -2*P.Qref/(3*m.vg(1))];
digr = (igr - S.ig_f)/S.tau_d;  S.ig_f = S.ig_f + Ts*digr;
eg  = ig - igr;
en  = norm(eg)/(0.05*S.Ibg);
[gg, S.nn_g] = rbf_gain(S.nn_g, en, (en - S.en_g)/Ts*2e-3, Ts);  S.en_g = en;
vi  = P.Lf*digr + P.Rf*igr - P.wg*P.Lf*Jm*igr + m.vg ...
      - gg*S.Rb0*eg - S.Kig*S.zg;
vil = sat_vec(vi, m.Vdc/sqrt(3));
if norm(vi - vil) < 1e-9, S.zg = S.zg + Ts*eg; end

u = [vsl; vil];  S.u = u;
lg = [wr, isr', igr', y2, Twh, NaN, NaN, gs, gg, gw, gv];
end
