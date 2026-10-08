%RUN_CASE  Runs one simulation case (used by the batch study of the revision).
% Environment variables: CTRL (PI|PIFF|FPBC0|FPBC), SCEN (nominal|robust),
% TEND [s], CFG (MATLAB statements modifying P), TAG, SAVE (1 = write CSV),
% MLI (1 = switched model, THD only).
P = pmsg_params();  P.Tend = str2double(getenv('TEND'));
cfg = getenv('CFG');  if ~isempty(cfg), eval(cfg); end
c = getenv('CTRL');  s = getenv('SCEN');  tag = getenv('TAG');
if strcmp(getenv('MLI'), '1')
  o = simulate_mli(P, c, P.Tend);
  printf('RES %s THD40=%.3f THD50=%.3f TDD50=%.3f Ihmax=%.3f TDall=%.3f I1/In=%.3f\n', tag, ...
         o.THD_ig, o.THD50, o.TDD50, o.Ihmax_pct, o.TDall, o.I1/(P.Pn/(1.5*P.Vgm)));
  [~, ih] = sort(o.Ih, 'descend');  ih = ih(1:6);  Ih = o.Ih(:);
  printf('TOP h=%d:%.3f%% ', [ih(:)' + 1; Ih(ih)'/(P.Pn/(1.5*P.Vgm))*100]);  printf('\n');
  if strcmp(getenv('SAVE'), '1'), Ysp = o.Y; save('-ascii', [tag '_spec.txt'], 'Ysp'); end
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
if size(o.lg, 2) >= 8 && strcmp(getenv('Y2LOG'), '1')     % dy2*/dt of the flat DC law
  d = o.lg(:,8);  nd = ~su & ~dip;
  printf('Y2 %s max|dy2*| su=%.4g dip=%.4g rest=%.4g W, rms rest=%.4g W\n', tag, ...
         max(abs(d(su))), max(abs(d(dip))), max(abs(d(nd))), sqrt(mean(d(nd).^2)));
end
if strcmp(getenv('SAVE'), '1')
  M = [t o.vw o.x o.lg(:,1:5) o.Cp o.Pgrid o.Qgrid];
  dlmwrite([tag '.csv'], M, 'precision', '%.8g');
end
