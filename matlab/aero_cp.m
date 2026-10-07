function Cp = aero_cp(lambda, beta)
%AERO_CP  Power coefficient (Heier / Slootweg model). Cp_max = 0.48 at
%lambda = 8.1, beta = 0.
li = 1 ./ (1./(lambda + 0.08*beta) - 0.035./(beta.^3 + 1));
Cp = 0.5176*(116./li - 0.4*beta - 5).*exp(-21./li) + 0.0068*lambda;
Cp = max(Cp, 0);
end
