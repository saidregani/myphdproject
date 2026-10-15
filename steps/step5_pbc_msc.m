%% Step 5: Passivity-based current control of the PMSG (machine-side converter)
% PMSG data: Hasan & Shatil, AJSE 2021, Table I. Receptor convention.
% Test: speed held at 2.23 rad/s, steps on the current references,
% sampling Ts = 1/(2 fsw), voltage applied one sample later, |vs| <= Vdc/sqrt(3).
clear; clc; close all

%% Parameters
p = 26;  Rs = 0.78e-3;  Ls = 1.57e-3;  psi = 9.18;  W = 2.23;  we = p*W;
Vdc = 1200;  fsw = 2160;  Ts = 1/(2*fsw);
wi  = 500;                         % closed-loop double pole [rad/s]
Ra  = 2*wi*Ls - Rs;                % damping injection [ohm]
Ki  = wi^2*Ls;                     % integral gain [ohm/s]
taud = 2e-3;                       % reference derivative filter [s]
Jm  = [0 1; -1 0];  eq = [0; 1];

%% Reference profile
Tend = 0.2;  N = round(Tend/Ts);  t = (0:N)*Ts;
isdr = zeros(1, N+1);  isqr = zeros(1, N+1);
isqr(t >= 0.02) = -1000;  isqr(t >= 0.07) = -2500;  isdr(t >= 0.12) = -500;

%% Simulation
x = [0; 0];  z = [0; 0];  irf = [0; 0];  u = [0; we*psi];
X = zeros(2, N+1);  U = zeros(2, N+1);  IR = zeros(2, N+1);
f = @(x, u) [(u(1) - Rs*x(1) + we*Ls*x(2))/Ls;
             (u(2) - Rs*x(2) - we*Ls*x(1) - we*psi)/Ls];
for k = 1:N+1
  % ---- PBC controller
  ir   = [isdr(k); isqr(k)];
  dir  = (ir - irf)/taud;  irf = irf + Ts*dir;      % filtered reference and derivative
  e    = x - irf;
  vs   = Ls*dir + Rs*irf - we*Ls*Jm*irf + we*psi*eq - Ra*e - Ki*z;
  if norm(vs) > Vdc/sqrt(3), vs = vs*Vdc/sqrt(3)/norm(vs); else, z = z + Ts*e; end
  X(:,k) = x;  U(:,k) = u;  IR(:,k) = irf;
  % ---- plant (RK4), previous voltage applied (one-sample delay)
  k1 = f(x, u); k2 = f(x + Ts/2*k1, u); k3 = f(x + Ts/2*k2, u); k4 = f(x + Ts*k3, u);
  x  = x + Ts/6*(k1 + 2*k2 + 2*k3 + k4);
  u  = vs;
end

%% Step-response indicators (isq step 0 -> -1000 A at 20 ms)
m  = t >= 0.02 & t < 0.07;  tq = t(m) - 0.02;  y = -X(2, m)/1000;
tr = tq(find(y >= 0.9, 1)) - tq(find(y >= 0.1, 1));
ov = max(0, (max(y) - 1)*100);
fprintf('Ra = %.3f ohm, Ki = %.1f ohm/s\n', Ra, Ki);
fprintf('isq step: rise time 10-90 %% = %.1f ms, overshoot = %.1f %%\n', tr*1e3, ov);
fprintf('Coupling on isd during the isq steps: max |isd| = %.1f A\n', max(abs(X(1, t < 0.12))));
fprintf('Steady error at 0.2 s: isd %.2f A, isq %.2f A\n', X(1,end) - isdr(end), X(2,end) - isqr(end));
fprintf('Max |vs| = %.0f V (limit %.0f V)\n', max(sqrt(sum(U.^2, 1))), Vdc/sqrt(3));

%% Figures
figure;
subplot(3,1,1); plot(t, IR(2,:), 'k--', t, X(2,:), 'LineWidth', 1.1); grid on;
ylabel('i_{sq} (A)'); ylim([-2800 300]); legend('i_{sq}^*', 'i_{sq}', 'Location', 'northeast');
subplot(3,1,2); plot(t, IR(1,:), 'k--', t, X(1,:), 'LineWidth', 1.1); grid on;
ylabel('i_{sd} (A)'); ylim([-600 150]); legend('i_{sd}^*', 'i_{sd}', 'Location', 'northeast');
subplot(3,1,3); plot(t, U(1,:), t, U(2,:), t, sqrt(sum(U.^2,1)), 'k', 'LineWidth', 1.1); grid on;
ylabel('v_s (V)'); xlabel('t (s)'); ylim([-800 900]); legend('v_{sd}', 'v_{sq}', '|v_s|', 'Location', 'southeast');
