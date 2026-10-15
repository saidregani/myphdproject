%% Step 3: Complete chain: turbine + PMSG + DC link + L filter + grid (average converter model)
% Test: equilibrium at v = 11 m/s computed analytically, then simulated with constant
% converter voltages: the states must stay constant and the power flow must balance.
clear; clc; close all

%% Parameters
rho = 1.225;  R = 40;  J = 2.8e6;  B = 1e3;  lopt = 8.1;
p = 26;  Rs = 0.78e-3;  Ls = 1.57e-3;  psi = 9.18;
C = 20e-3;  Vdc0 = 1200;
Vgm = 690*sqrt(2/3);  wg = 2*pi*50;  Lf = 0.15e-3;  Rf = 2e-3;
v = 11;                                        % wind speed [m/s]

%% Turbine torque
cp = @(l) 0.5176*(116./(1./(1./l - 0.035)) - 5).*exp(-21./(1./(1./l - 0.035))) + 0.0068*l;
Tw = @(W) 0.5*rho*pi*R^2*cp(W*R/v)*v^3/W;

%% Equilibrium (MPPT speed, isd = 0, unity power factor)
W0  = lopt*v/R;   we = p*W0;
isq0 = -(Tw(W0) - B*W0)/(1.5*p*psi);           % J dW/dt = Tw + Te - B W = 0
vsd0 = -we*Ls*isq0;                            % PMSG voltages (receptor convention)
vsq0 = Rs*isq0 + we*psi;
Pdc0 = -1.5*(vsd0*0 + vsq0*isq0);              % power into the DC link
igd0 = (-Vgm + sqrt(Vgm^2 + 4*Rf*Pdc0/1.5))/(2*Rf);  % Pdc = 1.5 (Vgm igd + Rf igd^2)
vid0 = Vgm + Rf*igd0;  viq0 = wg*Lf*igd0;      % inverter voltages
x = [0; isq0; W0; Vdc0; igd0; 0];
u = [vsd0; vsq0; vid0; viq0];

%% Plant model
f = @(x) [ (u(1) - Rs*x(1) + p*x(3)*Ls*x(2))/Ls;
           (u(2) - Rs*x(2) - p*x(3)*Ls*x(1) - p*x(3)*psi)/Ls;
           (Tw(x(3)) + 1.5*p*psi*x(2) - B*x(3))/J;
           (-1.5*(u(1)*x(1) + u(2)*x(2)) - 1.5*(u(3)*x(5) + u(4)*x(6)))/(C*x(4));
           (u(3) - Rf*x(5) + wg*Lf*x(6) - Vgm)/Lf;
           (u(4) - Rf*x(6) - wg*Lf*x(5))/Lf ];

%% Simulation (RK4)
h = 1e-4;  N = 10000;  X = zeros(6, N+1);  X(:,1) = x;
for k = 1:N
  k1 = f(x); k2 = f(x + h/2*k1); k3 = f(x + h/2*k2); k4 = f(x + h*k3);
  x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);  X(:,k+1) = x;
end
t = (0:N)*h;

%% Power flow at the equilibrium
Pw  = Tw(W0)*W0;   Pb = B*W0^2;   Pcs = 1.5*Rs*isq0^2;
Pg  = 1.5*Vgm*igd0; Pcf = 1.5*Rf*igd0^2;
fprintf('W = %.3f rad/s, isq = %.0f A, igd = %.0f A\n', W0, isq0, igd0);
fprintf('|vs| = %.0f V, |vi| = %.0f V, limit Vdc/sqrt(3) = %.0f V\n', ...
        norm([vsd0 vsq0]), norm([vid0 viq0]), Vdc0/sqrt(3));
fprintf('Pw = %.4f MW -> friction %.1f kW, Cu stator %.1f kW, Cu filter %.1f kW -> Pg = %.4f MW\n', ...
        Pw/1e6, Pb/1e3, Pcs/1e3, Pcf/1e3, Pg/1e6);
fprintf('Balance error Pw - losses - Pg = %.2e W\n', Pw - Pb - Pcs - Pcf - Pg);
fprintf('Max drift after 1 s: W %.1e rad/s, Vdc %.1e V, igd %.1e A\n', ...
        max(abs(X(3,:) - W0)), max(abs(X(4,:) - Vdc0)), max(abs(X(5,:) - igd0)));

%% Figures
figure;
subplot(2,2,1); plot(t, X(3,:)); grid on; ylabel('\Omega (rad/s)');
subplot(2,2,2); plot(t, X(4,:)); grid on; ylabel('V_{dc} (V)');
subplot(2,2,3); plot(t, X(1,:), t, X(2,:)); grid on; ylabel('i_s (A)'); legend('i_{sd}','i_{sq}'); xlabel('t (s)');
subplot(2,2,4); plot(t, X(5,:), t, X(6,:)); grid on; ylabel('i_g (A)'); legend('i_{gd}','i_{gq}'); xlabel('t (s)');
