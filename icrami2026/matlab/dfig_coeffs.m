function a = dfig_coeffs(p)
%DFIG_COEFFS Coefficients a1..a7, c1, c2 of Eqs. (3)-(4) from the parameters p.
a.ws  = 2*pi*p.fs;
a.psi = sqrt(2)*p.Vll/sqrt(3)/a.ws;                 % stator flux = V_s/omega_s
a.sig = 1 - p.Lm^2/(p.Ls*p.Lr);
a.a1  = -p.Rs*p.Lm^2/(a.sig*p.Ls^2*p.Lr) - p.Rr/(a.sig*p.Lr);
a.a2  = -p.Lm*a.psi/(a.sig*p.Lr*p.Ls);
a.a3  = -p.Lm/(a.sig*p.Ls*p.Lr);
a.a4  = 1/(a.sig*p.Lr);
a.a5  = p.Rs*p.Lm*a.psi/(a.sig*p.Ls^2*p.Lr);
a.a6  = 3*p.np^2*p.Lm*a.psi/(2*p.J*p.Ls);
a.a7  = p.D/p.J;
a.uds = -a.ws*a.psi;  a.uqs = 0;
a.c1  = a.a3*a.uds;                                  % u_dr, u_qr are supplied by the controller
a.c2  = a.a5 + a.a3*a.uqs;
a.np = p.np; a.J = p.J; a.Lm = p.Lm; a.Ls = p.Ls;
a.rho = p.rho; a.R = p.R; a.G = p.G; a.lopt = p.lopt;
end
