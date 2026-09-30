function T = aero_torque(v, x3, a)
%AERO_TORQUE Aerodynamic torque referred to the generator shaft, Eq. (1)-(2).
Wm  = max(x3, 1) / a.np;                              % generator mechanical speed
lam = a.R * Wm ./ (a.G * max(v, 0.5));
lam = min(max(lam, 2), 13);
li  = 1 ./ (1 ./ lam - 0.035);
Cp  = max(0.5176*(116./li - 5).*exp(-21./li) + 0.0068*lam, 0);
T   = 0.5*a.rho*pi*a.R^2*Cp.*v.^3 ./ Wm;
end
