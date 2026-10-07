function [x, u] = init_state(P, Pp, vw0)
%INIT_STATE  Steady-state MPPT operating point for wind speed vw0.
w0   = P.lopt*vw0/P.R;
Tw0  = 0.5*Pp.rho*pi*Pp.R^2*aero_cp(P.lopt, 0)*vw0^3/w0;
isq0 = (Tw0 - Pp.B*w0)/(1.5*Pp.p*Pp.psi);
we0  = Pp.p*w0;
us0  = [we0*Pp.Ls*isq0; we0*Pp.psi - Pp.Rs*isq0];
Pg0  = 1.5*us0(2)*isq0;
igd0 = Pg0/(1.5*P.Vgm);
ui0  = [P.Vgm + Pp.Rf*igd0; Pp.wg*Pp.Lf*igd0];
x = [0; isq0; w0; P.Vdc_ref; igd0; 0];
u = [us0; ui0];
end
