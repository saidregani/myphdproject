function [Tes, isqr, ew, satw] = blk_flat_speed(wr, dwr, w, vw, dTe, robust)
%BLK_FLAT_SPEED  [Simulink block, Ts] Flatness-based speed control, flat
%output y1 = Omega:
%  Te* = Tw_hat - B Omega - J (dOmega* + k11 e + k12 int e) + dTe_ANN
persistent zw
P = pmsg_params();
if isempty(zw), zw = 0; end
kTw = 1;  if robust, kTw = 0.9; end              % 10 % Cp-model error
wnw = 2; zt = 0.9;  k11 = 2*zt*wnw;  k12 = wnw^2;
ew  = wr - w;
lam = w*P.R/max(vw, 0.1);
Twh = kTw*0.5*P.rho*pi*P.R^2*aero_cp(lam, P.beta)*vw^3/max(w, 0.05);
nu1 = dwr + k11*ew + k12*zw;
Te  = Twh - P.B*w - P.J*nu1 + dTe;               % u = u_N + u_AI
Tes = clamp(Te, P.Te_min, P.Te_max);
satw = double(~(Te == Tes || sign(-ew) ~= sign(Te - Tes)));
if ~satw, zw = zw + P.Ts*ew; end                % anti-windup
isqr = clamp(Tes/(1.5*P.p*P.psi), -P.Imax_s, P.Imax_s);
end
