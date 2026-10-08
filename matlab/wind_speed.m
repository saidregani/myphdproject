function v = wind_speed(t)
%WIND_SPEED  Turbulent wind profile, same form as Eq. (80) of the authors'
%Mathematics paper (DFIG):
%   v(t) = Vmean + sum_k A_k sin(2 pi f_k t) + v_turb(t),  Vmean = 8 m/s
%A_k, f_k identified from Fig. 3 of that paper (the paper does not list
%them): A = [1.5 0.2 0.3] m/s, f = [0.03 0.16 0.17] Hz (fit error 0.02 m/s).
%v_turb: smoothed Gaussian noise (std 0.01 m/s, time constant 0.05 s),
%reproducible (own generator, same result in MATLAB and Octave).
persistent vt dt
if isempty(vt), [vt, dt] = turbulence(); end
A = [1.5 0.2 0.3];  f = [0.03 0.16 0.17];
v = 8 + A*sin(2*pi*f'*t) + vturb_at(t, vt, dt);
end

function x = vturb_at(t, vt, dt)
s = mod(t, (numel(vt) - 1)*dt)/dt;  k = floor(s);  a = s - k;
x = (1 - a)*vt(k + 1) + a*vt(k + 2);
end

function [vt, dt] = turbulence()
dt = 1e-3;  N = 20001;  tau = 0.05;  sig = 0.01;
seed = 12345;  u = zeros(N, 2);
for k = 1:2*N                                  % Park-Miller generator
  seed = mod(16807*seed, 2147483647);  u(k) = seed/2147483647;
end
w = sqrt(-2*log(u(:,1))).*cos(2*pi*u(:,2));   % Box-Muller -> N(0,1)
a = exp(-dt/tau);  vt = zeros(N, 1);
for k = 2:N, vt(k) = a*vt(k-1) + (1 - a)*w(k); end
vt = sig*vt/std(vt);
end
