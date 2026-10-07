function dx = plant_rhs(x, u, vw, vg, Pp)
%PLANT_RHS  Average model of the complete back-to-back PMSG chain.
% x = [i_sd i_sq w_m V_dc i_gd i_gq]   (states)
% u = [v_sd v_sq v_id v_iq]            (MSC / GSC terminal voltages, dq)
% vw: wind speed, vg = [v_gd v_gq]: grid voltage, Pp: plant parameters.
isd = x(1); isq = x(2); w = x(3); Vdc = x(4); igd = x(5); igq = x(6);
we  = Pp.p * w;

% aerodynamic torque
lam = w*Pp.R / max(vw, 0.1);
Pw  = 0.5*Pp.rho*pi*Pp.R^2*aero_cp(lam, Pp.beta)*vw^3;
Tw  = Pw / max(w, 0.05);

% PMSG (generator convention), surface PM: Te = 1.5 p psi i_sq
disd = (-Pp.Rs*isd + we*Pp.Ls*isq - u(1)) / Pp.Ls;
disq = (-Pp.Rs*isq - we*Pp.Ls*isd + we*Pp.psi - u(2)) / Pp.Ls;
Te   = 1.5*Pp.p*Pp.psi*isq;
dw   = (Tw - Te - Pp.B*w) / Pp.J;

% DC bus (lossless converters): C dVdc/dt = (P_msc - P_gsc)/Vdc
Pmsc = 1.5*(u(1)*isd + u(2)*isq);
Pgsc = 1.5*(u(3)*igd + u(4)*igq);
dVdc = (Pmsc - Pgsc) / (Pp.C*Vdc);

% L filter, current flowing from inverter to grid
digd = (-Pp.Rf*igd + Pp.wg*Pp.Lf*igq + u(3) - vg(1)) / Pp.Lf;
digq = (-Pp.Rf*igq - Pp.wg*Pp.Lf*igd + u(4) - vg(2)) / Pp.Lf;

dx = [disd; disq; dw; dVdc; digd; digq];
end
