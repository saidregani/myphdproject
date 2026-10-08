%PLOT_SIMULINK  Plots the logged signals after out = sim('PMSG_FPBC_ANN').
% Works whether the logs are in the workspace or inside out = sim(...).
if exist('out', 'var') && isa(out, 'Simulink.SimulationOutput')
  for f = {'x_log', 'wr_log', 'pq_log', 'cp_log', 'uai_log', 'vw_log'}
    try, eval([f{1} ' = out.get(''' f{1} ''');']); catch, end
  end
end
if ~exist('x_log', 'var')
  error('No results found: run  out = sim(''PMSG_FPBC_ANN'');  first.');
end
t  = x_log.time;  x = fixlog(x_log);         % [isd isq Omega Vdc igd igq]
figure('Name', 'PMSG_FPBC_ANN', 'Position', [100 100 1100 750]);
subplot(3,2,1); plot(vw_log.time, fixlog(vw_log)); grid on; ylabel('v [m/s]'); title('Wind');
subplot(3,2,2); plot(t, x(:,3), wr_log.time, fixlog(wr_log), '--'); grid on;
ylabel('\Omega [rad/s]'); legend('\Omega', '\Omega^*'); title('Rotor speed (MPPT)');
subplot(3,2,3); plot(cp_log.time, fixlog(cp_log)); grid on; ylabel('C_p'); title('Power coefficient');
subplot(3,2,4); plot(t, x(:,4)); grid on; ylabel('V_{dc} [V]'); title('DC-link voltage');
subplot(3,2,5); plot(pq_log.time, fixlog(pq_log)/1e6); grid on; ylabel('[MW, Mvar]'); xlabel('t [s]');
legend('P', 'Q'); title('Grid power');
subplot(3,2,6); u = fixlog(uai_log);
plot(uai_log.time, u(:,1)/1e6, uai_log.time, u(:,2)/1e6); grid on; xlabel('t [s]'); ylabel('u_{AI}');
legend('\Delta T_e [MN.m]', '\Delta P_g [MW]'); title('Adaptive ANN compensation');
