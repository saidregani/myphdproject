%MAIN_MLI  Validation with the switched model (PWM rectifier + PWM inverter,
% fsw = 5 kHz): waveforms and THD of the grid current, PI vs Flat+PBC+ANN.
clear; close all; clc;
P = pmsg_params();
outdir = fullfile('..', 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end
ctrls = {'PI', 'FPBC'};
for c = 1:2
  fprintf('Switched model, %s ...\n', ctrls{c});
  tic; O.(ctrls{c}) = simulate_mli(P, ctrls{c}); toc;
  fprintf('  THD(i_ga) = %.2f %%\n', O.(ctrls{c}).THD_ig);
end
a = O.PI; b = O.FPBC; t = a.t;
f = figure('Visible', 'off', 'Position', [50 50 1100 800]);
subplot(3,2,1); plot(t, b.van, 'Color', [0.6 0.6 0.6]); grid on; xlim([0.2 0.24]);
ylabel('v_{an} [V]'); title('Inverter PWM voltage, phase a (Flat+PBC+ANN)');
subplot(3,2,2); plot(t, a.iga, 'b', t, b.iga, 'r'); grid on; xlim([0.4 0.6]);
ylabel('i_{ga} [A]'); title(sprintf('Grid current (THD: PI %.2f%%, Flat+PBC+ANN %.2f%%)', a.THD_ig, b.THD_ig));
legend('PI', 'Flat+PBC+ANN');
subplot(3,2,3); plot(t, a.x(:,4), 'b', t, b.x(:,4), 'r'); grid on;
ylabel('V_{dc} [V]'); title('DC-link voltage');
subplot(3,2,4); plot(t, a.x(:,5), 'b', t, b.x(:,5), 'r', t, a.x(:,6), 'b', t, b.x(:,6), 'r'); grid on;
ylabel('i_{gd}, i_{gq} [A]'); title('Grid currents (dq)');
subplot(3,2,5); plot(t, a.isa, 'b', t, b.isa, 'r'); grid on;
ylabel('i_{sa} [A]'); xlabel('t [s]'); title('PMSG stator current, phase a');
subplot(3,2,6); plot(t, a.x(:,3), 'b', t, b.x(:,3), 'r'); grid on;
ylabel('\Omega [rad/s]'); xlabel('t [s]'); title('Rotor speed (wind 10 -> 11 m/s at 0.45 s)');
print(f, fullfile(outdir, 'fig_mli.png'), '-dpng', '-r110'); close(f);
