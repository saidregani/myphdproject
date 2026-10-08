function vout = blk_pi(vw, is, w, Vdc, ig, vg, vs_prev, ff)
%BLK_PI  [Simulink block, Ts] Classical vector control (comparison):
%PI speed + PI currents (MSC), PI DC bus (+ P_msc feed-forward if ff = 1)
%+ PI currents (GSC), with dq decoupling. vout = [vs; vi].
persistent vf wr dwr Iw Iv Is Ig
P = pmsg_params();  Ts = P.Ts;
tau = 2e-3;  wnw = 2;  zw = 0.9;  wnv = 60;  zv = 1;
Kps = P.Ls/tau;  Kis = P.Ls/(4*tau^2);  Kpg = P.Lf/tau;  Kig = P.Lf/(4*tau^2);
Kpw = 2*zw*wnw*P.J;  Kiw = wnw^2*P.J;
Kpv = 2*zv*wnv*P.C*P.Vdc_ref/(1.5*P.Vgm);  Kiv = wnv^2*P.C*P.Vdc_ref/(1.5*P.Vgm);
if isempty(vf)
  vf = vw;  wr = P.lopt*vw/P.R;  dwr = 0;
  Iw = 1.5*P.p*P.psi*is(2) + P.B*w;  Iv = ig(1)*(ff == 0);
  Is = [0; 0];  Ig = [0; 0];
end
% MPPT reference (same as blk_mppt)
vf   = vf + Ts/0.3*(vw - vf);
wraw = clamp(P.lopt*vf/P.R, 0.4*P.wn, 1.05*P.wn);
ddw  = 1.5^2*(wraw - wr) - 2*1.5*dwr;  wr = wr + Ts*dwr;  dwr = dwr + Ts*ddw;
% machine side
we  = P.p*w;
ew  = w - wr;
Te  = Kpw*ew + Iw;
Tes = clamp(Te, P.Te_min, P.Te_max);
if Te == Tes || sign(ew) ~= sign(Te - Tes), Iw = Iw + Ts*Kiw*ew; end
isr = [0; clamp(Tes/(1.5*P.p*P.psi), -P.Imax_s, P.Imax_s)];
es  = is - isr;
v   = we*P.Ls*[is(2); -is(1)] + [0; we*P.psi] + Kps*es + Is;
vs  = sat_vec(v, Vdc/sqrt(3));
if norm(v - vs) < 1e-9, Is = Is + Ts*Kis*es; end
% DC bus + grid side
ev  = Vdc - P.Vdc_ref;
iff = 0;
if ff, iff = (vs_prev(1)*is(1) + vs_prev(2)*is(2))/vg(1); end
igd = Kpv*ev + Iv + iff;
igr = [clamp(igd, -P.Imax_g, P.Imax_g); -2*P.Qref/(3*vg(1))];
if abs(igd) < P.Imax_g, Iv = Iv + Ts*Kiv*ev; end
eg  = ig - igr;
v   = vg - P.wg*P.Lf*[ig(2); -ig(1)] - Kpg*eg - Ig;
vi  = sat_vec(v, Vdc/sqrt(3));
if norm(v - vi) < 1e-9, Ig = Ig + Ts*Kig*eg; end
vout = [vs; vi];
end
