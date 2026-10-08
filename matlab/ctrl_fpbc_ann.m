function [u, S, lg] = ctrl_fpbc_ann(m, S, P)
%CTRL_FPBC_ANN  Flatness-based control (outer loops) + passivity-based
%control (inner current loops) of the complete PMSG chain, with an adaptive
%ANN compensator u = u_N + u_AI on the flat (outer) loops.
%
% Outer loops (flatness): flat outputs y1 = Omega (rotor speed) and
%   y2 = W = 0.5*C*Vdc^2 + 0.75*Lf*|i_g|^2 (energy stored in DC bus + filter).
%   Every state/input is an algebraic function of y and its derivatives, so
%   the reference input is obtained by inversion + a tracking law on y.
% Inner loops (PBC): L de/dt = -(R + Ra(t)) e + w L J e - Ki z, z = int(e),
%   J skew-symmetric -> V = 0.5 e'Le + 0.5 Ki z'z, dV/dt = -(R+Ra)|e|^2.
% ANN: same scheme as in the authors' Mathematics paper (DFIG). A 6-10-2
%   MLP takes z = [e; de/dt] with e = [e_Omega, e_y2, e_isq] and adds
%   u_AI = [dTe; dPg] to the flatness inputs, WITHOUT changing the nominal
%   gains. Learning signal r = B'e (control direction: e_Omega, e_y2) with
%   a dead-zone, sigma-modification and back-propagation (ann_step.m).
Ts = P.Ts;
[wr, dwr, S] = mppt_ref(m.vw, S, P);
we = P.p*m.w;
Jm = [0 1; -1 0];

%% Speed loop - flatness (flat output y1 = Omega)
% J dOmega/dt = Tw - Te - B Omega  =>  Te = Tw - B Omega - J*nu1
% nu1 = dOmega*/dt + k11 (Omega* - Omega) + k12 int(Omega* - Omega)
ew  = wr - m.w;
lam = m.w*P.R/max(m.vw, 0.1);                       % aerodynamic torque
Twh = P.kTw*0.5*P.rho*pi*P.R^2*aero_cp(lam, P.beta)*m.vw^3/max(m.w, 0.05);
nu1 = dwr + S.k11*ew + S.k12*S.zw;
Te  = Twh - P.B*m.w - P.J*nu1 + S.uAI(1);           % u = u_N + u_AI
Tes = clamp(Te, P.Te_min, P.Te_max);
S.satw = ~(Te == Tes || sign(-ew) ~= sign(Te - Tes));
if ~S.satw, S.zw = S.zw + Ts*ew; end                 % anti-windup

%% Machine-side current loop - passivity-based (rectifier MLI)
isr  = [0; clamp(Tes/(1.5*P.p*P.psi), -P.Imax_s, P.Imax_s)];
disr = (isr - S.is_f)/S.tau_d;  S.is_f = S.is_f + Ts*disr;
is  = [m.isd; m.isq];
es  = is - isr;
vs  = -P.Ls*disr - P.Rs*isr + we*P.Ls*Jm*isr + [0; we*P.psi] ...
      + S.Ra0*es + S.Kis*S.zs;
vsl = sat_vec(vs, m.Vdc/sqrt(3));
if norm(vs - vsl) < 1e-9, S.zs = S.zs + Ts*es; end

%% DC-bus loop - flatness (flat output y2 = stored energy)
% dy2/dt = P_msc - P_grid - 1.5 Rf |i_g|^2  =>  P_grid = P_msc - 1.5Rf|i_g|^2 - nu2
Pmsc = 1.5*(S.u(1)*m.isd + S.u(2)*m.isq);
ig   = [m.igd; m.igq];
y2   = 0.5*P.C*m.Vdc^2 + 0.75*P.Lf*(ig'*ig);
y2r  = 0.5*P.C*P.Vdc_ref^2 + 0.75*P.Lf*(S.ig_f'*S.ig_f);  % y2 at Vdc = Vdc*
ey   = y2r - y2;
nu2  = S.k21*ey + S.k22*S.zv;             % dy2*/dt ~ 0 (slow i_g*)
if isfield(P, 'y2dot') && P.y2dot && isfield(S, 'dy2r')
  nu2 = nu2 + S.dy2r;                     % optional: include dy2*/dt (previous sample)
end
Pgr  = Pmsc - 1.5*P.Rf*(ig'*ig) - nu2 + S.uAI(2);   % u = u_N + u_AI
igd  = 2*Pgr/(3*m.vg(1));
igdl = clamp(igd, -P.Imax_g, P.Imax_g);
S.satv = (igd ~= igdl);
if ~S.satv, S.zv = S.zv + Ts*ey; end

%% Grid-side current loop - passivity-based (onduleur MLI + filtre L)
igr  = [igdl; -2*P.Qref/(3*m.vg(1))];
digr = (igr - S.ig_f)/S.tau_d;  S.ig_f = S.ig_f + Ts*digr;
S.dy2r = 1.5*P.Lf*(S.ig_f'*digr);         % dy2*/dt (used only if P.y2dot = 1)
eg  = ig - igr;
vi  = P.Lf*digr + P.Rf*igr - P.wg*P.Lf*Jm*igr + m.vg ...
      - S.Rb0*eg - S.Kig*S.zg;
vil = sat_vec(vi, m.Vdc/sqrt(3));
if norm(vi - vil) < 1e-9, S.zg = S.zg + Ts*eg; end

%% Adaptive ANN compensation (used at the next sample)
% normalised errors and filtered derivatives: z = [e; de/dt] (6 inputs)
e  = [ew/S.sw; ey/S.sy; es(2)/S.si];
de = (e - S.e_f)/S.tau_z;  S.e_f = S.e_f + Ts*de;
zn = [e; de.*S.tz];
% learning signal r = B'e: Te enters J de_Omega/dt and Pg enters de_y2/dt
% with a positive sign, so B'e = [e_Omega; e_y2] (normalised)
[S.uAI, S.nn] = ann_step(S.nn, zn, e(1:2), Ts, ~(S.satw || S.satv));
S.uAI = S.uAI.*[S.uT; S.uP];

u = [vsl; vil];  S.u = u;
lg = [wr, isr', igr', y2, Twh, S.dy2r, NaN, S.uAI(1)/P.Tn, S.uAI(2)/P.Pn, ...
      norm(S.nn.W2), double(norm(e(1:2)) > S.nn.delta)];
end
