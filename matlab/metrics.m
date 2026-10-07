function M = metrics(o)
%METRICS  Performance indices used to compare the controllers.
% Current-tracking errors are split into the start-up phase (t < 1 s, where
% the adaptive laws are still learning the mismatched parameters) and the
% rest of the run.
dt  = o.t(2) - o.t(1);
es  = sum((o.x(:,1:2) - o.lg(:,2:3)).^2, 2);
eg  = sum((o.x(:,5:6) - o.lg(:,4:5)).^2, 2);
k0  = o.t < 1;  k1 = ~k0;
M.IAE_w    = sum(abs(o.x(:,3) - o.lg(:,1)))*dt;                % rad
M.ISE_Vdc  = sum((o.x(:,4) - o.P.Vdc_ref).^2)*dt;              % V^2 s
M.max_dVdc = max(abs(o.x(:,4) - o.P.Vdc_ref));                 % V
M.rms_es0  = sqrt(mean(es(k0)));  M.rms_es = sqrt(mean(es(k1)));  % A
M.rms_eg0  = sqrt(mean(eg(k0)));  M.rms_eg = sqrt(mean(eg(k1)));  % A
M.Cp_mean  = mean(o.Cp);
M.E_grid   = sum(o.Pgrid)*dt/3.6e6;                            % kWh
end
