%% Step 4: Wind speed profiles
% (a) step profile 9 -> 11 -> 8 m/s (as in Aimene et al., Processes 2022, Sec. 5)
% (b) turbulent profile: v = Vm + sum A_k sin(2 pi f_k t) + v_t(t)
%     (harmonic part as in Eq. (80) of the authors' Mathematics paper,
%      v_t = first-order coloured noise, Park-Miller + Box-Muller generator)
clear; clc; close all

%% Parameters
Ts   = 1e-3;  Tend = 40;  t = 0:Ts:Tend;
Vm   = 8.5;  A = [1.5 0.2 0.3];  f = [0.03 0.16 0.17];
sig  = 0.5;  tau = 1.5;  seed = 12345;

%% (a) Step profile
v_step = 9*ones(size(t));
v_step(t >= 10) = 11;
v_step(t >= 25) = 8;

%% (b) Turbulent profile
n = numel(t);  a = exp(-Ts/tau);  g = sqrt(1 - a^2)*sig;
s = seed;  vt = zeros(1, n);  x = 0;  k = 1;
while k <= n
  s = mod(16807*s, 2147483647);  u1 = s/2147483647;
  s = mod(16807*s, 2147483647);  u2 = s/2147483647;
  r = sqrt(-2*log(u1));  z = [r*cos(2*pi*u2), r*sin(2*pi*u2)];
  for j = 1:2
    if k > n, break; end
    x = a*x + g*z(j);  vt(k) = x;  k = k + 1;
  end
end
v_turb = Vm + vt;
for i = 1:numel(A)
  v_turb = v_turb + A(i)*sin(2*pi*f(i)*t);
end

%% Statistics
fprintf('Turbulent wind: mean %.2f m/s, std %.2f m/s, min %.2f, max %.2f m/s\n', ...
        mean(v_turb), std(v_turb), min(v_turb), max(v_turb));
fprintf('Turbulence part: std %.2f m/s (%.1f %% of Vm)\n', std(vt), 100*std(vt)/Vm);

%% Figures
figure;
subplot(2,1,1); plot(t, v_step, 'LineWidth', 1.2); grid on; ylim([6 12]);
ylabel('v (m/s)'); title('(a) Step profile');
subplot(2,1,2); plot(t, v_turb, 'LineWidth', 0.8); grid on; ylim([5 12]);
ylabel('v (m/s)'); xlabel('t (s)'); title('(b) Turbulent profile');
