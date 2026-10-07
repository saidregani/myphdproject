function Pp = plant_true(P, scenario)
%PLANT_TRUE  "Real" plant parameters. In the 'robust' scenario they differ
%from the nominal values used by the controllers.
Pp = P;
if strcmp(scenario, 'robust')
  Pp.Rs = 1.5*P.Rs;  Pp.Ls = 1.2*P.Ls;  Pp.psi = 0.92*P.psi;
  Pp.Rf = 1.5*P.Rf;  Pp.Lf = 1.25*P.Lf;
end
end
