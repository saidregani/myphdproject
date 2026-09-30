% CASEB_MPPT_TRACKING  Table III and Figs. 2, 5, 6 of the revised paper.
clear; close all;
ctrls = {'mpc','fl','pi'};  names = {'FL-MPC','FL only','PI'};
plants = {'nom','m1','m2'};
S = cell(3,3);
fprintf('%-5s %-8s %9s %9s %9s %9s\n','plant','ctrl','P_s[%]','i_dr[A]','i_qr[A]','w_r');
for j = 1:3
    for c = 1:3
        S{c,j} = run_mppt_case(ctrls{c}, plants{j});
        o = S{c,j};
        fprintf('%-5s %-8s %9.3f %9.2f %9.3f %9.5f\n', plants{j}, names{c}, o.rmse_P_pct, o.rmse(1), o.rmse(2), o.rmse(3));
    end
end
o = S{1,1};  p = S{3,1};  a = o.a;
% ---- Fig. 2 wind
figure('Position',[100 100 520 220]);
plot(o.tw, o.vw, 'Color', [0.2 0.45 0.8], 'LineWidth', 0.4); hold on; plot(o.tw, o.vf, 'k', 'LineWidth', 1.2);
xlabel('time (s)'); ylabel('wind speed (m/s)'); legend('v(t)','low-pass filtered (MPPT)'); grid on; xlim([0 30]);
print('-dpng', '-r300', 'fig2_matlab.png');
% ---- Fig. 5 states
figure('Position',[100 100 520 500]);
lab = {'i_{dr} (kA)','i_{qr} (kA)','\omega_r (rad/s)'};  sc = [1e-3 1e-3 1];
for i = 1:3
    subplot(3,1,i); plot(o.t, o.xr(:,i)*sc(i), 'r', 'LineWidth', 1.4); hold on;
    plot(o.t, o.x(:,i)*sc(i), 'b', 'LineWidth', 0.6); ylabel(lab{i}); grid on; xlim([0 30]);
end
subplot(3,1,1); legend('reference','FL-MPC'); subplot(3,1,3); xlabel('time (s)');
print('-dpng', '-r300', 'fig5_matlab.png');
% ---- Fig. 6 power
Ps  = @(x1) -1.5*a.ws*a.psi*a.Lm/a.Ls*x1/1e6;
figure('Position',[100 100 520 350]);
subplot(3,1,[1 2]); plot(o.t, Ps(o.xr(:,1)), 'r', 'LineWidth', 1.4); hold on; plot(o.t, Ps(o.x(:,1)), 'b', 'LineWidth', 0.6);
ylabel('P_s (MW)'); legend('P_{s,ref}','P_s (FL-MPC)'); grid on; xlim([0 30]);
subplot(3,1,3); plot(p.t, (Ps(p.x(:,1)) - Ps(p.xr(:,1)))*1e3, 'g', 'LineWidth', 0.5); hold on;
plot(o.t, (Ps(o.x(:,1)) - Ps(o.xr(:,1)))*1e3, 'b', 'LineWidth', 0.6);
ylim([-250 250]); xlim([0 30]); ylabel('error (kW)'); xlabel('time (s)'); legend('PI','FL-MPC','Orientation','horizontal','Location','southwest'); grid on;
print('-dpng', '-r300', 'fig6_matlab.png');
