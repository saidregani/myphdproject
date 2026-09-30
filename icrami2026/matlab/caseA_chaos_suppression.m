% CASEA_CHAOS_SUPPRESSION  Table II and Fig. 4 of the revised paper.
clear; close all;
ctrls = {'mpc','fl','pi'};  names = {'FL-MPC','FL only','PI'};  dl = [0 -0.2 0.2];
R = cell(3,3);
fprintf('%-8s %-8s %8s %8s %10s\n','plant','ctrl','IAE','t_s','e_f');
for j = 1:3
    for c = 1:3
        R{c,j} = run_chaos_case(ctrls{c}, dl(j));
        fprintf('%+-8.1f %-8s %8.3f %8.3f %10.2e\n', dl(j), names{c}, R{c,j}.IAE, R{c,j}.ts, R{c,j}.ef);
    end
end
% ---- Fig. 4
o = R{1,1};  zt = o.zt;  figure('Position',[100 100 520 600]);
for i = 1:3
    subplot(4,1,i); plot(o.t, o.z(:,i), 'b', 'LineWidth', 0.8); hold on;
    plot([0 10], zt(i)*[1 1], 'k-.'); plot([6 6], ylim, 'Color', [.5 .5 .5]);
    xlim([0 10]); ylabel(sprintf('z_%d', i)); grid on;
end
xlabel('normalized time');
subplot(4,1,4); sty = {'b-','g--','r:'};
for c = [1 3 2]
    o = R{c,3};  m = o.t >= 6;
    semilogy(o.t(m) - 6, sqrt(sum((o.z(m,:) - zt').^2, 2)), sty{c}, 'LineWidth', 1); hold on;
end
xlim([0 3]); ylim([1e-4 1e2]); grid on; legend('FL-MPC (proposed)','PI','FL only');
xlabel('normalized time after activation'); ylabel('||z - z^*||');
text(0.05, 3e-4, '(b) +20 % mismatch');
print('-dpng', '-r300', 'fig4_matlab.png');
