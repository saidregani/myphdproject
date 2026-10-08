function build_pmsg_simulink()
%BUILD_PMSG_SIMULINK  Builds PMSG_FPBC_ANN.slx: complete 2 MW direct-drive
%PMSG wind chain (turbine -> PMSG -> PWM rectifier -> DC bus -> PWM inverter
%-> L filter -> grid, average model) with
%  * the proposed control: flatness (speed, DC energy) + PBC (currents)
%    + adaptive ANN compensation 6-10-2 (u = u_N + u_AI),
%  * the PI vector control used for comparison.
%Every block of the model is a MATLAB Function block calling one of the
%blk_*.m files of this folder (validated against simulate.m by
%test_blocks.m: identical results).
%
%Usage:   build_pmsg_simulink;  then set the switches below and run
%         sim('PMSG_FPBC_ANN');  plot_simulink;
%   CTRL_SEL = 1 : PI          CTRL_SEL = 2 : Flatness + PBC (+ ANN)
%   ANN_ON   = 0/1             PI_FF    = 0/1 (P_msc feed-forward)
%   ROBUST   = 0/1 (parameter mismatch + 10 % Cp error + 20 % grid dip)
here = fileparts(mfilename('fullpath'));
addpath(here, fullfile(here, '..'));
mdl = 'PMSG_FPBC_ANN';
if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist(fullfile(here, [mdl '.slx']), 'file'), delete(fullfile(here, [mdl '.slx'])); end
new_system(mdl);  open_system(mdl);

assignin('base', 'ROBUST', 0);   assignin('base', 'CTRL_SEL', 2);
assignin('base', 'ANN_ON', 1);   assignin('base', 'PI_FF', 0);
pre = ['p = fileparts(which(''' mdl ''')); addpath(p, fullfile(p, ''..''));' ...
       'if ~exist(''ROBUST'',''var''), ROBUST = 0; end;' ...
       'if ~exist(''CTRL_SEL'',''var''), CTRL_SEL = 2; end;' ...
       'if ~exist(''ANN_ON'',''var''), ANN_ON = 1; end;' ...
       'if ~exist(''PI_FF'',''var''), PI_FF = 0; end;'];
ini = ['P = pmsg_params(); Pp = plant_pp(P, ROBUST);' ...
       '[X0, U0] = init_state(P, Pp, wind_speed(0));'];
set_param(mdl, 'PreLoadFcn', pre, 'InitFcn', ini, ...
  'Solver', 'ode4', 'FixedStep', 'P.Ts', 'StopTime', 'P.Tend');
evalin('base', pre);  evalin('base', ini);

%% ===================== PLANT (average model) =========================
pl = [mdl '/Plant: Turbine-PMSG-Back-to-back-L filter-Grid'];
newSub(pl, [330 330 560 560]);
inp(pl, 'vs*', 1, [20 60]);   inp(pl, 'vi*', 2, [20 380]);
inp(pl, 'v_wind', 3, [20 160]); inp(pl, 'v_grid', 4, [20 470]);
cst(pl, 'ROBUST', 'ROBUST', [20 260]);
mf(pl, 'Turbine', ...
  'function [Tw, Cp, lambda] = fcn(w, vw)\n[Tw, Cp, lambda] = blk_turbine(w, vw);', [140 140 240 200]);
mf(pl, 'Drive train', ...
  'function dw = fcn(Tw, Te, w, robust)\ndw = blk_shaft(Tw, Te, w, robust);', [300 140 400 210]);
itg(pl, 'Int Omega', 'X0(3)', [440 155 470 185]);
mf(pl, 'PMSG dq', ...
  'function [dis, Te] = fcn(vs, is, w, robust)\n[dis, Te] = blk_pmsg(vs, is, w, robust);', [300 30 400 100]);
itg(pl, 'Int is', 'X0(1:2)', [440 45 470 75]);
mf(pl, 'PWM rectifier (MSC)', ...
  'function [Pmsc, idc] = fcn(vs, is, Vdc)\n[Pmsc, idc] = blk_rectifier(vs, is, Vdc);', [560 30 680 100]);
mf(pl, 'DC bus', ...
  'function dVdc = fcn(Pmsc, Pgsc, Vdc)\ndVdc = blk_dcbus(Pmsc, Pgsc, Vdc);', [740 140 840 210]);
itg(pl, 'Int Vdc', 'X0(4)', [880 155 910 185]);
mf(pl, 'PWM inverter (GSC)', ...
  'function [Pgsc, idc] = fcn(vi, ig, Vdc)\n[Pgsc, idc] = blk_inverter(vi, ig, Vdc);', [560 360 680 430]);
mf(pl, 'L filter + grid', ...
  'function [dig, Pg, Qg] = fcn(vi, ig, vg, robust)\n[dig, Pg, Qg] = blk_filter(vi, ig, vg, robust);', [300 360 400 470]);
itg(pl, 'Int ig', 'X0(5:6)', [440 375 470 405]);
outp(pl, 'is', 1, [1000 50]);  outp(pl, 'Omega', 2, [1000 160]);
outp(pl, 'Vdc', 3, [1000 220]); outp(pl, 'ig', 4, [1000 380]);
outp(pl, 'Tw', 5, [1000 260]); outp(pl, 'Te', 6, [1000 100]);
outp(pl, 'Cp', 7, [1000 300]); outp(pl, 'Pg', 8, [1000 440]);
outp(pl, 'Qg', 9, [1000 480]);
L(pl, 'Int Omega/1', 'Turbine/1');   L(pl, 'v_wind/1', 'Turbine/2');
L(pl, 'Turbine/1', 'Drive train/1'); L(pl, 'PMSG dq/2', 'Drive train/2');
L(pl, 'Int Omega/1', 'Drive train/3'); L(pl, 'ROBUST/1', 'Drive train/4');
L(pl, 'Drive train/1', 'Int Omega/1');
L(pl, 'vs*/1', 'PMSG dq/1');  L(pl, 'Int is/1', 'PMSG dq/2');
L(pl, 'Int Omega/1', 'PMSG dq/3');  L(pl, 'ROBUST/1', 'PMSG dq/4');
L(pl, 'PMSG dq/1', 'Int is/1');
L(pl, 'vs*/1', 'PWM rectifier (MSC)/1');  L(pl, 'Int is/1', 'PWM rectifier (MSC)/2');
L(pl, 'Int Vdc/1', 'PWM rectifier (MSC)/3');
L(pl, 'PWM rectifier (MSC)/1', 'DC bus/1');  L(pl, 'PWM inverter (GSC)/1', 'DC bus/2');
L(pl, 'Int Vdc/1', 'DC bus/3');  L(pl, 'DC bus/1', 'Int Vdc/1');
L(pl, 'vi*/1', 'PWM inverter (GSC)/1');  L(pl, 'Int ig/1', 'PWM inverter (GSC)/2');
L(pl, 'Int Vdc/1', 'PWM inverter (GSC)/3');
L(pl, 'vi*/1', 'L filter + grid/1');  L(pl, 'Int ig/1', 'L filter + grid/2');
L(pl, 'v_grid/1', 'L filter + grid/3');  L(pl, 'ROBUST/1', 'L filter + grid/4');
L(pl, 'L filter + grid/1', 'Int ig/1');
L(pl, 'Int is/1', 'is/1');  L(pl, 'Int Omega/1', 'Omega/1');  L(pl, 'Int Vdc/1', 'Vdc/1');
L(pl, 'Int ig/1', 'ig/1');  L(pl, 'Turbine/1', 'Tw/1');  L(pl, 'PMSG dq/2', 'Te/1');
L(pl, 'Turbine/2', 'Cp/1');  L(pl, 'L filter + grid/2', 'Pg/1');  L(pl, 'L filter + grid/3', 'Qg/1');
term(pl, 'T1', [720 60]);  L(pl, 'PWM rectifier (MSC)/2', 'T1/1');
term(pl, 'T2', [720 420]); L(pl, 'PWM inverter (GSC)/2', 'T2/1');
term(pl, 'T3', [280 230]); L(pl, 'Turbine/3', 'T3/1');

%% ========== PROPOSED CONTROL: flatness + PBC + adaptive ANN ===========
% m = [isd isq Omega Vdc igd igq vgd vgq v_wind] sampled at Ts (ZOH)
fc = [mdl '/Control: Flatness + PBC + ANN'];
newSub(fc, [330 640 560 760]);
inp(fc, 'm', 1, [20 200]);
cst(fc, 'ROBUST', 'ROBUST', [20 120]);  cst(fc, 'ANN_ON', 'ANN_ON', [20 420]);
mf(fc, 'MPPT', ...
  'function [wr, dwr] = fcn(m)\n[wr, dwr] = blk_mppt(m(9));', [120 30 220 80]);
mf(fc, 'Flatness: speed (y1 = Omega)', ['function [Tes, isqr, ew, satw] = fcn(wr, dwr, m, uAI, robust)\n' ...
  '[Tes, isqr, ew, satw] = blk_flat_speed(wr, dwr, m(3), m(9), uAI(1), robust);'], [300 30 440 130]);
mf(fc, 'PBC: rectifier currents', ['function [vs, es] = fcn(isqr, m)\n' ...
  '[vs, es] = blk_pbc_msc(isqr, m(1:2), m(3), m(4));'], [520 30 660 100]);
ud(fc, 'vs(k-1)', 'U0(1:2)', [700 160 730 190]);
mf(fc, 'Flatness: DC bus (y2 = energy)', ['function [igr, ey, satv] = fcn(m, vs_prev, uAI)\n' ...
  '[igr, ey, satv] = blk_flat_dc(m(4), m(1:2), vs_prev, m(5:6), m(7:8), uAI(2));'], [300 220 440 300]);
mf(fc, 'PBC: inverter currents', ['function vi = fcn(igr, m)\n' ...
  'vi = blk_pbc_gsc(igr, m(5:6), m(7:8), m(4));'], [520 220 660 290]);
mf(fc, 'Adaptive ANN 6-10-2', ['function uAI = fcn(ew, ey, es, satw, satv, on)\n' ...
  'uAI = blk_ann(ew, ey, es(2), satw, satv, on);'], [300 360 440 480]);
ud(fc, 'uAI(k-1)', '[0;0]', [500 400 530 430]);
outp(fc, 'vs', 1, [760 60]);  outp(fc, 'vi', 2, [760 250]);
outp(fc, 'Omega*', 3, [760 330]);  outp(fc, 'uAI', 4, [760 410]);
L(fc, 'm/1', 'MPPT/1');
L(fc, 'MPPT/1', 'Flatness: speed (y1 = Omega)/1');  L(fc, 'MPPT/2', 'Flatness: speed (y1 = Omega)/2');
L(fc, 'm/1', 'Flatness: speed (y1 = Omega)/3');  L(fc, 'uAI(k-1)/1', 'Flatness: speed (y1 = Omega)/4');
L(fc, 'ROBUST/1', 'Flatness: speed (y1 = Omega)/5');
L(fc, 'Flatness: speed (y1 = Omega)/2', 'PBC: rectifier currents/1');  L(fc, 'm/1', 'PBC: rectifier currents/2');
L(fc, 'PBC: rectifier currents/1', 'vs(k-1)/1');
L(fc, 'm/1', 'Flatness: DC bus (y2 = energy)/1');  L(fc, 'vs(k-1)/1', 'Flatness: DC bus (y2 = energy)/2');
L(fc, 'uAI(k-1)/1', 'Flatness: DC bus (y2 = energy)/3');
L(fc, 'Flatness: DC bus (y2 = energy)/1', 'PBC: inverter currents/1');  L(fc, 'm/1', 'PBC: inverter currents/2');
L(fc, 'Flatness: speed (y1 = Omega)/3', 'Adaptive ANN 6-10-2/1');
L(fc, 'Flatness: DC bus (y2 = energy)/2', 'Adaptive ANN 6-10-2/2');
L(fc, 'PBC: rectifier currents/2', 'Adaptive ANN 6-10-2/3');
L(fc, 'Flatness: speed (y1 = Omega)/4', 'Adaptive ANN 6-10-2/4');
L(fc, 'Flatness: DC bus (y2 = energy)/3', 'Adaptive ANN 6-10-2/5');
L(fc, 'ANN_ON/1', 'Adaptive ANN 6-10-2/6');
L(fc, 'Adaptive ANN 6-10-2/1', 'uAI(k-1)/1');
L(fc, 'PBC: rectifier currents/1', 'vs/1');  L(fc, 'PBC: inverter currents/1', 'vi/1');
L(fc, 'MPPT/1', 'Omega*/1');  L(fc, 'Adaptive ANN 6-10-2/1', 'uAI/1');
term(fc, 'T1', [480 120]);  L(fc, 'Flatness: speed (y1 = Omega)/1', 'T1/1');

%% ================= PI VECTOR CONTROL (comparison) =====================
pc = [mdl '/Control: PI vector control (comparison)'];
newSub(pc, [330 820 560 900]);
inp(pc, 'm', 1, [20 60]);  cst(pc, 'PI_FF', 'PI_FF', [20 140]);
mf(pc, 'PI controllers', ['function [vs, vi] = fcn(m, vs_prev, ff)\n' ...
  'v = blk_pi(m(9), m(1:2), m(3), m(4), m(5:6), m(7:8), vs_prev, ff);\nvs = v(1:2);  vi = v(3:4);'], ...
  [140 40 280 140]);
ud(pc, 'vs(k-1)', 'U0(1:2)', [140 200 170 230]);
outp(pc, 'vs', 1, [400 60]);  outp(pc, 'vi', 2, [400 120]);
L(pc, 'm/1', 'PI controllers/1');  L(pc, 'vs(k-1)/1', 'PI controllers/2');
L(pc, 'PI_FF/1', 'PI controllers/3');  L(pc, 'PI controllers/1', 'vs(k-1)/1');
L(pc, 'PI controllers/1', 'vs/1');  L(pc, 'PI controllers/2', 'vi/1');

%% ============================ TOP LEVEL ================================
add_block('simulink/Sources/Clock', [mdl '/Clock'], 'Position', [30 360 60 390]);
mf(mdl, 'Wind profile', 'function vw = fcn(t)\nvw = blk_wind(t);', [110 340 200 410]);
mf(mdl, 'Grid voltage (ideal PLL)', 'function vg = fcn(t, robust)\nvg = blk_grid(t, robust);', [110 460 200 530]);
cst(mdl, 'ROBUST', 'ROBUST', [30 500]);
add_block('simulink/Signal Routing/Mux', [mdl '/Measurements'], 'Inputs', '[2 1 1 2 2 1]', ...
  'Position', [680 610 690 790]);
add_block('simulink/Discrete/Zero-Order Hold', [mdl '/Sampling Ts'], 'SampleTime', 'P.Ts', ...
  'Position', [730 685 770 715]);
add_block('simulink/Signal Routing/Multiport Switch', [mdl '/Select vs*'], 'Inputs', '2', ...
  'Position', [200 600 230 700]);
add_block('simulink/Signal Routing/Multiport Switch', [mdl '/Select vi*'], 'Inputs', '2', ...
  'Position', [200 720 230 820]);
cst(mdl, 'CTRL_SEL', 'CTRL_SEL', [120 640]);
L(mdl, 'Clock/1', 'Wind profile/1');  L(mdl, 'Clock/1', 'Grid voltage (ideal PLL)/1');
L(mdl, 'ROBUST/1', 'Grid voltage (ideal PLL)/2');
P1 = 'Plant: Turbine-PMSG-Back-to-back-L filter-Grid';
F1 = 'Control: Flatness + PBC + ANN';  C1 = 'Control: PI vector control (comparison)';
L(mdl, 'Select vs*/1', [P1 '/1']);  L(mdl, 'Select vi*/1', [P1 '/2']);
L(mdl, 'Wind profile/1', [P1 '/3']); L(mdl, 'Grid voltage (ideal PLL)/1', [P1 '/4']);
L(mdl, [P1 '/1'], 'Measurements/1');  L(mdl, [P1 '/2'], 'Measurements/2');
L(mdl, [P1 '/3'], 'Measurements/3');  L(mdl, [P1 '/4'], 'Measurements/4');
L(mdl, 'Grid voltage (ideal PLL)/1', 'Measurements/5');  L(mdl, 'Wind profile/1', 'Measurements/6');
L(mdl, 'Measurements/1', 'Sampling Ts/1');
L(mdl, 'Sampling Ts/1', [F1 '/1']);  L(mdl, 'Sampling Ts/1', [C1 '/1']);
L(mdl, 'CTRL_SEL/1', 'Select vs*/1');  L(mdl, 'CTRL_SEL/1', 'Select vi*/1');
L(mdl, [C1 '/1'], 'Select vs*/2');  L(mdl, [F1 '/1'], 'Select vs*/3');
L(mdl, [C1 '/2'], 'Select vi*/2');  L(mdl, [F1 '/2'], 'Select vi*/3');

% logging (To Workspace, every 10 samples) and scopes
tw(mdl, 'x_log', [1050 330]);   tw(mdl, 'wr_log', [1050 650]);
tw(mdl, 'pq_log', [1050 450]);  tw(mdl, 'cp_log', [1050 400]);
tw(mdl, 'uai_log', [1050 720]); tw(mdl, 'vw_log', [300 250]);
add_block('simulink/Signal Routing/Mux', [mdl '/x'], 'Inputs', '[2 1 1 2]', 'Position', [880 300 890 380]);
add_block('simulink/Signal Routing/Mux', [mdl '/PQ'], 'Inputs', '2', 'Position', [880 440 890 480]);
L(mdl, [P1 '/1'], 'x/1');  L(mdl, [P1 '/2'], 'x/2');  L(mdl, [P1 '/3'], 'x/3');  L(mdl, [P1 '/4'], 'x/4');
L(mdl, 'x/1', 'x_log/1');  L(mdl, [P1 '/8'], 'PQ/1');  L(mdl, [P1 '/9'], 'PQ/2');
L(mdl, 'PQ/1', 'pq_log/1');  L(mdl, [P1 '/7'], 'cp_log/1');
L(mdl, [F1 '/3'], 'wr_log/1');  L(mdl, [F1 '/4'], 'uai_log/1');  L(mdl, 'Wind profile/1', 'vw_log/1');
sc(mdl, 'Scope Omega', 2, [1200 560]);  L(mdl, [P1 '/2'], 'Scope Omega/1');  L(mdl, [F1 '/3'], 'Scope Omega/2');
sc(mdl, 'Scope Vdc', 1, [1200 200]);    L(mdl, [P1 '/3'], 'Scope Vdc/1');
sc(mdl, 'Scope P Q', 1, [1200 460]);    L(mdl, 'PQ/1', 'Scope P Q/1');
sc(mdl, 'Scope torques', 2, [1200 330]); L(mdl, [P1 '/5'], 'Scope torques/1');  L(mdl, [P1 '/6'], 'Scope torques/2');
sc(mdl, 'Scope ANN', 1, [1200 720]);    L(mdl, [F1 '/4'], 'Scope ANN/1');

try   % title annotation (cosmetic)
  add_block('built-in/Note', [mdl '/' sprintf(['2 MW direct-drive PMSG - back-to-back PWM converters - L filter - 690 V grid\n' ...
    'CTRL_SEL: 1 = PI, 2 = Flatness+PBC(+ANN)  |  ANN_ON 0/1  |  PI_FF 0/1  |  ROBUST 0/1'])], ...
    'Position', [330 40 900 60]);
catch
end
save_system(mdl, fullfile(here, [mdl '.slx']));
fprintf('Model %s.slx created. Run: sim(''%s''); plot_simulink\n', mdl, mdl);
end

%% ------------------------------ helpers --------------------------------
function newSub(path, pos)
add_block('simulink/Ports & Subsystems/Subsystem', path, 'Position', pos);
Simulink.SubSystem.deleteContents(path);
end
function mf(sys, name, code, pos)
path = [sys '/' name];
add_block('simulink/User-Defined Functions/MATLAB Function', path, 'Position', pos);
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', path);
ch.Script = sprintf(code);
end
function inp(sys, name, k, xy)
add_block('simulink/Sources/In1', [sys '/' name], 'Port', num2str(k), ...
  'Position', [xy(1) xy(2) xy(1)+30 xy(2)+14]);
end
function outp(sys, name, k, xy)
add_block('simulink/Sinks/Out1', [sys '/' name], 'Port', num2str(k), ...
  'Position', [xy(1) xy(2) xy(1)+30 xy(2)+14]);
end
function cst(sys, name, val, xy)
add_block('simulink/Sources/Constant', [sys '/' name], 'Value', val, ...
  'Position', [xy(1) xy(2) xy(1)+60 xy(2)+24]);
end
function itg(sys, name, ic, pos)
add_block('simulink/Continuous/Integrator', [sys '/' name], 'InitialCondition', ic, 'Position', pos);
end
function ud(sys, name, ic, pos)
add_block('simulink/Discrete/Unit Delay', [sys '/' name], 'InitialCondition', ic, ...
  'SampleTime', 'P.Ts', 'Position', pos);
end
function term(sys, name, xy)
add_block('simulink/Sinks/Terminator', [sys '/' name], 'Position', [xy(1) xy(2) xy(1)+20 xy(2)+20]);
end
function tw(sys, var, xy)
add_block('simulink/Sinks/To Workspace', [sys '/' var], 'VariableName', var, ...
  'SaveFormat', 'Structure With Time', 'Decimation', '10', ...
  'Position', [xy(1) xy(2) xy(1)+80 xy(2)+26]);
end
function sc(sys, name, n, xy)
add_block('simulink/Sinks/Scope', [sys '/' name], 'NumInputPorts', num2str(n), ...
  'Position', [xy(1) xy(2) xy(1)+40 xy(2)+40]);
end
function L(sys, a, b)
add_line(sys, a, b, 'autorouting', 'on');
end
