%% Step 1: Wind turbine model (aerodynamics)
clear; clc; close all

%% Parameters
rho  = 1.225;      % air density [kg/m3]
R    = 40;         % blade radius [m]
Pn   = 2e6;        % rated power [W]
Wn   = 2.23;       % rated rotor speed [rad/s]
beta = 0;          % pitch angle [deg]

%% Power coefficient Cp(lambda)
lam = linspace(1, 14, 1000);
li  = 1 ./ (1 ./ (lam + 0.08*beta) - 0.035/(beta^3 + 1));
Cp  = 0.5176*(116./li - 0.4*beta - 5).*exp(-21./li) + 0.0068*lam;
[Cpmax, k] = max(Cp);
lopt = lam(k);

%% Rated point
vn   = Wn*R/lopt;                                % rated wind speed
Prat = 0.5*rho*pi*R^2*Cpmax*vn^3;                % power at rated wind
Kopt = 0.5*rho*pi*R^5*Cpmax/lopt^3;              % P_opt = Kopt*W^3
fprintf('Cp_max      = %.3f\n', Cpmax);
fprintf('lambda_opt  = %.2f\n', lopt);
fprintf('v_n         = %.2f m/s\n', vn);
fprintf('P at v_n    = %.2f MW\n', Prat/1e6);
fprintf('T at v_n    = %.3f MN.m\n', Prat/Wn/1e6);

%% Figure 1: Cp(lambda)
figure;
plot(lam, Cp, 'LineWidth', 1.2); grid on;
xlabel('\lambda'); ylabel('C_p'); ylim([0 0.5]);
title('Power coefficient (\beta = 0)');

%% Figure 2: P(Omega) for several wind speeds + MPPT curve
W = linspace(0.3, 3, 400);
figure; hold on; grid on;
for v = 6:1:12
  l  = W*R/v;
  li = 1 ./ (1 ./ (l + 0.08*beta) - 0.035/(beta^3 + 1));
  cp = max(0.5176*(116./li - 0.4*beta - 5).*exp(-21./li) + 0.0068*l, 0);
  plot(W, 0.5*rho*pi*R^2*cp*v^3/1e6, 'LineWidth', 1);
end
plot(W, Kopt*W.^3/1e6, 'k--', 'LineWidth', 1.5);
xlabel('\Omega (rad/s)'); ylabel('P_w (MW)');
legend('6 m/s','7','8','9','10','11','12','MPPT curve', 'Location', 'northwest');
ylim([0 3]);
