%RUN_CASE  Runs one simulation case (used by the batch study of the revision).
% Environment variables: CTRL (PI|PIFF|FPBC0|FPBC), SCEN (nominal|robust),
% TEND [s], CFG (MATLAB statements modifying P), TAG, SAVE (1 = write CSV),
% MLI (1 = switched model, THD only).
P = pmsg_params();  P.Tend = str2double(getenv('TEND'));
cfg = getenv('CFG');  if ~isempty(cfg), eval(cfg); end
c = getenv('CTRL');  s = getenv('SCEN');  tag = getenv('TAG');
if strcmp(getenv('MLI'), '1')
  o = simulate_mli(P, c, P.Tend);
  printf('RES %s THD=%.3f\n', tag, o.THD_ig);
  return
end
o = simulate(P, c, s);
dt = o.t(2) - o.t(1);  t = o.t;
ew = o.x(:,3) - o.lg(:,1);  eV = o.x(:,4) - P.Vdc_ref;
eisq = o.x(:,2) - o.lg(:,3);  eigd = o.x(:,5) - o.lg(:,4);
dip = t > 7.9 & t < 8.6;  su = t < 1;
if any(dip), dipmax = max(abs(eV(dip))); else, dipmax = NaN; end
printf(['RES %s IAEw=%.6g RMSw=%.4g maxw=%.4g RMSisq=%.4g RMSigd=%.4g ISEV=%.5g ' ...
        'maxVsu=%.4g maxVdip=%.4g maxVrest=%.4g Cp=%.5f E=%.4f\n'], tag, sum(abs(ew))*dt, ...
        sqrt(mean(ew.^2)), max(abs(ew)), sqrt(mean(eisq.^2)), sqrt(mean(eigd.^2)), ...
        sum(eV.^2)*dt, max(abs(eV(su))), dipmax, max(abs(eV(~su & ~dip))), mean(o.Cp), ...
        sum(o.Pgrid)*dt/3.6e6);
if strcmp(getenv('SAVE'), '1')
  M = [t o.vw o.x o.lg(:,1:5) o.Cp o.Pgrid o.Qgrid];
  dlmwrite([tag '.csv'], M, 'precision', '%.8g');
end
