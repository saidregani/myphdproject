function PMSG_WECS_simulink()
%% Creates ONE self-contained Simulink model, PMSG_WECS_blocks.slx, built only from standard
%% Simulink blocks (no MATLAB Function block). Parameters are stored inside the model (InitFcn).
%% Run this file once; then open PMSG_WECS_blocks.slx and press Run.
mdl = 'PMSG_WECS_blocks';
here = fileparts(mfilename('fullpath'));
INIT = { ...
  '%% Parameters of the Simulink model PMSG_WECS_blocks (run automatically by InitFcn)'
  '% Scenario selection (can be set in the Command Window before sim):'
  '%   scenario = ''step'' | ''nominal'' | ''robust'' ;  useANN = 1 | 0'
  'if ~exist(''scenario'', ''var''), scenario = ''robust''; end'
  'if ~exist(''useANN'', ''var''),   useANN = 1;         end'
  '%% Turbine'
  'rho = 1.225;  R = 40;  Pn = 2e6;  Wn = 2.23;  Tn = Pn/Wn;'
  'J = 2.8e6;  B = 1e3;  lopt = 8.1;  vn = Wn*R/lopt;'
  'lam_tab = linspace(1, 16, 301);'
  'li_tab  = 1./(1./lam_tab - 0.035);'
  'cp_tab  = max(0.5176*(116./li_tab - 5).*exp(-21./li_tab) + 0.0068*lam_tab, 0);'
  '%% PMSG (Hasan & Shatil, AJSE 2021, Table I)'
  'p = 26;  Rs = 0.78e-3;  Ls = 1.57e-3;  psi = 9.18;'
  '%% DC link, filter, grid'
  'C = 20e-3;  Vdcr = 1200;  Vgm = 690*sqrt(2/3);  wg = 2*pi*50;'
  'Lf = 0.15e-3;  Rf = 2e-3;  fsw = 2160;'
  'In = Pn/(1.5*Vgm);  Temax = 1.2*Tn;  Igmax = 1.3*In;  Wmin = 0.5*Wn;  Wmax = Wn;'
  '%% Sampling and simulation'
  'Ts = 1/(2*fsw);  Tend = 40;  Tlog = 10*Ts;'
  '%% Wind'
  'Vm = 8.5;  Aw = [1.5 0.2 0.3];  fw = [0.03 0.16 0.17];'
  'sig_t = 0.5;  tau_t = 1.5;  seed = 12345;  tau_a = 1.0;'
  'Tn_w = 4*Ts;  an = exp(-Tn_w/tau_t);  gn = sqrt(1 - an^2)*sig_t;'
  '%% Control'
  'wr = 1;  wW = 2;  k11 = 2*wW;  k12 = wW^2;  wv = 60;  k21 = 2*wv;  k22 = wv^2;'
  'wi = 500;  Ra = 2*wi*Ls - Rs;  Ki = wi^2*Ls;  Rb = 2*wi*Lf - Rf;  Kig = wi^2*Lf;'
  'taud = 2e-3;  kI = k12*(1 - useANN);'
  '[c1g, c2g] = meshgrid(linspace(0.5, 1.1, 5), linspace(0.5, 1.1, 5));'
  'c1 = c1g(:);  c2 = c2g(:);  b = 0.15;  Gam = 1e7;  sig = 0.02;'
  '%% True plant (robustness scenario: parameter mismatch + 50 % grid voltage dip)'
  'kTw = 1;  Jt = J;  Rst = Rs;  Lst = Ls;  psit = psi;  Rft = Rf;  Lft = Lf;  Bt = B;'
  'windStep = 0;  v0 = Vm;  kdip = 0;  tdip = 25;  ddip = 0.15;'
  'switch scenario'
  '  case ''step'''
  '    windStep = 1;  v0 = 9;'
  '  case ''robust'''
  '    kTw = 1.10;  Jt = 1.2*J;  Rst = 1.5*Rs;  Lst = 1.2*Ls;  psit = 0.95*psi;'
  '    Rft = 1.5*Rf;  Lft = 1.25*Lf;  kdip = 0.5;'
  'end'
  '%% Initial equilibrium (MPPT at v0, isd = 0, unity power factor)'
  'cpf  = @(l) max(0.5176*(116./(1./(1./l - 0.035)) - 5).*exp(-21./(1./(1./l - 0.035))) + 0.0068*l, 0);'
  'aero = @(W, v) 0.5*rho*pi*R^2*cpf(W*R/v)*v^3/W;'
  'W0   = min(max(lopt*v0/R, Wmin), Wmax);'
  'isq0 = -(kTw*aero(W0, v0) - Bt*W0)/(1.5*p*psit);'
  'we0  = p*W0;'
  'us0  = [-we0*Lst*isq0; Rst*isq0 + we0*psit];'
  'Pdc0 = -1.5*us0(2)*isq0;'
  'igd0 = (-Vgm + sqrt(Vgm^2 + 4*Rft*Pdc0/1.5))/(2*Rft);'
  'ui0  = [Rft*igd0 + Vgm; wg*Lft*igd0];'
  'Te0c = 1.5*p*psi*isq0;'
  'zW0  = (B*W0 - aero(W0, v0) - Te0c)/(J*k12) * (1 - useANN);' };
initCode = strjoin(INIT, newline);
if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist(fullfile(here, [mdl '.slx']), 'file'), delete(fullfile(here, [mdl '.slx'])); end
evalin('base', initCode);
new_system(mdl);  open_system(mdl);
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'Ts', ...
          'StopTime', 'Tend', 'InitFcn', initCode, 'ReturnWorkspaceOutputs', 'on');

%% Top level: plant on the first row, control below, signals linked by Goto/From tags
C = 'Control (flatness + PBC + RBF-ANN)';
mk_wind(mdl, 'Wind', [80 100 180 150]);
mk_turbine(mdl, 'Turbine', [380 100 480 220], 'kTw');
mk_pmsg(mdl, 'PMSG and shaft', [680 100 780 260]);
mk_dclink(mdl, 'DC link', [980 100 1080 400]);
mk_grid(mdl, 'L filter and grid', [1280 100 1380 290]);
mk_controller(mdl, C, [680 520 900 820]);
outs = {'Wind/1', 'v'; 'Turbine/1', 'Tw'; 'Turbine/2', 'Cp'; 'PMSG and shaft/1', 'isd';
        'PMSG and shaft/2', 'isq'; 'PMSG and shaft/3', 'W'; 'PMSG and shaft/4', 'Te'; 'DC link/1', 'Vdc';
        'L filter and grid/1', 'igd'; 'L filter and grid/2', 'igq'; 'L filter and grid/3', 'vgd';
        'L filter and grid/4', 'Pg'; 'L filter and grid/5', 'Qg'; [C '/1'], 'vsd'; [C '/2'], 'vsq';
        [C '/3'], 'vid'; [C '/4'], 'viq'; [C '/5'], 'Wr'; [C '/6'], 'isqr'; [C '/7'], 'igdr'; [C '/8'], 'Dh'};
for k = 1:size(outs, 1), tag_out(mdl, outs{k,1}, outs{k,2}); end
add_block('simulink/Sinks/Terminator', [mdl '/Term lambda'], 'Position', [520 182 535 197], 'ShowName', 'off');
add_line(mdl, 'Turbine/3', 'Term lambda/1');
ins = {'v', 'Turbine/1'; 'W', 'Turbine/2'; 'vsd', 'PMSG and shaft/1'; 'vsq', 'PMSG and shaft/2';
       'Tw', 'PMSG and shaft/3'; 'vsd', 'DC link/1'; 'vsq', 'DC link/2'; 'isd', 'DC link/3';
       'isq', 'DC link/4'; 'vid', 'DC link/5'; 'viq', 'DC link/6'; 'igd', 'DC link/7'; 'igq', 'DC link/8';
       'vid', 'L filter and grid/1'; 'viq', 'L filter and grid/2'; 'v', [C '/1']; 'W', [C '/2'];
       'isd', [C '/3']; 'isq', [C '/4']; 'Vdc', [C '/5']; 'igd', [C '/6']; 'igq', [C '/7']; 'vgd', [C '/8']};
for k = 1:size(ins, 1), tag_in(mdl, ins{k,1}, ins{k,2}); end

%% Measurements (right side): To Workspace and scopes fed by From tags
add_block('simulink/Sources/Clock', [mdl '/Clock'], 'Position', [1600 100 1630 130]);
add_block('simulink/Sinks/To Workspace', [mdl '/log_t'], 'Position', [1680 100 1750 130], ...
          'VariableName', 't', 'SaveFormat', 'Array', 'SampleTime', 'Tlog', 'MaxDataPoints', 'inf');
add_line(mdl, 'Clock/1', 'log_t/1');
logs = {'v', 'W', 'Wr', 'Tw', 'Cp', 'Te', 'isd', 'isq', 'isqr', 'Vdc', 'igd', 'igq', 'igdr', 'Pg', 'Qg', 'Dh'};
for k = 1:numel(logs)
  y = 100 + 45*k;
  add_block('simulink/Sinks/To Workspace', [mdl '/log_' logs{k}], 'Position', [1680 y 1750 y+30], ...
            'VariableName', logs{k}, 'SaveFormat', 'Array', 'SampleTime', 'Tlog', 'MaxDataPoints', 'inf');
  tag_in(mdl, logs{k}, ['log_' logs{k} '/1']);
end
scopes = {'Scope speed', 'W', 'Wr'; 'Scope isq', 'isq', 'isqr'; 'Scope igd', 'igd', 'igdr'; 'Scope powers', 'Pg', 'Qg'};
for k = 1:size(scopes, 1)
  y = 100 + 110*(k-1);
  add_block('simulink/Signal Routing/Mux', [mdl '/Mux ' scopes{k,1}], 'Inputs', '2', ...
            'Position', [2000 y 2005 y+50], 'ShowName', 'off');
  add_block('simulink/Sinks/Scope', [mdl '/' scopes{k,1}], 'Position', [2060 y+5 2100 y+45]);
  tag_in(mdl, scopes{k,2}, ['Mux ' scopes{k,1} '/1']);  tag_in(mdl, scopes{k,3}, ['Mux ' scopes{k,1} '/2']);
  add_line(mdl, ['Mux ' scopes{k,1} '/1'], [scopes{k,1} '/1']);
end
add_block('simulink/Sinks/Scope', [mdl '/Scope Vdc'], 'Position', [2060 545 2100 585]);
tag_in(mdl, 'Vdc', 'Scope Vdc/1');
add_block('simulink/Sinks/Scope', [mdl '/Scope ANN'], 'Position', [2060 645 2100 685]);
tag_in(mdl, 'Dh', 'Scope ANN/1');
try
  n1 = Simulink.Annotation(mdl, 'PLANT: wind, turbine, PMSG, back-to-back converter, DC link, L filter, grid');
  n1.Position = [80 60];
  n2 = Simulink.Annotation(mdl, 'CONTROL: MPPT, flatness (speed, DC link), PBC (MSC, GSC), RBF neural network');
  n2.Position = [680 480];
  n3 = Simulink.Annotation(mdl, 'MEASUREMENTS');
  n3.Position = [1600 60];
catch
end
colorize(mdl);
save_system(mdl, fullfile(here, [mdl '.slx']));
fprintf('Model %s.slx created in %s. Open it and press Run (scopes show the results).\n', mdl, here);
open_system(mdl);
end

%% ========================================================================
function s = subsys(parent, name, pos, ins, outs)
s = [parent '/' name];
add_block('simulink/Ports & Subsystems/Subsystem', s, 'Position', pos);
delete_line(s, 'In1/1', 'Out1/1');  delete_block([s '/In1']);  delete_block([s '/Out1']);
for k = 1:numel(ins)
  add_block('simulink/Sources/In1', [s '/' ins{k}], 'Port', num2str(k), 'Position', [20 40*k 50 40*k+14]);
end
for k = 1:numel(outs)
  add_block('simulink/Sinks/Out1', [s '/' outs{k}], 'Port', num2str(k), 'Position', [900 40*k 930 40*k+14]);
end
end

function b(s, name, lib, varargin)
persistent n
if isempty(n), n = 0; end
n = n + 1;  x = 100 + 110*mod(n, 7);  y = 30 + 60*mod(floor(n/7), 12);
add_block(lib, [s '/' name], 'Position', [x y x+60 y+34], varargin{:});
end

function w(s, a, c)
add_line(s, a, c, 'autorouting', 'on');
end

function arrange(s)
try, Simulink.BlockDiagram.arrangeSystem(s); catch, end
end

%% ========================================================================
function mk_wind(parent, name, pos)
s = subsys(parent, name, pos, {}, {'v'});
b(s, 'Vm', 'simulink/Sources/Constant', 'Value', 'Vm');
for k = 1:3
  b(s, sprintf('Harmonic %d', k), 'simulink/Sources/Sine Wave', 'Amplitude', sprintf('Aw(%d)', k), ...
    'Frequency', sprintf('2*pi*fw(%d)', k), 'Phase', '0', 'SampleTime', '0');
end
b(s, 'White noise', 'simulink/Sources/Random Number', 'Mean', '0', 'Variance', '1', 'Seed', 'seed', 'SampleTime', 'Tn_w');
b(s, 'Turbulence AR1', 'simulink/Discrete/Discrete Transfer Fcn', 'Numerator', '[gn 0]', 'Denominator', '[1 -an]', 'SampleTime', 'Tn_w');
b(s, 'Turbulent wind', 'simulink/Math Operations/Sum', 'Inputs', '+++++', 'IconShape', 'rectangular');
w(s, 'Vm/1', 'Turbulent wind/1');  w(s, 'Harmonic 1/1', 'Turbulent wind/2');
w(s, 'Harmonic 2/1', 'Turbulent wind/3');  w(s, 'Harmonic 3/1', 'Turbulent wind/4');
w(s, 'White noise/1', 'Turbulence AR1/1');  w(s, 'Turbulence AR1/1', 'Turbulent wind/5');
b(s, 'v base', 'simulink/Sources/Constant', 'Value', '9');
b(s, 'Step 10 s', 'simulink/Sources/Step', 'Time', '10', 'Before', '0', 'After', '2');
b(s, 'Step 25 s', 'simulink/Sources/Step', 'Time', '25', 'Before', '0', 'After', '-3');
b(s, 'Step wind', 'simulink/Math Operations/Sum', 'Inputs', '+++', 'IconShape', 'rectangular');
w(s, 'v base/1', 'Step wind/1');  w(s, 'Step 10 s/1', 'Step wind/2');  w(s, 'Step 25 s/1', 'Step wind/3');
b(s, 'windStep', 'simulink/Sources/Constant', 'Value', 'windStep');
b(s, 'Profile', 'simulink/Signal Routing/Switch', 'Criteria', 'u2 > Threshold', 'Threshold', '0.5');
w(s, 'Step wind/1', 'Profile/1');  w(s, 'windStep/1', 'Profile/2');  w(s, 'Turbulent wind/1', 'Profile/3');
w(s, 'Profile/1', 'v/1');
arrange(s);
end

%% ========================================================================
function mk_turbine(parent, name, pos, kname)
s = subsys(parent, name, pos, {'v', 'W'}, {'Tw', 'Cp', 'lambda'});
b(s, 'v min', 'simulink/Sources/Constant', 'Value', '0.1');
b(s, 'W min', 'simulink/Sources/Constant', 'Value', '0.05');
b(s, 'max v', 'simulink/Math Operations/MinMax', 'Function', 'max', 'Inputs', '2');
b(s, 'max W', 'simulink/Math Operations/MinMax', 'Function', 'max', 'Inputs', '2');
w(s, 'v/1', 'max v/1');  w(s, 'v min/1', 'max v/2');  w(s, 'W/1', 'max W/1');  w(s, 'W min/1', 'max W/2');
b(s, 'R', 'simulink/Math Operations/Gain', 'Gain', 'R');
b(s, 'lambda calc', 'simulink/Math Operations/Product', 'Inputs', '*/');
w(s, 'max W/1', 'R/1');  w(s, 'R/1', 'lambda calc/1');  w(s, 'max v/1', 'lambda calc/2');  w(s, 'lambda calc/1', 'lambda/1');
b(s, 'Cp(lambda)', 'simulink/Lookup Tables/1-D Lookup Table', 'Table', 'cp_tab', ...
  'BreakpointsForDimension1', 'lam_tab', 'ExtrapMethod', 'Clip');
b(s, 'k Cp', 'simulink/Math Operations/Gain', 'Gain', kname);
w(s, 'lambda calc/1', 'Cp(lambda)/1');  w(s, 'Cp(lambda)/1', 'k Cp/1');  w(s, 'k Cp/1', 'Cp/1');
b(s, 'Cp v3 over W', 'simulink/Math Operations/Product', 'Inputs', '****/');
b(s, '0.5 rho pi R^2', 'simulink/Math Operations/Gain', 'Gain', '0.5*rho*pi*R^2');
w(s, 'k Cp/1', 'Cp v3 over W/1');  w(s, 'max v/1', 'Cp v3 over W/2');  w(s, 'max v/1', 'Cp v3 over W/3');
w(s, 'max v/1', 'Cp v3 over W/4');  w(s, 'max W/1', 'Cp v3 over W/5');
w(s, 'Cp v3 over W/1', '0.5 rho pi R^2/1');  w(s, '0.5 rho pi R^2/1', 'Tw/1');
arrange(s);
end

%% ========================================================================
function mk_pmsg(parent, name, pos)
% receptor convention: Ls disd/dt = vsd - Rs isd + we Ls isq
%                      Ls disq/dt = vsq - Rs isq - we Ls isd - we psi
%                      J dW/dt = Tw + Te - B W,  Te = 1.5 p psi isq
s = subsys(parent, name, pos, {'vsd', 'vsq', 'Tw'}, {'isd', 'isq', 'W', 'Te'});
b(s, 'Int isd', 'simulink/Continuous/Integrator', 'InitialCondition', '0');
b(s, 'Int isq', 'simulink/Continuous/Integrator', 'InitialCondition', 'isq0');
b(s, 'Int W', 'simulink/Continuous/Integrator', 'InitialCondition', 'W0');
b(s, 'p', 'simulink/Math Operations/Gain', 'Gain', 'p');
w(s, 'Int W/1', 'p/1');
b(s, 'we*isq', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'Ls we isq', 'simulink/Math Operations/Gain', 'Gain', 'Lst');
b(s, 'Rs isd', 'simulink/Math Operations/Gain', 'Gain', 'Rst');
b(s, 'sum d', 'simulink/Math Operations/Sum', 'Inputs', '+-+', 'IconShape', 'rectangular');
b(s, 'inv Ls d', 'simulink/Math Operations/Gain', 'Gain', '1/Lst');
w(s, 'p/1', 'we*isq/1');  w(s, 'Int isq/1', 'we*isq/2');  w(s, 'we*isq/1', 'Ls we isq/1');
w(s, 'Int isd/1', 'Rs isd/1');
w(s, 'vsd/1', 'sum d/1');  w(s, 'Rs isd/1', 'sum d/2');  w(s, 'Ls we isq/1', 'sum d/3');
w(s, 'sum d/1', 'inv Ls d/1');  w(s, 'inv Ls d/1', 'Int isd/1');
b(s, 'we*isd', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'Ls we isd', 'simulink/Math Operations/Gain', 'Gain', 'Lst');
b(s, 'psi we', 'simulink/Math Operations/Gain', 'Gain', 'psit');
b(s, 'Rs isq', 'simulink/Math Operations/Gain', 'Gain', 'Rst');
b(s, 'sum q', 'simulink/Math Operations/Sum', 'Inputs', '+---', 'IconShape', 'rectangular');
b(s, 'inv Ls q', 'simulink/Math Operations/Gain', 'Gain', '1/Lst');
w(s, 'p/1', 'we*isd/1');  w(s, 'Int isd/1', 'we*isd/2');  w(s, 'we*isd/1', 'Ls we isd/1');
w(s, 'p/1', 'psi we/1');  w(s, 'Int isq/1', 'Rs isq/1');
w(s, 'vsq/1', 'sum q/1');  w(s, 'Rs isq/1', 'sum q/2');  w(s, 'Ls we isd/1', 'sum q/3');  w(s, 'psi we/1', 'sum q/4');
w(s, 'sum q/1', 'inv Ls q/1');  w(s, 'inv Ls q/1', 'Int isq/1');
b(s, 'Te = 1.5 p psi isq', 'simulink/Math Operations/Gain', 'Gain', '1.5*p*psit');
b(s, 'B W', 'simulink/Math Operations/Gain', 'Gain', 'Bt');
b(s, 'sum mech', 'simulink/Math Operations/Sum', 'Inputs', '++-', 'IconShape', 'rectangular');
b(s, 'inv J', 'simulink/Math Operations/Gain', 'Gain', '1/Jt');
w(s, 'Int isq/1', 'Te = 1.5 p psi isq/1');  w(s, 'Int W/1', 'B W/1');
w(s, 'Tw/1', 'sum mech/1');  w(s, 'Te = 1.5 p psi isq/1', 'sum mech/2');  w(s, 'B W/1', 'sum mech/3');
w(s, 'sum mech/1', 'inv J/1');  w(s, 'inv J/1', 'Int W/1');
w(s, 'Int isd/1', 'isd/1');  w(s, 'Int isq/1', 'isq/1');  w(s, 'Int W/1', 'W/1');  w(s, 'Te = 1.5 p psi isq/1', 'Te/1');
arrange(s);
end

%% ========================================================================
function mk_dclink(parent, name, pos)
% C Vdc dVdc/dt = Pdc - Pi, Pdc = -1.5 (vsd isd + vsq isq), Pi = 1.5 (vid igd + viq igq)
s = subsys(parent, name, pos, {'vsd', 'vsq', 'isd', 'isq', 'vid', 'viq', 'igd', 'igq'}, {'Vdc'});
b(s, 'vsd isd', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'vsq isq', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'vid igd', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'viq igq', 'simulink/Math Operations/Product', 'Inputs', '**');
w(s, 'vsd/1', 'vsd isd/1');  w(s, 'isd/1', 'vsd isd/2');  w(s, 'vsq/1', 'vsq isq/1');  w(s, 'isq/1', 'vsq isq/2');
w(s, 'vid/1', 'vid igd/1');  w(s, 'igd/1', 'vid igd/2');  w(s, 'viq/1', 'viq igq/1');  w(s, 'igq/1', 'viq igq/2');
b(s, 'sum s', 'simulink/Math Operations/Sum', 'Inputs', '++', 'IconShape', 'rectangular');
b(s, 'sum g', 'simulink/Math Operations/Sum', 'Inputs', '++', 'IconShape', 'rectangular');
b(s, 'Pdc', 'simulink/Math Operations/Gain', 'Gain', '-1.5');
b(s, 'Pi', 'simulink/Math Operations/Gain', 'Gain', '1.5');
w(s, 'vsd isd/1', 'sum s/1');  w(s, 'vsq isq/1', 'sum s/2');  w(s, 'sum s/1', 'Pdc/1');
w(s, 'vid igd/1', 'sum g/1');  w(s, 'viq igq/1', 'sum g/2');  w(s, 'sum g/1', 'Pi/1');
b(s, 'Pdc - Pi', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'div Vdc', 'simulink/Math Operations/Product', 'Inputs', '*/');
b(s, 'inv C', 'simulink/Math Operations/Gain', 'Gain', '1/C');
b(s, 'Int Vdc', 'simulink/Continuous/Integrator', 'InitialCondition', 'Vdcr');
w(s, 'Pdc/1', 'Pdc - Pi/1');  w(s, 'Pi/1', 'Pdc - Pi/2');  w(s, 'Pdc - Pi/1', 'div Vdc/1');  w(s, 'Int Vdc/1', 'div Vdc/2');
w(s, 'div Vdc/1', 'inv C/1');  w(s, 'inv C/1', 'Int Vdc/1');  w(s, 'Int Vdc/1', 'Vdc/1');
arrange(s);
end

%% ========================================================================
function mk_grid(parent, name, pos)
% Lf digd/dt = vid - Rf igd + wg Lf igq - vgd ;  Lf digq/dt = viq - Rf igq - wg Lf igd  (vgq = 0)
s = subsys(parent, name, pos, {'vid', 'viq'}, {'igd', 'igq', 'vgd', 'Pg', 'Qg'});
b(s, 'Dip start', 'simulink/Sources/Step', 'Time', 'tdip', 'Before', '0', 'After', '1');
b(s, 'Dip end', 'simulink/Sources/Step', 'Time', 'tdip+ddip', 'Before', '0', 'After', '1');
b(s, 'dip window', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'kdip', 'simulink/Math Operations/Gain', 'Gain', 'kdip');
b(s, 'one', 'simulink/Sources/Constant', 'Value', '1');
b(s, '1 - dip', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'Vgm', 'simulink/Math Operations/Gain', 'Gain', 'Vgm');
w(s, 'Dip start/1', 'dip window/1');  w(s, 'Dip end/1', 'dip window/2');  w(s, 'dip window/1', 'kdip/1');
w(s, 'one/1', '1 - dip/1');  w(s, 'kdip/1', '1 - dip/2');  w(s, '1 - dip/1', 'Vgm/1');  w(s, 'Vgm/1', 'vgd/1');
b(s, 'Int igd', 'simulink/Continuous/Integrator', 'InitialCondition', 'igd0');
b(s, 'Int igq', 'simulink/Continuous/Integrator', 'InitialCondition', '0');
b(s, 'Rf igd', 'simulink/Math Operations/Gain', 'Gain', 'Rft');
b(s, 'wLf igq', 'simulink/Math Operations/Gain', 'Gain', 'wg*Lft');
b(s, 'sum d', 'simulink/Math Operations/Sum', 'Inputs', '+-+-', 'IconShape', 'rectangular');
b(s, 'inv Lf d', 'simulink/Math Operations/Gain', 'Gain', '1/Lft');
w(s, 'Int igd/1', 'Rf igd/1');  w(s, 'Int igq/1', 'wLf igq/1');
w(s, 'vid/1', 'sum d/1');  w(s, 'Rf igd/1', 'sum d/2');  w(s, 'wLf igq/1', 'sum d/3');  w(s, 'Vgm/1', 'sum d/4');
w(s, 'sum d/1', 'inv Lf d/1');  w(s, 'inv Lf d/1', 'Int igd/1');
b(s, 'Rf igq', 'simulink/Math Operations/Gain', 'Gain', 'Rft');
b(s, 'wLf igd', 'simulink/Math Operations/Gain', 'Gain', 'wg*Lft');
b(s, 'sum q', 'simulink/Math Operations/Sum', 'Inputs', '+--', 'IconShape', 'rectangular');
b(s, 'inv Lf q', 'simulink/Math Operations/Gain', 'Gain', '1/Lft');
w(s, 'Int igq/1', 'Rf igq/1');  w(s, 'Int igd/1', 'wLf igd/1');
w(s, 'viq/1', 'sum q/1');  w(s, 'Rf igq/1', 'sum q/2');  w(s, 'wLf igd/1', 'sum q/3');
w(s, 'sum q/1', 'inv Lf q/1');  w(s, 'inv Lf q/1', 'Int igq/1');
b(s, 'vgd igd', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'vgd igq', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'Pg = 1.5 vgd igd', 'simulink/Math Operations/Gain', 'Gain', '1.5');
b(s, 'Qg = -1.5 vgd igq', 'simulink/Math Operations/Gain', 'Gain', '-1.5');
w(s, 'Vgm/1', 'vgd igd/1');  w(s, 'Int igd/1', 'vgd igd/2');  w(s, 'vgd igd/1', 'Pg = 1.5 vgd igd/1');
w(s, 'Vgm/1', 'vgd igq/1');  w(s, 'Int igq/1', 'vgd igq/2');  w(s, 'vgd igq/1', 'Qg = -1.5 vgd igq/1');
w(s, 'Int igd/1', 'igd/1');  w(s, 'Int igq/1', 'igq/1');
w(s, 'Pg = 1.5 vgd igd/1', 'Pg/1');  w(s, 'Qg = -1.5 vgd igq/1', 'Qg/1');
arrange(s);
end

%% ========================================================================
function mk_controller(parent, name, pos)
s = subsys(parent, name, pos, {'v', 'W', 'isd', 'isq', 'Vdc', 'igd', 'igq', 'vgd'}, ...
           {'vsd', 'vsq', 'vid', 'viq', 'Wr', 'isqr', 'igdr', 'Dh'});
outs = {'vsd', 'vsq', 'vid', 'viq', 'Wr', 'isqr', 'igdr', 'Dh'};
for k = 1:numel(outs), set_param([s '/' outs{k}], 'Position', [1500 40+60*k 1530 54+60*k]); end
ins = {'v', 'W', 'isd', 'isq', 'Vdc', 'igd', 'igq', 'vgd'};
for k = 1:numel(ins), set_param([s '/' ins{k}], 'Position', [20 40+60*k 50 54+60*k]); end
mk_mppt(s, 'MPPT reference', [250 60 350 170]);
mk_turbine(s, 'Turbine model', [250 260 350 380], '1');
mk_rbf(s, 'RBF network', [250 470 350 610]);
mk_speed(s, 'Flatness speed loop', [650 60 750 250]);
mk_dcloop(s, 'Flatness DC-link loop', [650 330 750 650]);
mk_pbc_msc(s, 'PBC machine side', [1000 60 1100 240]);
mk_pbc_gsc(s, 'PBC grid side', [1000 330 1100 510]);
nm = {'Delay vsd', 'Delay vsq', 'Delay vid', 'Delay viq'};  ic = {'us0(1)', 'us0(2)', 'ui0(1)', 'ui0(2)'};
for k = 1:4
  add_block('simulink/Discrete/Unit Delay', [s '/' nm{k}], 'InitialCondition', ic{k}, 'SampleTime', 'Ts', ...
            'Position', [1300 80+90*k 1340 110+90*k]);
end
add_block('simulink/Sinks/Terminator', [s '/T1'], 'Position', [420 330 435 345], 'ShowName', 'off');
add_block('simulink/Sinks/Terminator', [s '/T2'], 'Position', [420 360 435 375], 'ShowName', 'off');
add_line(s, 'Turbine model/2', 'T1/1');  add_line(s, 'Turbine model/3', 'T2/1');
src = {'v/1', 'v'; 'W/1', 'W'; 'isd/1', 'isd'; 'isq/1', 'isq'; 'Vdc/1', 'Vdc'; 'igd/1', 'igd';
       'igq/1', 'igq'; 'vgd/1', 'vgd'; 'MPPT reference/1', 'vm'; 'MPPT reference/2', 'Wr';
       'MPPT reference/3', 'dWr'; 'Turbine model/1', 'Twh'; 'RBF network/1', 'Dh';
       'Flatness speed loop/1', 'isqr'; 'Flatness speed loop/2', 'eW'; 'Flatness speed loop/3', 'enW';
       'Flatness DC-link loop/1', 'igdr'; 'PBC machine side/1', 'vsd_c'; 'PBC machine side/2', 'vsq_c';
       'PBC grid side/1', 'vid_c'; 'PBC grid side/2', 'viq_c'; 'PBC grid side/3', 'igf';
       'Delay vsd/1', 'vsd_a'; 'Delay vsq/1', 'vsq_a'; 'Delay vid/1', 'vid_a'; 'Delay viq/1', 'viq_a'};
for k = 1:size(src, 1), tag_out(s, src{k,1}, src{k,2}); end
dst = {'v', 'MPPT reference/1'; 'vm', 'Turbine model/1'; 'W', 'Turbine model/2';
       'W', 'RBF network/1'; 'vm', 'RBF network/2'; 'eW', 'RBF network/3'; 'enW', 'RBF network/4';
       'W', 'Flatness speed loop/1'; 'Wr', 'Flatness speed loop/2'; 'dWr', 'Flatness speed loop/3';
       'Twh', 'Flatness speed loop/4'; 'Dh', 'Flatness speed loop/5';
       'Vdc', 'Flatness DC-link loop/1'; 'igd', 'Flatness DC-link loop/2'; 'igq', 'Flatness DC-link loop/3';
       'isd', 'Flatness DC-link loop/4'; 'isq', 'Flatness DC-link loop/5'; 'vsd_a', 'Flatness DC-link loop/6';
       'vsq_a', 'Flatness DC-link loop/7'; 'vgd', 'Flatness DC-link loop/8'; 'igf', 'Flatness DC-link loop/9';
       'isd', 'PBC machine side/1'; 'isq', 'PBC machine side/2'; 'isqr', 'PBC machine side/3';
       'W', 'PBC machine side/4'; 'Vdc', 'PBC machine side/5';
       'igd', 'PBC grid side/1'; 'igq', 'PBC grid side/2'; 'igdr', 'PBC grid side/3';
       'vgd', 'PBC grid side/4'; 'Vdc', 'PBC grid side/5';
       'vsd_c', 'Delay vsd/1'; 'vsq_c', 'Delay vsq/1'; 'vid_c', 'Delay vid/1'; 'viq_c', 'Delay viq/1';
       'vsd_a', 'vsd/1'; 'vsq_a', 'vsq/1'; 'vid_a', 'vid/1'; 'viq_a', 'viq/1';
       'Wr', 'Wr/1'; 'isqr', 'isqr/1'; 'igdr', 'igdr/1'; 'Dh', 'Dh/1'};
for k = 1:size(dst, 1), tag_in(s, dst{k,1}, dst{k,2}); end
end

function mk_mppt(parent, name, pos)
% anemometer (first-order lag), W_opt = lopt vm / R, second-order reference filter
s = subsys(parent, name, pos, {'v'}, {'vm', 'Wr', 'dWr'});
b(s, 'Int vm', 'simulink/Continuous/Integrator', 'InitialCondition', 'v0');
b(s, 'v - vm', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'inv tau_a', 'simulink/Math Operations/Gain', 'Gain', '1/tau_a');
w(s, 'v/1', 'v - vm/1');  w(s, 'Int vm/1', 'v - vm/2');  w(s, 'v - vm/1', 'inv tau_a/1');  w(s, 'inv tau_a/1', 'Int vm/1');
b(s, 'lopt over R', 'simulink/Math Operations/Gain', 'Gain', 'lopt/R');
b(s, 'W limits', 'simulink/Discontinuities/Saturation', 'UpperLimit', 'Wmax', 'LowerLimit', 'Wmin');
w(s, 'Int vm/1', 'lopt over R/1');  w(s, 'lopt over R/1', 'W limits/1');
b(s, 'Int Wr', 'simulink/Continuous/Integrator', 'InitialCondition', 'W0');
b(s, 'Int dWr', 'simulink/Continuous/Integrator', 'InitialCondition', '0');
b(s, 'Wopt - Wr', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'wr^2', 'simulink/Math Operations/Gain', 'Gain', 'wr^2');
b(s, '2 wr', 'simulink/Math Operations/Gain', 'Gain', '2*wr');
b(s, 'ddWr', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
w(s, 'W limits/1', 'Wopt - Wr/1');  w(s, 'Int Wr/1', 'Wopt - Wr/2');  w(s, 'Wopt - Wr/1', 'wr^2/1');
w(s, 'Int dWr/1', '2 wr/1');  w(s, 'wr^2/1', 'ddWr/1');  w(s, '2 wr/1', 'ddWr/2');
w(s, 'ddWr/1', 'Int dWr/1');  w(s, 'Int dWr/1', 'Int Wr/1');
w(s, 'Int vm/1', 'vm/1');  w(s, 'Int Wr/1', 'Wr/1');  w(s, 'Int dWr/1', 'dWr/1');
arrange(s);
end

function gate(s, name, ic)
% discrete integrator (forward Euler, Ts) whose input is multiplied by an enable signal
b(s, [name ' gate'], 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, name, 'simulink/Discrete/Discrete-Time Integrator', 'IntegratorMethod', 'Integration: Forward Euler', ...
  'InitialCondition', ic, 'SampleTime', 'Ts');
w(s, [name ' gate/1'], [name '/1']);
end

function satflag(s, name, a, c)
% enable = 1 - (a ~= c)
b(s, [name ' ~='], 'simulink/Logic and Bit Operations/Relational Operator', 'Operator', '~=');
b(s, [name ' dbl'], 'simulink/Signal Attributes/Data Type Conversion', 'OutDataTypeStr', 'double');
b(s, [name ' one'], 'simulink/Sources/Constant', 'Value', '1');
b(s, name, 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
w(s, a, [name ' ~=/1']);  w(s, c, [name ' ~=/2']);  w(s, [name ' ~=/1'], [name ' dbl/1']);
w(s, [name ' one/1'], [name '/1']);  w(s, [name ' dbl/1'], [name '/2']);
end

function mk_speed(parent, name, pos)
% Te* = J nu1 + B W - Tw_hat - D_hat, nu1 = dWr - k11 eW - kI int(eW), isq* = Te*/(1.5 p psi)
s = subsys(parent, name, pos, {'W', 'Wr', 'dWr', 'Twh', 'Dh'}, {'isqr', 'eW', 'enW'});
b(s, 'W - Wr', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
w(s, 'W/1', 'W - Wr/1');  w(s, 'Wr/1', 'W - Wr/2');
gate(s, 'zW', 'zW0');
b(s, 'k11', 'simulink/Math Operations/Gain', 'Gain', 'k11');
b(s, 'kI', 'simulink/Math Operations/Gain', 'Gain', 'kI');
b(s, 'nu1', 'simulink/Math Operations/Sum', 'Inputs', '+--', 'IconShape', 'rectangular');
w(s, 'W - Wr/1', 'zW gate/1');  w(s, 'W - Wr/1', 'k11/1');  w(s, 'zW/1', 'kI/1');
w(s, 'dWr/1', 'nu1/1');  w(s, 'k11/1', 'nu1/2');  w(s, 'kI/1', 'nu1/3');
b(s, 'J', 'simulink/Math Operations/Gain', 'Gain', 'J');
b(s, 'B', 'simulink/Math Operations/Gain', 'Gain', 'B');
b(s, 'Te*', 'simulink/Math Operations/Sum', 'Inputs', '++--', 'IconShape', 'rectangular');
w(s, 'nu1/1', 'J/1');  w(s, 'W/1', 'B/1');
w(s, 'J/1', 'Te*/1');  w(s, 'B/1', 'Te*/2');  w(s, 'Twh/1', 'Te*/3');  w(s, 'Dh/1', 'Te*/4');
b(s, 'Te limits', 'simulink/Discontinuities/Saturation', 'UpperLimit', '0', 'LowerLimit', '-Temax');
w(s, 'Te*/1', 'Te limits/1');
satflag(s, 'en speed', 'Te*/1', 'Te limits/1');
w(s, 'en speed/1', 'zW gate/2');
b(s, 'Te to isq', 'simulink/Math Operations/Gain', 'Gain', '1/(1.5*p*psi)');
w(s, 'Te limits/1', 'Te to isq/1');
w(s, 'Te to isq/1', 'isqr/1');  w(s, 'W - Wr/1', 'eW/1');  w(s, 'en speed/1', 'enW/1');
arrange(s);
end

function mk_rbf(parent, name, pos)
% phi_j = exp(-((W/Wn - c1j)^2 + (vm/vn - c2j)^2)/(2 b^2)), D_hat = W_hat' phi,
% dW_hat/dt = Gam (phi eW - sig W_hat), frozen when Te* saturates
s = subsys(parent, name, pos, {'W', 'vm', 'eW', 'enW'}, {'Dh'});
b(s, 'z1', 'simulink/Math Operations/Gain', 'Gain', '1/Wn');
b(s, 'z2', 'simulink/Math Operations/Gain', 'Gain', '1/vn');
b(s, 'c1', 'simulink/Sources/Constant', 'Value', 'c1');
b(s, 'c2', 'simulink/Sources/Constant', 'Value', 'c2');
b(s, 'z1 - c1', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'z2 - c2', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'sq1', 'simulink/Math Operations/Math Function', 'Operator', 'square');
b(s, 'sq2', 'simulink/Math Operations/Math Function', 'Operator', 'square');
b(s, 'dist', 'simulink/Math Operations/Sum', 'Inputs', '++', 'IconShape', 'rectangular');
b(s, 'gauss gain', 'simulink/Math Operations/Gain', 'Gain', '-1/(2*b^2)');
b(s, 'phi', 'simulink/Math Operations/Math Function', 'Operator', 'exp');
w(s, 'W/1', 'z1/1');  w(s, 'vm/1', 'z2/1');
w(s, 'z1/1', 'z1 - c1/1');  w(s, 'c1/1', 'z1 - c1/2');  w(s, 'z2/1', 'z2 - c2/1');  w(s, 'c2/1', 'z2 - c2/2');
w(s, 'z1 - c1/1', 'sq1/1');  w(s, 'z2 - c2/1', 'sq2/1');  w(s, 'sq1/1', 'dist/1');  w(s, 'sq2/1', 'dist/2');
w(s, 'dist/1', 'gauss gain/1');  w(s, 'gauss gain/1', 'phi/1');
gate(s, 'W_hat', 'zeros(25,1)');
b(s, 'D_hat', 'simulink/Math Operations/Dot Product');
b(s, 'useANN', 'simulink/Math Operations/Gain', 'Gain', 'useANN');
w(s, 'W_hat/1', 'D_hat/1');  w(s, 'phi/1', 'D_hat/2');  w(s, 'D_hat/1', 'useANN/1');  w(s, 'useANN/1', 'Dh/1');
b(s, 'phi eW', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'Gam', 'simulink/Math Operations/Gain', 'Gain', 'Gam');
b(s, 'sig', 'simulink/Math Operations/Gain', 'Gain', 'sig');
b(s, 'dW', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
w(s, 'phi/1', 'phi eW/1');  w(s, 'eW/1', 'phi eW/2');  w(s, 'phi eW/1', 'Gam/1');
w(s, 'W_hat/1', 'sig/1');  w(s, 'Gam/1', 'dW/1');  w(s, 'sig/1', 'dW/2');
w(s, 'dW/1', 'W_hat gate/1');  w(s, 'enW/1', 'W_hat gate/2');
arrange(s);
end

function mk_dcloop(parent, name, pos)
% y2 = 0.5 C Vdc^2 + 0.75 Lf |ig|^2 ; Pg* = Pdc - 1.5 Rf |ig|^2 + k21 ey + k22 int(ey) ; igd* = 2 Pg*/(3 vgd)
s = subsys(parent, name, pos, {'Vdc', 'igd', 'igq', 'isd', 'isq', 'vsd', 'vsq', 'vgd', 'igf'}, {'igdr'});
b(s, 'vsd isd', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'vsq isq', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'sum p', 'simulink/Math Operations/Sum', 'Inputs', '++', 'IconShape', 'rectangular');
b(s, 'Pdc', 'simulink/Math Operations/Gain', 'Gain', '-1.5');
w(s, 'vsd/1', 'vsd isd/1');  w(s, 'isd/1', 'vsd isd/2');  w(s, 'vsq/1', 'vsq isq/1');  w(s, 'isq/1', 'vsq isq/2');
w(s, 'vsd isd/1', 'sum p/1');  w(s, 'vsq isq/1', 'sum p/2');  w(s, 'sum p/1', 'Pdc/1');
b(s, 'igd^2', 'simulink/Math Operations/Math Function', 'Operator', 'square');
b(s, 'igq^2', 'simulink/Math Operations/Math Function', 'Operator', 'square');
b(s, '|ig|^2', 'simulink/Math Operations/Sum', 'Inputs', '++', 'IconShape', 'rectangular');
w(s, 'igd/1', 'igd^2/1');  w(s, 'igq/1', 'igq^2/1');  w(s, 'igd^2/1', '|ig|^2/1');  w(s, 'igq^2/1', '|ig|^2/2');
b(s, 'Vdc^2', 'simulink/Math Operations/Math Function', 'Operator', 'square');
b(s, '0.5 C', 'simulink/Math Operations/Gain', 'Gain', '0.5*C');
b(s, '0.75 Lf', 'simulink/Math Operations/Gain', 'Gain', '0.75*Lf');
b(s, 'y2', 'simulink/Math Operations/Sum', 'Inputs', '++', 'IconShape', 'rectangular');
w(s, 'Vdc/1', 'Vdc^2/1');  w(s, 'Vdc^2/1', '0.5 C/1');  w(s, '|ig|^2/1', '0.75 Lf/1');
w(s, '0.5 C/1', 'y2/1');  w(s, '0.75 Lf/1', 'y2/2');
b(s, 'igf^2', 'simulink/Math Operations/Math Function', 'Operator', 'square');
b(s, '0.75 Lf r', 'simulink/Math Operations/Gain', 'Gain', '0.75*Lf');
b(s, '0.5 C Vdc*^2', 'simulink/Sources/Constant', 'Value', '0.5*C*Vdcr^2');
b(s, 'y2*', 'simulink/Math Operations/Sum', 'Inputs', '++', 'IconShape', 'rectangular');
w(s, 'igf/1', 'igf^2/1');  w(s, 'igf^2/1', '0.75 Lf r/1');
w(s, '0.5 C Vdc*^2/1', 'y2*/1');  w(s, '0.75 Lf r/1', 'y2*/2');
b(s, 'ey', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
w(s, 'y2/1', 'ey/1');  w(s, 'y2*/1', 'ey/2');
gate(s, 'zy', '0');
b(s, 'k21', 'simulink/Math Operations/Gain', 'Gain', 'k21');
b(s, 'k22', 'simulink/Math Operations/Gain', 'Gain', 'k22');
b(s, '1.5 Rf', 'simulink/Math Operations/Gain', 'Gain', '1.5*Rf');
b(s, 'Pg*', 'simulink/Math Operations/Sum', 'Inputs', '+-++', 'IconShape', 'rectangular');
w(s, 'ey/1', 'zy gate/1');  w(s, 'ey/1', 'k21/1');  w(s, 'zy/1', 'k22/1');  w(s, '|ig|^2/1', '1.5 Rf/1');
w(s, 'Pdc/1', 'Pg*/1');  w(s, '1.5 Rf/1', 'Pg*/2');  w(s, 'k21/1', 'Pg*/3');  w(s, 'k22/1', 'Pg*/4');
b(s, 'Pg* div vgd', 'simulink/Math Operations/Product', 'Inputs', '*/');
b(s, 'two thirds', 'simulink/Math Operations/Gain', 'Gain', '2/3');
b(s, 'igd limits', 'simulink/Discontinuities/Saturation', 'UpperLimit', 'Igmax', 'LowerLimit', '-Igmax');
w(s, 'Pg*/1', 'Pg* div vgd/1');  w(s, 'vgd/1', 'Pg* div vgd/2');  w(s, 'Pg* div vgd/1', 'two thirds/1');  w(s, 'two thirds/1', 'igd limits/1');
satflag(s, 'enV', 'two thirds/1', 'igd limits/1');
w(s, 'enV/1', 'zy gate/2');  w(s, 'igd limits/1', 'igdr/1');
arrange(s);
end

function vlimit(s, vin, en_dst, vout_name)
% |v| <= Vdc/sqrt(3): k = min(1, (Vdc/sqrt(3))/|v|), v_lim = k v, enable = 1 - (k < 1)
b(s, 'v.^2', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'sum v2', 'simulink/Math Operations/Sum of Elements');
b(s, '|v|', 'simulink/Math Operations/Sqrt');
b(s, 'eps', 'simulink/Sources/Constant', 'Value', '1e-6');
b(s, 'max |v|', 'simulink/Math Operations/MinMax', 'Function', 'max', 'Inputs', '2');
b(s, 'Vdc over sqrt3', 'simulink/Math Operations/Gain', 'Gain', '1/sqrt(3)');
b(s, 'ratio', 'simulink/Math Operations/Product', 'Inputs', '*/');
b(s, 'one k', 'simulink/Sources/Constant', 'Value', '1');
b(s, 'k', 'simulink/Math Operations/MinMax', 'Function', 'min', 'Inputs', '2');
b(s, vout_name, 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'k<1', 'simulink/Logic and Bit Operations/Relational Operator', 'Operator', '<');
b(s, 'k<1 dbl', 'simulink/Signal Attributes/Data Type Conversion', 'OutDataTypeStr', 'double');
b(s, 'enable', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
w(s, vin, 'v.^2/1');  w(s, vin, 'v.^2/2');  w(s, 'v.^2/1', 'sum v2/1');  w(s, 'sum v2/1', '|v|/1');
w(s, '|v|/1', 'max |v|/1');  w(s, 'eps/1', 'max |v|/2');  w(s, 'Vdc/1', 'Vdc over sqrt3/1');
w(s, 'Vdc over sqrt3/1', 'ratio/1');  w(s, 'max |v|/1', 'ratio/2');  w(s, 'ratio/1', 'k/1');  w(s, 'one k/1', 'k/2');
w(s, vin, [vout_name '/1']);  w(s, 'k/1', [vout_name '/2']);
w(s, 'k/1', 'k<1/1');  w(s, 'one k/1', 'k<1/2');  w(s, 'k<1/1', 'k<1 dbl/1');
w(s, 'one k/1', 'enable/1');  w(s, 'k<1 dbl/1', 'enable/2');  w(s, 'enable/1', en_dst);
end

function mk_pbc_msc(parent, name, pos)
% vs* = Ls dis*/dt + Rs is* - we Ls J is* + we psi eq - Ra es - Ki int(es),  J = [0 1; -1 0]
s = subsys(parent, name, pos, {'isd', 'isq', 'isqr', 'W', 'Vdc'}, {'vsd', 'vsq'});
b(s, 'isdr = 0', 'simulink/Sources/Constant', 'Value', '0');
b(s, 'is*', 'simulink/Signal Routing/Mux', 'Inputs', '2');
b(s, 'is', 'simulink/Signal Routing/Mux', 'Inputs', '2');
w(s, 'isdr = 0/1', 'is*/1');  w(s, 'isqr/1', 'is*/2');  w(s, 'isd/1', 'is/1');  w(s, 'isq/1', 'is/2');
b(s, 'is* - isf', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'inv taud', 'simulink/Math Operations/Gain', 'Gain', '1/taud');
b(s, 'isf', 'simulink/Discrete/Discrete-Time Integrator', 'IntegratorMethod', 'Integration: Forward Euler', ...
  'InitialCondition', '[0; isq0]', 'SampleTime', 'Ts');
w(s, 'is*/1', 'is* - isf/1');  w(s, 'isf/1', 'is* - isf/2');  w(s, 'is* - isf/1', 'inv taud/1');  w(s, 'inv taud/1', 'isf/1');
b(s, 'es', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
w(s, 'is/1', 'es/1');  w(s, 'is*/1', 'es/2');
gate(s, 'zs', '[0; 0]');
w(s, 'es/1', 'zs gate/1');
b(s, 'we', 'simulink/Math Operations/Gain', 'Gain', 'p');
b(s, 'Ls [0 -1; 1 0]', 'simulink/Math Operations/Gain', 'Gain', 'Ls*[0 -1; 1 0]', 'Multiplication', 'Matrix(K*u)');
b(s, 'coupling', 'simulink/Math Operations/Product', 'Inputs', '**');
b(s, 'psi [0;1]', 'simulink/Math Operations/Gain', 'Gain', 'psi*[0; 1]', 'Multiplication', 'Element-wise(K.*u)');
w(s, 'W/1', 'we/1');  w(s, 'is*/1', 'Ls [0 -1; 1 0]/1');  w(s, 'we/1', 'coupling/1');  w(s, 'Ls [0 -1; 1 0]/1', 'coupling/2');
w(s, 'we/1', 'psi [0;1]/1');
b(s, 'Ls', 'simulink/Math Operations/Gain', 'Gain', 'Ls');
b(s, 'Rs', 'simulink/Math Operations/Gain', 'Gain', 'Rs');
b(s, 'Ra', 'simulink/Math Operations/Gain', 'Gain', 'Ra');
b(s, 'Ki', 'simulink/Math Operations/Gain', 'Gain', 'Ki');
b(s, 'vs*', 'simulink/Math Operations/Sum', 'Inputs', '++++--', 'IconShape', 'rectangular');
w(s, 'inv taud/1', 'Ls/1');  w(s, 'is*/1', 'Rs/1');  w(s, 'es/1', 'Ra/1');  w(s, 'zs/1', 'Ki/1');
w(s, 'Ls/1', 'vs*/1');  w(s, 'Rs/1', 'vs*/2');  w(s, 'coupling/1', 'vs*/3');  w(s, 'psi [0;1]/1', 'vs*/4');
w(s, 'Ra/1', 'vs*/5');  w(s, 'Ki/1', 'vs*/6');
vlimit(s, 'vs*/1', 'zs gate/2', 'vs lim');
b(s, 'Demux', 'simulink/Signal Routing/Demux', 'Outputs', '2');
w(s, 'vs lim/1', 'Demux/1');  w(s, 'Demux/1', 'vsd/1');  w(s, 'Demux/2', 'vsq/1');
arrange(s);
end

function mk_pbc_gsc(parent, name, pos)
% vi* = Lf dig*/dt + Rf ig* - wg Lf J ig* + vg - Rb eg - Kig int(eg)
s = subsys(parent, name, pos, {'igd', 'igq', 'igdr', 'vgd', 'Vdc'}, {'vid', 'viq', 'igf'});
b(s, 'igqr = 0', 'simulink/Sources/Constant', 'Value', '0');
b(s, 'vgq = 0', 'simulink/Sources/Constant', 'Value', '0');
b(s, 'ig*', 'simulink/Signal Routing/Mux', 'Inputs', '2');
b(s, 'ig', 'simulink/Signal Routing/Mux', 'Inputs', '2');
b(s, 'vg', 'simulink/Signal Routing/Mux', 'Inputs', '2');
w(s, 'igdr/1', 'ig*/1');  w(s, 'igqr = 0/1', 'ig*/2');  w(s, 'igd/1', 'ig/1');  w(s, 'igq/1', 'ig/2');
w(s, 'vgd/1', 'vg/1');  w(s, 'vgq = 0/1', 'vg/2');
b(s, 'ig* - igf', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
b(s, 'inv taud', 'simulink/Math Operations/Gain', 'Gain', '1/taud');
b(s, 'ig filter', 'simulink/Discrete/Discrete-Time Integrator', 'IntegratorMethod', 'Integration: Forward Euler', ...
  'InitialCondition', '[igd0; 0]', 'SampleTime', 'Ts');
w(s, 'ig*/1', 'ig* - igf/1');  w(s, 'ig filter/1', 'ig* - igf/2');  w(s, 'ig* - igf/1', 'inv taud/1');  w(s, 'inv taud/1', 'ig filter/1');
b(s, 'eg', 'simulink/Math Operations/Sum', 'Inputs', '+-', 'IconShape', 'rectangular');
w(s, 'ig/1', 'eg/1');  w(s, 'ig*/1', 'eg/2');
gate(s, 'zg', '[0; 0]');
w(s, 'eg/1', 'zg gate/1');
b(s, 'wg Lf [0 -1; 1 0]', 'simulink/Math Operations/Gain', 'Gain', 'wg*Lf*[0 -1; 1 0]', 'Multiplication', 'Matrix(K*u)');
b(s, 'Lf', 'simulink/Math Operations/Gain', 'Gain', 'Lf');
b(s, 'Rf', 'simulink/Math Operations/Gain', 'Gain', 'Rf');
b(s, 'Rb', 'simulink/Math Operations/Gain', 'Gain', 'Rb');
b(s, 'Kig', 'simulink/Math Operations/Gain', 'Gain', 'Kig');
b(s, 'vi*', 'simulink/Math Operations/Sum', 'Inputs', '++++--', 'IconShape', 'rectangular');
w(s, 'ig*/1', 'wg Lf [0 -1; 1 0]/1');  w(s, 'inv taud/1', 'Lf/1');  w(s, 'ig*/1', 'Rf/1');
w(s, 'eg/1', 'Rb/1');  w(s, 'zg/1', 'Kig/1');
w(s, 'Lf/1', 'vi*/1');  w(s, 'Rf/1', 'vi*/2');  w(s, 'wg Lf [0 -1; 1 0]/1', 'vi*/3');  w(s, 'vg/1', 'vi*/4');
w(s, 'Rb/1', 'vi*/5');  w(s, 'Kig/1', 'vi*/6');
vlimit(s, 'vi*/1', 'zg gate/2', 'vi lim');
b(s, 'Demux', 'simulink/Signal Routing/Demux', 'Outputs', '2');
b(s, 'Demux igf', 'simulink/Signal Routing/Demux', 'Outputs', '2');
b(s, 'Term', 'simulink/Sinks/Terminator');
w(s, 'vi lim/1', 'Demux/1');  w(s, 'Demux/1', 'vid/1');  w(s, 'Demux/2', 'viq/1');
w(s, 'ig filter/1', 'Demux igf/1');  w(s, 'Demux igf/1', 'igf/1');  w(s, 'Demux igf/2', 'Term/1');
arrange(s);
end

function tag_out(sys, src, tag)
% subsystem output -> Goto block placed just right of the port
persistent n
if isempty(n), n = 0; end
n = n + 1;
i = find(src == '/', 1, 'last');  blk = src(1:i-1);  k = str2double(src(i+1:end));
ph = get_param([sys '/' blk], 'PortHandles');  pp = get_param(ph.Outport(k), 'Position');
g = sprintf('Goto %d', n);
add_block('simulink/Signal Routing/Goto', [sys '/' g], 'GotoTag', tag, 'ShowName', 'off', ...
          'Position', [pp(1)+30 pp(2)-9 pp(1)+90 pp(2)+9]);
add_line(sys, src, [g '/1']);
end

function tag_in(sys, tag, dst)
% From block placed just left of the input port -> subsystem/block input
persistent n
if isempty(n), n = 0; end
n = n + 1;
i = find(dst == '/', 1, 'last');  blk = dst(1:i-1);  k = str2double(dst(i+1:end));
ph = get_param([sys '/' blk], 'PortHandles');  pp = get_param(ph.Inport(k), 'Position');
f = sprintf('From %d', n);
add_block('simulink/Signal Routing/From', [sys '/' f], 'GotoTag', tag, 'ShowName', 'off', ...
          'Position', [pp(1)-90 pp(2)-9 pp(1)-30 pp(2)+9]);
add_line(sys, [f '/1'], dst);
end

function colorize(mdl)
% light background colour for every block (by block type, subsystems by role)
BLUE = '[0.85 0.92 1]';  YEL = '[1 1 0.8]';  GRN = '[0.86 1 0.86]';  ORA = '[1 0.92 0.8]';
PUR = '[0.93 0.89 1]';  PNK = '[1 0.89 0.92]';  CYA = '[0.88 1 1]';  GRY = '[0.92 0.92 0.92]';
typ = {'Integrator', BLUE; 'DiscreteIntegrator', BLUE; 'UnitDelay', BLUE; 'DiscreteTransferFcn', BLUE;
       'Gain', YEL; 'Sum', GRN; 'Product', ORA; 'DotProduct', ORA; 'Math', ORA; 'Sqrt', ORA; 'MinMax', ORA;
       'Lookup_n-D', CYA; 'Constant', PUR; 'Step', PUR; 'Sin', PUR; 'RandomNumber', PUR; 'Clock', PUR;
       'Saturate', PNK; 'RelationalOperator', PNK; 'DataTypeConversion', PNK; 'Switch', PNK;
       'Goto', CYA; 'From', CYA; 'Scope', GRY; 'ToWorkspace', GRY; 'Terminator', GRY};
sub = {'Wind', BLUE; 'Turbine', BLUE; 'PMSG and shaft', BLUE; 'DC link', BLUE; 'L filter and grid', BLUE;
       'Control (flatness + PBC + RBF-ANN)', YEL; 'MPPT reference', GRN; 'Turbine model', BLUE;
       'RBF network', PUR; 'Flatness speed loop', ORA; 'Flatness DC-link loop', ORA;
       'PBC machine side', PNK; 'PBC grid side', PNK};
blks = find_system(mdl, 'Type', 'Block');
for k = 1:numel(blks)
  bt = get_param(blks{k}, 'BlockType');
  if strcmp(bt, 'SubSystem'), list = sub;  key = get_param(blks{k}, 'Name');  else, list = typ;  key = bt;  end
  i = find(strcmp(list(:,1), key), 1);
  if ~isempty(i), set_param(blks{k}, 'BackgroundColor', list{i,2}); end
end
end
