function [u, S, lg] = ctrl_apbc_ann(m, S, P)
%CTRL_APBC_ANN  Adaptive passivity-based control (PBC + Lyapunov parameter
%adaptation) of the complete back-to-back PMSG chain, with damping-injection
%gains tuned online by RBF neural networks.
%
% For every loop the error dynamics take the form  M de/dt = -(R + K(t)) e
% + Jsk e + Phi*theta_tilde, with Jsk skew-symmetric (workless coupling),
% so with V = 0.5 e'Me + sum(theta_tilde^2/(2 gamma)) and the adaptation
% laws below, dV/dt = -(R + K(t))|e|^2 <= 0 for ANY K(t) > 0: the ANN only
% shapes the transient, it cannot destabilise the loop.
Ts = P.Ts;
[wr, dwr, S] = mppt_ref(m.vw, S, P);
we = P.p*m.w;
Jm = [0 1; -1 0];

%% Speed loop (adaptive PBC, unknown aerodynamic torque Tw)
% J de_w/dt = Tw - Te - B w - J dw*/dt
ew = m.w - wr;
S.en_w_d = (ew/(0.02*P.wn) - S.en_w)/Ts;  S.en_w = ew/(0.02*P.wn);
[gw, S.nn_w] = rbf_gain(S.nn_w, S.en_w, S.en_w_d*0.5, Ts);
Te  = S.Twh - P.B*m.w - P.J*dwr + gw*S.kw0*ew;
Tes = clamp(Te, P.Te_min, P.Te_max);
if Te == Tes || sign(ew) ~= sign(Te - Tes)          % freeze if saturated
  S.Twh = clamp(S.Twh + Ts*S.gT*ew, 0, 1.5*P.Tn);
end

%% Machine-side current loop (adaptive PBC, unknown Rs, Ls, psi)
isr = [0; clamp(Tes/(1.5*P.p*S.psih), -P.Imax_s, P.Imax_s)];
disr   = (isr - S.is_f)/S.tau_d;  S.is_f = S.is_f + Ts*disr;
is  = [m.isd; m.isq];
es  = is - isr;
en  = norm(es)/(0.05*S.Ibs);
S.en_s_d = (en - S.en_s)/Ts;  S.en_s = en;
[gs, S.nn_s] = rbf_gain(S.nn_s, en, S.en_s_d*2e-3, Ts);
Ka  = gs*S.Ka0;
vs  = -S.Lh*disr - S.Rh*isr + we*S.Lh*Jm*isr + [0; we*S.psih] + Ka*es;
vsl = sat_vec(vs, m.Vdc/sqrt(3));
if norm(vs - vsl) < 1e-9                           % adaptation laws
  S.Rh   = clamp(S.Rh   - Ts*S.gR  *(es'*isr),               0.3*P.Rs,  3*P.Rs);
  S.Lh   = clamp(S.Lh   + Ts*S.gL  *(es'*(we*Jm*isr - disr)), 0.3*P.Ls,  3*P.Ls);
  S.psih = clamp(S.psih + Ts*S.gpsi*we*es(2),                0.5*P.psi, 1.5*P.psi);
end

%% DC-bus loop (energy shaping, adaptive power disturbance d)
% dW/dt = P_msc - P_gsc,  W = 0.5 C Vdc^2
Pmsc = 1.5*(S.u(1)*m.isd + S.u(2)*m.isq);        % measured (known u, i)
eW   = 0.5*P.C*(m.Vdc^2 - P.Vdc_ref^2);
env  = (m.Vdc - P.Vdc_ref)/(0.01*P.Vdc_ref);
S.en_v_d = (env - S.en_v)/Ts;  S.en_v = env;
[gv, S.nn_v] = rbf_gain(S.nn_v, env, S.en_v_d*0.02, Ts);
Pr  = Pmsc + S.dh + gv*S.kv0*eW;
igd = 2*Pr/(3*m.vg(1));
igdl = clamp(igd, -P.Imax_g, P.Imax_g);
if igd == igdl, S.dh = S.dh + Ts*S.gd*eW; end

%% Grid-side current loop (adaptive PBC, unknown Rf, Lf)
igr = [igdl; -2*P.Qref/(3*m.vg(1))];
digr  = (igr - S.ig_f)/S.tau_d;  S.ig_f = S.ig_f + Ts*digr;
ig  = [m.igd; m.igq];
eg  = ig - igr;
en  = norm(eg)/(0.05*S.Ibg);
S.en_g_d = (en - S.en_g)/Ts;  S.en_g = en;
[gg, S.nn_g] = rbf_gain(S.nn_g, en, S.en_g_d*2e-3, Ts);
Kb  = gg*S.Kb0;
vi  = S.Lfh*digr + S.Rfh*igr - P.wg*S.Lfh*Jm*igr + m.vg - Kb*eg;
vil = sat_vec(vi, m.Vdc/sqrt(3));
if norm(vi - vil) < 1e-9
  S.Rfh = clamp(S.Rfh - Ts*S.gRf*(eg'*igr),                  0.3*P.Rf, 3*P.Rf);
  S.Lfh = clamp(S.Lfh + Ts*S.gLf*(eg'*(P.wg*Jm*igr - digr)),  0.3*P.Lf, 3*P.Lf);
end

u = [vsl; vil];  S.u = u;
lg = [wr, isr', igr', S.Rh, S.Lh, S.psih, S.Twh, gs, gg, gw, gv];
end
