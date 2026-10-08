function [wr, dwr] = blk_mppt(vw)
%BLK_MPPT  [Simulink block, Ts] MPPT reference Omega* = lambda_opt v/R with
%anemometer filter and 2nd-order reference filter (gives dOmega*/dt).
persistent vf w dw
P = pmsg_params();
if isempty(vf), vf = vw; w = P.lopt*vw/P.R; dw = 0; end
Ts = P.Ts;
vf   = vf + Ts/0.3*(vw - vf);
wraw = clamp(P.lopt*vf/P.R, 0.4*P.wn, 1.05*P.wn);
wn = 1.5; z = 1;
ddw = wn^2*(wraw - w) - 2*z*wn*dw;
w   = w + Ts*dw;
dw  = dw + Ts*ddw;
wr = w;  dwr = dw;
end
