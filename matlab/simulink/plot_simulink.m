%PLOT_SIMULINK  Plots the logged signals after sim('PMSG_FPBC_ANN').
t  = x_log.time;  x = x_log.signals.values;   % [isd isq Omega Vdc igd igq]
figure('Name', 'PMSG_FPBC_ANN');
subplot(3,2,1); plot(vw_log.time, vw_log.signals.values); grid on; ylabel('v [m/s]'); title('Wind');
subplot(3,2,2); plot(t, x(:,3), wr_log.time, wr_log.signals.values, '--'); grid on;
ylabel('\Omega [rad/s]'); legend('\Omega', '\Omega^*'); title('Rotor speed (MPPT)');
subplot(3,2,3); plot(cp_log.time, cp_log.signals.values); grid on; ylabel('C_p'); title('Power coefficient');
subplot(3,2,4); plot(t, x(:,4)); grid on; ylabel('V_{dc} [V]'); title('DC-link voltage');
pq = pq_log.signals.values;
subplot(3,2,5); plot(pq_log.time, pq/1e6); grid on; ylabel('[MW, Mvar]'); xlabel('t [s]');
legend('P', 'Q'); title('Grid power');
subplot(3,2,6); u = uai_log.signals.values;
plot(uai_log.time, squeeze(u)'); grid on; xlabel('t [s]'); ylabel('u_{AI}');
legend('\Delta T_e [N.m]', '\Delta P_g [W]'); title('Adaptive ANN compensation');
