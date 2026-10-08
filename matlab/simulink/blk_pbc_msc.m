function [vs, es] = blk_pbc_msc(isqr, is, w, Vdc)
%BLK_PBC_MSC  [Simulink block, Ts] Passivity-based current control of the
%PWM rectifier (damping injection Ra + integral injection Ki):
%  vs* = -Ls di*/dt - Rs i* + we Ls J i* + we psi e_q + Ra e + Ki int e
persistent isf zs
P = pmsg_params();
if isempty(isf), isf = [0; is(2)]; zs = [0; 0]; end
tau = 2e-3;  Ra = P.Ls/tau;  Ki = P.Ls/(4*tau^2);  tau_d = 2e-3;
we  = P.p*w;
isr = [0; isqr];
disr = (isr - isf)/tau_d;  isf = isf + P.Ts*disr;   % dirty derivative
es  = is - isr;
v   = -P.Ls*disr - P.Rs*isr + we*P.Ls*[isr(2); -isr(1)] + [0; we*P.psi] ...
      + Ra*es + Ki*zs;
vs  = sat_vec(v, Vdc/sqrt(3));
if norm(v - vs) < 1e-9, zs = zs + P.Ts*es; end
end
