%MAIN  2 MW PMSG back-to-back wind chain: PI vs flatness + PBC + ANN.
% Runs both controllers on the nominal and robustness scenarios, prints a
% comparison table and saves figures in ../results.
clear; close all; clc;
P = pmsg_params();
outdir = fullfile('..', 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end

% PI    : classical vector control
% PIFF  : PI + feed-forward of P_msc in the DC-bus loop (fair baseline)
% FPBC0 : flatness + PBC, ANN disabled (shows the contribution of the ANN)
% FPBC  : flatness + PBC + ANN (proposed)
ctrls = {'PI', 'PIFF', 'FPBC0', 'FPBC'};  scen = {'nominal', 'robust'};
if ~isempty(getenv('MAIN_SCEN')), scen = {getenv('MAIN_SCEN')}; end
R = struct();
for s = 1:numel(scen)
  for c = 1:numel(ctrls)
    fprintf('Simulating %-5s / %-8s ...\n', ctrls{c}, scen{s});
    tic; R.(scen{s}).(ctrls{c}) = simulate(P, ctrls{c}, scen{s}); toc;
  end
end

fprintf('\n(current errors in A: [t<1 s] / [t>=1 s])\n');
fprintf('%-9s %-5s %8s %10s %9s %17s %17s %7s %8s\n', 'scenario', 'ctrl', ...
  'IAE_w', 'ISE_Vdc', 'max|dV|', 'rms e_s', 'rms e_g', 'Cp', 'E[kWh]');
for s = 1:numel(scen)
  for c = 1:numel(ctrls)
    M = metrics(R.(scen{s}).(ctrls{c}));
    fprintf('%-9s %-5s %8.4f %10.2f %9.2f %8.2f/%8.2f %8.2f/%8.2f %7.4f %8.3f\n', ...
      scen{s}, ctrls{c}, M.IAE_w, M.ISE_Vdc, M.max_dVdc, M.rms_es0, M.rms_es, ...
      M.rms_eg0, M.rms_eg, M.Cp_mean, M.E_grid);
  end
end

for s = 1:numel(scen)
  plot_results(R.(scen{s}).PI, R.(scen{s}).FPBC, outdir, scen{s});
  Rs = R.(scen{s});
  save(fullfile(outdir, ['results_' scen{s} '.mat']), 'Rs', '-v7');
end
