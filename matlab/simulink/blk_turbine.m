function [Tw, Cp, lambda] = blk_turbine(w, vw)
%BLK_TURBINE  [Simulink block] Aerodynamic torque Tw = Pw/Omega,
%Pw = 0.5 rho pi R^2 Cp(lambda, beta) v^3.
P = pmsg_params();
lambda = w*P.R/max(vw, 0.1);
Cp = aero_cp(lambda, P.beta);
Tw = 0.5*P.rho*pi*P.R^2*Cp*vw^3/max(w, 0.05);
end
