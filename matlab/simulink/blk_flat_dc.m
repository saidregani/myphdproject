function [igr, ey, satv] = blk_flat_dc(Vdc, is, vs_prev, ig, vg, dPg)
%BLK_FLAT_DC  [Simulink block, Ts] Flatness-based DC-link control, flat
%output y2 = 0.5 C Vdc^2 + 0.75 Lf |ig|^2:
%  Pg* = P_msc - 1.5 Rf |ig|^2 - (k21 e + k22 int e) + dPg_ANN
persistent zv igf
P = pmsg_params();
if isempty(zv), zv = 0; igf = [ig(1); 0]; end
wnv = 60;  k21 = 2*wnv;  k22 = wnv^2;  tau_d = 2e-3;
Pmsc = 1.5*(vs_prev(1)*is(1) + vs_prev(2)*is(2));
y2   = 0.5*P.C*Vdc^2 + 0.75*P.Lf*(ig'*ig);
y2r  = 0.5*P.C*P.Vdc_ref^2 + 0.75*P.Lf*(igf'*igf);
ey   = y2r - y2;
nu2  = k21*ey + k22*zv;
Pgr  = Pmsc - 1.5*P.Rf*(ig'*ig) - nu2 + dPg;     % u = u_N + u_AI
igd  = 2*Pgr/(3*vg(1));
igdl = clamp(igd, -P.Imax_g, P.Imax_g);
satv = double(igd ~= igdl);
if ~satv, zv = zv + P.Ts*ey; end
igr  = [igdl; -2*P.Qref/(3*vg(1))];
igf  = igf + P.Ts*(igr - igf)/tau_d;              % same filter as the GSC block
end
