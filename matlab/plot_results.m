function plot_results(a, b, outdir, tag)
%PLOT_RESULTS  Comparison figures (a = PI, b = APBC+ANN).
t = a.t;  lw = 1.1;
f = figure('Visible', 'off', 'Position', [50 50 1100 900]);
subplot(4,2,1); plot(t, a.vw, 'k', 'LineWidth', lw); grid on;
ylabel('v_w [m/s]'); title('Wind speed');
subplot(4,2,2); plot(t, a.lg(:,1), 'k--', t, a.x(:,3), 'b', t, b.x(:,3), 'r', 'LineWidth', lw);
grid on; ylabel('\omega_m [rad/s]'); title('Rotor speed'); legend('ref','PI','APBC-ANN','Location','best');
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
subplot(4,2,8); plot(t, b.lg(:,10), t, b.lg(:,11), t, b.lg(:,12), t, b.lg(:,13), 'LineWidth', lw);
grid on; ylabel('g [-]'); xlabel('t [s]'); title('ANN gain multipliers');
legend('MSC current','GSC current','speed','DC bus','Location','best');
print(f, fullfile(outdir, ['fig_' tag '.png']), '-dpng', '-r110'); close(f);

f = figure('Visible', 'off', 'Position', [50 50 1000 500]);
P = b.P; Pp = b.Pp;
subplot(2,2,1); plot(t, b.lg(:,6)/P.Rs, 'r', t, Pp.Rs/P.Rs*ones(size(t)), 'k--'); grid on; title('\hat R_s / R_{s,nom}');
subplot(2,2,2); plot(t, b.lg(:,7)/P.Ls, 'r', t, Pp.Ls/P.Ls*ones(size(t)), 'k--'); grid on; title('\hat L_s / L_{s,nom}');
subplot(2,2,3); plot(t, b.lg(:,8)/P.psi, 'r', t, Pp.psi/P.psi*ones(size(t)), 'k--'); grid on; title('\hat\psi / \psi_{nom}'); xlabel('t [s]');
subplot(2,2,4); plot(t, b.lg(:,9)/1e6, 'r', t, b.Tw/1e6, 'k--'); grid on; title('\hat T_w [MN.m]'); xlabel('t [s]');
print(f, fullfile(outdir, ['fig_' tag '_estimates.png']), '-dpng', '-r110'); close(f);
end
