function [wr, dwr, S] = mppt_ref(vw, S, P)
%MPPT_REF  Optimal speed reference w* = lambda_opt*v/R, smoothed by a
%critically damped 2nd-order filter that also provides dw*/dt.
Ts = P.Ts;
S.vf  = S.vf + Ts/0.3*(vw - S.vf);                  % anemometer filter
wraw  = clamp(P.lopt*S.vf/P.R, 0.4*P.wn, 1.05*P.wn);
wn = 1.5; z = 1;
ddw   = wn^2*(wraw - S.wr) - 2*z*wn*S.dwr;
S.wr  = S.wr + Ts*S.dwr;
S.dwr = S.dwr + Ts*ddw;
wr = S.wr; dwr = S.dwr;
end
