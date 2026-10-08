function plot_results(a, b, outdir, tag)
%PLOT_RESULTS  Comparison figures (a = PI, b = flatness+PBC+ANN).
t = a.t;  lw = 1.1;
f = figure('Visible', 'off', 'Position', [50 50 1100 900]);
subplot(4,2,1); plot(t, a.vw, 'k', 'LineWidth', lw); grid on;
ylabel('v_w [m/s]'); title('Wind speed');
subplot(4,2,2); plot(t, a.lg(:,1), 'k--', t, a.x(:,3), 'b', t, b.x(:,3), 'r', 'LineWidth', lw);
grid on; ylabel('\omega_m [rad/s]'); title('Rotor speed'); legend('ref','PI','Flat+PBC+ANN','Location','best');
subplot(4,2,3); plot(t, a.Cp, 'b', t, b.Cp, 'r', 'LineWidth', lw); grid on;
ylabel('C_p'); title('Power coefficient'); ylim([0.3 0.5]);
subplot(4,2,4); plot(t, a.Te/1e6, 'b', t, b.Te/1e6, 'r', t, b.Tw/1e6, 'k:', 'LineWidth', lw);
grid on; ylabel('T [MN.m]'); title('Electromagnetic / aerodynamic torque');
subplot(4,2,5); plot(t, a.x(:,4), 'b', t, b.x(:,4), 'r', 'LineWidth', lw); grid on;
ylabel('V_{dc} [V]'); title('DC-link voltage');
subplot(4,2,6); plot(t, a.Pgrid/1e6, 'b', t, b.Pgrid/1e6, 'r', t, a.Qgrid/1e6, 'b--', t, b.Qgrid/1e6, 'r--', 'LineWidth', lw);
grid on; ylabel('P, Q [MW, Mvar]'); title('Power injected into the grid');
subplot(4,2,7); plot(t, a.x(:,1), 'b', t, b.x(:,1), 'r', t, a.x(:,2), 'b', t, b.x(:,2), 'r', 'LineWidth', lw);
grid on; ylabel('i_{sd}, i_{sq} [A]'); xlabel('t [s]'); title('PMSG currents');
subplot(4,2,8); plot(t, b.lg(:,10), t, b.lg(:,11), 'LineWidth', lw);
grid on; ylabel('u_{AI} [pu]'); xlabel('t [s]'); title('ANN compensation');
legend('\Delta T_e / T_n','\Delta P_g / P_n','Location','best');
print(f, fullfile(outdir, ['fig_' tag '.png']), '-dpng', '-r110'); close(f);

f = figure('Visible', 'off', 'Position', [50 50 1000 500]);
P = b.P;
subplot(2,2,1); plot(t, b.lg(:,6)/1e3, 'r', t, 0.5*P.C*P.Vdc_ref^2/1e3*ones(size(t)), 'k--'); grid on;
title('Flat output y_2 = W_{dc} + W_{Lf} [kJ]');
subplot(2,2,2); plot(t, b.lg(:,7)/1e6, 'r', t, b.Tw/1e6, 'k--'); grid on;
title('T_w: Cp model vs true [MN.m]'); legend('model','true');
subplot(2,2,3); plot(t, b.x(:,5) - b.lg(:,4), 'r', t, a.x(:,5) - a.lg(:,4), 'b'); grid on;
title('i_{gd} tracking error [A]'); xlabel('t [s]'); legend('Flat+PBC+ANN','PI');
subplot(2,2,4); plot(t, b.x(:,2) - b.lg(:,3), 'r', t, a.x(:,2) - a.lg(:,3), 'b'); grid on;
title('i_{sq} tracking error [A]'); xlabel('t [s]');
print(f, fullfile(outdir, ['fig_' tag '_details.png']), '-dpng', '-r110'); close(f);
end
