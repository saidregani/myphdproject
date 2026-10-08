function Pp = plant_pp(P, robust)
%PLANT_PP  "True" plant parameters (numeric flag version of plant_true.m,
%usable inside Simulink MATLAB Function blocks). robust = 1: mismatch.
Pp = P;
if robust
  Pp.Rs = 1.5*P.Rs;  Pp.Ls = 1.2*P.Ls;  Pp.psi = 0.92*P.psi;
  Pp.Rf = 1.5*P.Rf;  Pp.Lf = 1.25*P.Lf;
end
end
