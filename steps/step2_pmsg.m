%% Step 2: PMSG model (receptor convention, as in Aimene et al., Processes 2022, Eqs. (5)-(6))
% Test: PMSG driven at constant speed and feeding a three-phase resistive load.
clear; clc; close all

%% Parameters
p   = 26;          % pole pairs
Rs  = 0.78e-3;     % stator resistance [ohm]
Ls  = 1.57e-3;     % stator inductance Ld = Lq [H]
psi = 9.18;        % magnet flux [Wb]
W   = 2.23;        % imposed rotor speed [rad/s]
RL  = 0.19;        % load resistance per phase [ohm]

%% Simulation (RK4)
h = 1e-5;  Tend = 0.3;  N = round(Tend/h);
t = (0:N)*h;  x = [0; 0];  X = zeros(2, N+1);
we = p*W;
f = @(x) [(-RL*x(1) - Rs*x(1) + we*Ls*x(2))/Ls;
          (-RL*x(2) - Rs*x(2) - we*Ls*x(1) - we*psi)/Ls];
for k = 1:N
  X(:,k) = x;
  k1 = f(x); k2 = f(x + h/2*k1); k3 = f(x + h/2*k2); k4 = f(x + h*k3);
  x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
end
X(:,end) = x;
isd = X(1,:);  isq = X(2,:);

%% Torque, powers and power balance (steady state)
Te    = 1.5*p*psi*isq;                 % electromagnetic torque (< 0: generator)
Pmech = -Te*W;                         % mechanical power absorbed by the PMSG
vsd   = -RL*isd;  vsq = -RL*isq;
Pout  = -1.5*(vsd.*isd + vsq.*isq);    % electrical power delivered to the load
Pcu   = 1.5*Rs*(isd.^2 + isq.^2);      % copper losses
fprintf('isd = %.0f A, isq = %.0f A\n', isd(end), isq(end));
fprintf('Te = %.3f MN.m (negative = generator)\n', Te(end)/1e6);
fprintf('Pmech = %.4f MW, Pout = %.4f MW, Pcu = %.2f kW\n', Pmech(end)/1e6, Pout(end)/1e6, Pcu(end)/1e3);
fprintf('Balance error Pmech - Pout - Pcu = %.2e W\n', Pmech(end) - Pout(end) - Pcu(end));

%% Phase currents (inverse Park)
th = we*t;
ia = isd.*cos(th) - isq.*sin(th);
ib = isd.*cos(th - 2*pi/3) - isq.*sin(th - 2*pi/3);
ic = isd.*cos(th + 2*pi/3) - isq.*sin(th + 2*pi/3);

%% Figures
figure;
subplot(3,1,1); plot(t, isd, t, isq, 'LineWidth', 1.2); grid on;
ylabel('i_s (A)'); legend('i_{sd}', 'i_{sq}');
subplot(3,1,2); plot(t, Te/1e6, 'LineWidth', 1.2); grid on;
ylabel('T_e (MN.m)');
subplot(3,1,3); plot(t, Pmech/1e6, t, Pout/1e6, '--', 'LineWidth', 1.2); grid on;
ylabel('P (MW)'); xlabel('t (s)'); legend('P_{mech}', 'P_{out}');
figure;
plot(t, ia, t, ib, t, ic, 'LineWidth', 1); grid on;
xlabel('t (s)'); ylabel('i_{abc} (A)'); legend('i_a', 'i_b', 'i_c');
