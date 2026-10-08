function vi = blk_pbc_gsc(igr, ig, vg, Vdc)
%BLK_PBC_GSC  [Simulink block, Ts] Passivity-based current control of the
%PWM inverter + L filter:
%  vi* = Lf di*/dt + Rf i* - wg Lf J i* + vg - Rb e - Ki int e
persistent igf zg
P = pmsg_params();
if isempty(igf), igf = [ig(1); 0]; zg = [0; 0]; end
tau = 2e-3;  Rb = P.Lf/tau;  Ki = P.Lf/(4*tau^2);  tau_d = 2e-3;
digr = (igr - igf)/tau_d;  igf = igf + P.Ts*digr;
eg  = ig - igr;
v   = P.Lf*digr + P.Rf*igr - P.wg*P.Lf*[igr(2); -igr(1)] + vg ...
      - Rb*eg - Ki*zg;
vi  = sat_vec(v, Vdc/sqrt(3));
if norm(v - vi) < 1e-9, zg = zg + P.Ts*eg; end
end
