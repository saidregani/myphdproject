% CHAOS_ANALYSIS  Lyapunov spectrum, attractor and bifurcation diagram of model (5) -> Fig. 1.
%   Set FAST = true for a quick, lower-resolution bifurcation diagram (a few minutes).
clear; close all;
FAST = false;
g = -1;  s = 8;  e = [0; -85; 0];
% ---- 1) Lyapunov spectrum (QR method on the variational equations), fixed-step RK4
dt = 1e-3;  Ttr = 200;  T = 500;  nq = 100;          % re-orthonormalize every nq steps (0.1 time unit)
f  = @(z) chaos_rhs(z, g, s, e);
Jf = @(z) [-1, -z(3), -z(2)+g;  z(3), -1, z(1);  s, 0, -s];
G  = @(y) [f(y(1:3)); reshape(Jf(y(1:3))*reshape(y(4:12),3,3), 9, 1)];
z = [0.3; 0.6; 1.0];
for k = 1:round(Ttr/dt)
    k1 = f(z); k2 = f(z+dt/2*k1); k3 = f(z+dt/2*k2); k4 = f(z+dt*k3); z = z + dt/6*(k1+2*k2+2*k3+k4);
end
y = [z; reshape(eye(3),9,1)];  S = zeros(3,1);
for k = 1:round(T/dt)
    k1 = G(y); k2 = G(y+dt/2*k1); k3 = G(y+dt/2*k2); k4 = G(y+dt*k3); y = y + dt/6*(k1+2*k2+2*k3+k4);
    if mod(k, nq) == 0
        [Qm, Rm] = qr(reshape(y(4:12),3,3));
        S = S + log(abs(diag(Rm)));  y(4:12) = reshape(Qm*diag(sign(diag(Rm))), 9, 1);
    end
end
L = sort(S/T, 'descend');
fprintf('Lyapunov spectrum: %.4f  %.4f  %.4f   (sum %.3f, divergence %.3f)\n', L, sum(L), -(2+s));
fprintf('Kaplan-Yorke dimension: %.3f\n', 2 + L(1)/abs(L(3)));
% ---- 2) attractor
[~, Z] = ode45(@(t,z) f(z), [0 300], [0.3 0.6 1.0], odeset('RelTol',1e-9,'AbsTol',1e-9,'MaxStep',0.002));
Z = Z(round(end/3):end, :);
% ---- 3) bifurcation diagram and largest Lyapunov exponent versus eps2 (vectorized RK4)
if FAST, E2 = linspace(-100, 0, 101); Ttr = 100; Tb = 150; else, E2 = linspace(-100, 0, 401); Ttr = 150; Tb = 300; end
M = numel(E2);  x = repmat([0.3; 0.6; 1.0], 1, M);  w = ones(3, M)/sqrt(3);
Fv = @(x) [-x(1,:) - x(3,:).*x(2,:) + g*x(3,:); -x(2,:) + x(3,:).*x(1,:) + E2; s*x(1,:) - s*x(3,:)];
Jv = @(x,w) [-w(1,:) - x(3,:).*w(2,:) + (-x(2,:)+g).*w(3,:); x(3,:).*w(1,:) - w(2,:) + x(1,:).*w(3,:); s*w(1,:) - s*w(3,:)];
ntr = round(Ttr/dt);  nb = round(Tb/dt);  LL = zeros(1, M);
pts = cell(1, M);  yp2 = [];  yp1 = [];
for k = 1:ntr + nb
    k1x = Fv(x);            k1w = Jv(x, w);
    k2x = Fv(x+dt/2*k1x);   k2w = Jv(x+dt/2*k1x, w+dt/2*k1w);
    k3x = Fv(x+dt/2*k2x);   k3w = Jv(x+dt/2*k2x, w+dt/2*k2w);
    k4x = Fv(x+dt*k3x);     k4w = Jv(x+dt*k3x, w+dt*k3w);
    x = x + dt/6*(k1x+2*k2x+2*k3x+k4x);  w = w + dt/6*(k1w+2*k2w+2*k3w+k4w);
    if mod(k, 20) == 0
        nw = sqrt(sum(w.^2, 1));  if k > ntr, LL = LL + log(nw); end;  w = w ./ nw;
    end
    if k > ntr
        if ~isempty(yp2)
            idx = find(yp1 > yp2 & yp1 >= x(3,:));
            for i = idx, if numel(pts{i}) < 300, pts{i}(end+1) = yp1(i); end, end
        end
        yp2 = yp1;  yp1 = x(3,:);
    end
end
LL = LL/(nb*dt);
% ---- Fig. 1
figure('Position', [100 100 560 480]);
subplot(2,2,1); plot(Z(:,1), Z(:,2), 'b', 'LineWidth', 0.2); xlabel('z_1'); ylabel('z_2'); title('(a)'); grid on;
subplot(2,2,2); plot(Z(:,1), Z(:,3), 'b', 'LineWidth', 0.2); xlabel('z_1'); ylabel('z_3'); title('(b)'); grid on;
subplot(2,2,3); hold on;
for i = 1:M, if ~isempty(pts{i}), plot(E2(i)*ones(size(pts{i})), pts{i}, 'k.', 'MarkerSize', 1); end, end
xlabel('\epsilon_2'); ylabel('local maxima of z_3'); title('(c)'); grid on; xlim([-100 0]); box on;
subplot(2,2,4); plot(E2, LL, 'r', 'LineWidth', 1); hold on; plot([-100 0], [0 0], 'k--');
xlabel('\epsilon_2'); ylabel('\lambda_{max}'); title('(d)'); grid on; xlim([-100 0]);
print('-dpng', '-r300', 'fig1_matlab.png');
