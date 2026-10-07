function [u, S, lg] = ctrl_pi(m, S, P)
%CTRL_PI  Classical vector control: PI speed loop + PI current loops
%(MSC), PI DC-bus loop + PI current loops (GSC), with dq decoupling.
Ts = P.Ts;
[wr, ~, S] = mppt_ref(m.vw, S, P);
we = P.p*m.w;

%% Machine side
ew  = m.w - wr;
Te  = S.Kpw*ew + S.Iw;
Tes = clamp(Te, P.Te_min, P.Te_max);
if Te == Tes || sign(ew) ~= sign(Te - Tes)       % anti-windup
  S.Iw = S.Iw + Ts*S.Kiw*ew;
end
isr = [0; clamp(Tes/(1.5*P.p*P.psi), -P.Imax_s, P.Imax_s)];
is  = [m.isd; m.isq];
es  = is - isr;
vs  = we*P.Ls*[is(2); -is(1)] + [0; we*P.psi] + S.Kps*es + S.Is;
vsl = sat_vec(vs, m.Vdc/sqrt(3));
if norm(vs - vsl) < 1e-9, S.Is = S.Is + Ts*S.Kis*es; end

%% DC bus + grid side
ev  = m.Vdc - P.Vdc_ref;
igr = [clamp(S.Kpv*ev + S.Iv, -P.Imax_g, P.Imax_g); -2*P.Qref/(3*m.vg(1))];
if abs(S.Kpv*ev + S.Iv) < P.Imax_g, S.Iv = S.Iv + Ts*S.Kiv*ev; end
ig  = [m.igd; m.igq];
eg  = ig - igr;
vi  = m.vg - P.wg*P.Lf*[ig(2); -ig(1)] - S.Kpg*eg - S.Ig;
vil = sat_vec(vi, m.Vdc/sqrt(3));
if norm(vi - vil) < 1e-9, S.Ig = S.Ig + Ts*S.Kig*eg; end

u = [vsl; vil];  S.u = u;
lg = [wr, isr', igr', NaN, NaN, NaN, NaN, 1, 1, 1, 1];
end
