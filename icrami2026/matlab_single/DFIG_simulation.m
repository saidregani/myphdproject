function DFIG_simulation
% Chaos suppression and MPPT tracking of a DFIG wind turbine
% using feedback linearization + constrained MPC (ICRAMI 2026)
%
% Parts:
%   1) chaotic dynamics of the dimensionless model (Fig. 1)
%   2) chaos suppression: FL-MPC / FL only / PI        (Table II, Fig. 4)
%   3) MPPT tracking of a 2 MW DFIG                    (Table III, Fig. 2, 5, 6)
%
% needs wind_profile.csv in the same folder (wind used in the paper)

clc; close all;

run_part1 = 1;     % bifurcation diagram takes 10-30 min
run_part2 = 1;
run_part3 = 1;     % about 10 min


%% ===================== PART 1 : chaos =====================
if run_part1
g = -1; s = 8; e = [0; -85; 0];
f = @(z) [-z(1) - z(3)*z(2) + g*z(3) + e(1);
          -z(2) + z(3)*z(1) + e(2);
           s*z(1) - s*z(3) + e(3)];
Jac = @(z) [-1, -z(3), -z(2)+g;  z(3), -1, z(1);  s, 0, -s];

% --- Lyapunov exponents (QR method)
dt = 1e-3;
z = [0.3; 0.6; 1];
for k = 1:200/dt            % transient
    z = rk4(f, z, dt);
end
Q = eye(3); S = zeros(3,1);
fz = @(y) [f(y(1:3)); reshape(Jac(y(1:3))*reshape(y(4:12),3,3), 9, 1)];
y = [z; Q(:)];
for k = 1:500/dt
    y = rk4(fz, y, dt);
    if mod(k,100) == 0
        [Q, R] = qr(reshape(y(4:12),3,3));
        S = S + log(abs(diag(R)));
        y(4:12) = reshape(Q*diag(sign(diag(R))), 9, 1);
    end
end
LE = sort(S/500, 'descend');
fprintf('Lyapunov exponents : %.4f  %.4f  %.4f\n', LE);
fprintf('sum = %.3f   (divergence = %.3f)\n', sum(LE), -(2+s));
fprintf('Kaplan-Yorke dim   : %.3f\n\n', 2 + LE(1)/abs(LE(3)));

% --- attractor
[~, Z] = ode45(@(t,z) f(z), [0 300], [0.3 0.6 1], odeset('RelTol',1e-9,'AbsTol',1e-9,'MaxStep',0.002));
Z = Z(round(end/3):end, :);

% --- bifurcation diagram + largest Lyapunov exponent vs eps2
E2 = linspace(-100, 0, 401);
M = length(E2);
x = repmat([0.3; 0.6; 1], 1, M);
w = ones(3, M)/sqrt(3);
Fv = @(x) [-x(1,:) - x(3,:).*x(2,:) + g*x(3,:);
           -x(2,:) + x(3,:).*x(1,:) + E2;
            s*x(1,:) - s*x(3,:)];
Jv = @(x,w) [-w(1,:) - x(3,:).*w(2,:) + (g - x(2,:)).*w(3,:);
              x(3,:).*w(1,:) - w(2,:) + x(1,:).*w(3,:);
              s*w(1,:) - s*w(3,:)];
ntr = 150/dt; nb = 300/dt;
lam = zeros(1, M);
peaks = cell(1, M);
z3_old2 = []; z3_old1 = [];
for k = 1:ntr+nb
    k1x = Fv(x);           k1w = Jv(x, w);
    k2x = Fv(x+dt/2*k1x);  k2w = Jv(x+dt/2*k1x, w+dt/2*k1w);
    k3x = Fv(x+dt/2*k2x);  k3w = Jv(x+dt/2*k2x, w+dt/2*k2w);
    k4x = Fv(x+dt*k3x);    k4w = Jv(x+dt*k3x, w+dt*k3w);
    x = x + dt/6*(k1x + 2*k2x + 2*k3x + k4x);
    w = w + dt/6*(k1w + 2*k2w + 2*k3w + k4w);
    if mod(k,20) == 0
        nw = sqrt(sum(w.^2, 1));
        if k > ntr, lam = lam + log(nw); end
        w = w./nw;
    end
    if k > ntr
        if ~isempty(z3_old2)
            idx = find(z3_old1 > z3_old2 & z3_old1 >= x(3,:));
            for i = idx
                if length(peaks{i}) < 300, peaks{i}(end+1) = z3_old1(i); end
            end
        end
        z3_old2 = z3_old1; z3_old1 = x(3,:);
    end
end
lam = lam/(nb*dt);

figure;
subplot(2,2,1); plot(Z(:,1), Z(:,2), 'b', 'linewidth', 0.2); xlabel('z_1'); ylabel('z_2'); title('(a)'); grid on
subplot(2,2,2); plot(Z(:,1), Z(:,3), 'b', 'linewidth', 0.2); xlabel('z_1'); ylabel('z_3'); title('(b)'); grid on
subplot(2,2,3); hold on
for i = 1:M
    if ~isempty(peaks{i}), plot(E2(i)*ones(size(peaks{i})), peaks{i}, 'k.', 'markersize', 1); end
end
xlabel('\epsilon_2'); ylabel('local maxima of z_3'); title('(c)'); grid on; box on; xlim([-100 0])
subplot(2,2,4); plot(E2, lam, 'r', 'linewidth', 1); hold on; plot([-100 0], [0 0], 'k--')
xlabel('\epsilon_2'); ylabel('\lambda_{max}'); title('(d)'); grid on; xlim([-100 0])
end


%% ============ PART 2 : chaos suppression (dimensionless model) ============
if run_part2
g = -1; s = 8; e = [0; -85; 0];
tau = 0.0321; ws = 2*pi*50;
z3s = 0.2*ws*tau;                                  % wr = 1.2 ws
zref = [z3s; (-z3s + g*z3s + e(1))/z3s; z3s];      % target (u1 = u3 = 0)
Umax = 120; Tsim = 16; t_on = 6; Ts = 0.01; nsub = 5;

[mpcA, K] = mpc_init(Ts, 15, diag([1 10]), 1e-4);
ke = -K(1); ki = -K(2);

names = {'FL-MPC', 'FL only', 'PI'};
dlist = [0 -0.2 0.2];
res = cell(3,3);
fprintf('Table II : chaos suppression\n');
fprintf('%-8s %-8s %8s %8s %10s\n', 'plant', 'ctrl', 'IAE', 't_s', 'e_f');
for j = 1:3
    d = dlist(j);
    gp = g*(1+d); sp = s*(1+d); ep = e*(1+d); cp = 1+d;     % real plant
    for c = 1:3
        z = [0.3; 0.6; 1]; I = zeros(3,1);
        N = round(Tsim/Ts);
        tt = zeros(N,1); zz = zeros(N,3);
        for k = 1:N
            t = (k-1)*Ts;
            if t < t_on
                u = zeros(3,1);
            else
                er = z - zref;
                ff = -chaos_f(z, g, s, e, 1);               % cancel nonlinearities
                if c == 1           % FL-MPC
                    v = zeros(3,1);
                    for i = 1:3
                        v(i) = mpc_step(mpcA, [er(i); I(i)], -Umax-ff(i), Umax-ff(i));
                    end
                    u = ff + v;
                    I = I + (abs(u) < Umax-1e-9).*er*Ts;
                elseif c == 2       % FL only
                    u = min(max(ff - ke*er, -Umax), Umax);
                else                % PI
                    uc = -ke*er - ki*I;
                    u = min(max(uc, -Umax), Umax);
                    I = I + (uc == u).*er*Ts;
                end
            end
            for jj = 1:nsub
                z = rk4(@(zz_) chaos_f(zz_, gp, sp, ep, cp) + u, z, Ts/nsub);
            end
            tt(k) = t + Ts; zz(k,:) = z';
        end
        % metrics
        m = tt >= t_on;
        en = sqrt(sum((zz(m,:) - zref').^2, 2));
        IAE = sum(en)*Ts;
        out = find(en > 0.02*norm(zref));
        if isempty(out), ts = 0; elseif out(end) == length(en), ts = NaN; else, ts = tt(find(m,1)+out(end)-1) - t_on; end
        fprintf('%+-8.1f %-8s %8.3f %8.3f %10.2e\n', d, names{c}, IAE, ts, en(end));
        res{c,j}.t = tt; res{c,j}.z = zz;
    end
end
fprintf('\n');

figure;
for i = 1:3
    subplot(4,1,i); plot(res{1,1}.t, res{1,1}.z(:,i), 'b'); hold on
    plot([0 10], zref(i)*[1 1], 'k-.'); xlim([0 10]); ylabel(['z_' num2str(i)]); grid on
end
xlabel('normalized time')
subplot(4,1,4); st = {'b-', 'g--', 'r:'};
for c = [1 3 2]
    m = res{c,3}.t >= t_on;
    semilogy(res{c,3}.t(m) - t_on, sqrt(sum((res{c,3}.z(m,:) - zref').^2, 2)), st{c}, 'linewidth', 1); hold on
end
set(gca, 'YScale', 'log', 'YTick', 10.^(-4:2:2)); xlim([0 3]); ylim([1e-4 1e2]); grid on
legend('FL-MPC', 'PI', 'FL only'); xlabel('normalized time after activation'); ylabel('||z - z^*||')
text(0.05, 3e-4, '(b) +20 % mismatch')
end


%% ================= PART 3 : MPPT tracking (2 MW DFIG) =================
if run_part3
% machine (Table I)
Rs = 2.6e-3; Rr = 2.9e-3; Lm = 2.5e-3; Ls = 2.587e-3; Lr = 2.587e-3;
p = 2; J = 127; D = 1e-3; Vll = 690; fs = 50;
% turbine
rho = 1.225; Rb = 40; G = 80; lopt = 8.1;

nom = [Rs Rr Lm Ls Lr p J D Vll fs rho Rb G lopt];
an = dfig_coef(nom);                    % model used by the controller

% wind and references
W = csvread('wind_profile.csv', 1, 0);
t = W(:,1); v = W(:,2); Ts = t(2) - t(1);
vf = v;
for k = 2:length(v), vf(k) = vf(k-1) + Ts/2*(v(k) - vf(k-1)); end     % low-pass, 2 s
wr_ref  = p*G*lopt*vf/Rb;
idr_ref = (gradient(wr_ref,Ts) + an.a7*wr_ref - p*aero(v, wr_ref, an)/J)/an.a6;
iqr_ref = an.psi/Lm*ones(size(t));
xr  = [idr_ref iqr_ref wr_ref];
dxr = [gradient(idr_ref,Ts) gradient(iqr_ref,Ts) gradient(wr_ref,Ts)];

Umax = [200*an.a4; 200*an.a4; 2000*p/J];     % 200 V on rotor voltages, 2 kNm on torque
sc = [1e3; 1e3; 100];
[mpcB, K] = mpc_init(Ts, 10, diag([1 3]), 1e-6);
ke = -K(1); ki = -K(2);

% plants: nominal, M1, M2  (factors on Rs, Rr, Lm, J)
fac = [1 1 1 1; 1.2 1.2 0.9 1.2; 0.8 0.8 1.1 0.8];
pname = {'nom', 'M1', 'M2'};
Ps = @(i) -1.5*an.ws*an.psi*Lm/Ls*i;

fprintf('Table III : MPPT tracking (RMS errors, t >= 5 s)\n');
fprintf('%-5s %-8s %9s %9s %9s\n', 'plant', 'ctrl', 'Ps [%]', 'idr [A]', 'wr');
for j = 1:3
    pp = nom;
    pp(1) = Rs*fac(j,1); pp(2) = Rr*fac(j,2); pp(3) = Lm*fac(j,3);
    pp(4) = pp(3) + (Ls - Lm); pp(5) = pp(3) + (Lr - Lm);      % same leakage
    pp(7) = J*fac(j,4);
    ap = dfig_coef(pp);                                       % real plant
    for c = 1:3
        x = [0; 0; 0.9*wr_ref(1)]; I = zeros(3,1);
        N = length(t) - 1;
        X = zeros(N,3); U = zeros(N,3);
        for k = 1:N
            er = x - xr(k,:)';
            ff = -dfig_f(x, an, v(k)) + dxr(k,:)';
            if c == 1
                vv = zeros(3,1);
                for i = 1:3
                    vv(i) = sc(i)*mpc_step(mpcB, [er(i); I(i)]/sc(i), (-Umax(i)-ff(i))/sc(i), (Umax(i)-ff(i))/sc(i));
                end
                u = min(max(ff + vv, -Umax), Umax);
                I = I + (abs(u) < Umax-1e-9).*er./sc*Ts;
            elseif c == 2
                u = min(max(ff - ke*er, -Umax), Umax);
            else
                uc = -ke*er - ki*I;
                u = min(max(uc, -Umax), Umax);
                I = I + (uc == u).*er*Ts;
            end
            for jj = 1:4
                x = rk4(@(xx) dfig_f(xx, ap, v(k)) + u, x, Ts/4);
            end
            X(k,:) = x'; U(k,:) = u';
        end
        tk = t(2:end); XR = xr(2:end,:);
        m = tk >= 5;
        rm = sqrt(mean((X(m,:) - XR(m,:)).^2));
        rP = 100*sqrt(mean((Ps(X(m,1)) - Ps(XR(m,1))).^2))/2e6;
        fprintf('%-5s %-8s %9.3f %9.2f %9.5f\n', pname{j}, names_ctrl(c), rP, rm(1), rm(3));
        if j == 1 && c == 1, Xmpc = X; end
        if j == 1 && c == 3, Xpi = X; end
    end
end

tk = t(2:end); XR = xr(2:end,:);
figure;
plot(t, v, 'color', [0.2 0.45 0.8]); hold on; plot(t, vf, 'k', 'linewidth', 1.5)
xlabel('time (s)'); ylabel('wind speed (m/s)'); legend('v(t)', 'filtered'); grid on

figure; lab = {'i_{dr} (kA)', 'i_{qr} (kA)', '\omega_r (rad/s)'}; k_ = [1e-3 1e-3 1];
for i = 1:3
    subplot(3,1,i); plot(tk, XR(:,i)*k_(i), 'r', 'linewidth', 1.5); hold on
    plot(tk, Xmpc(:,i)*k_(i), 'b'); ylabel(lab{i}); grid on
end
subplot(3,1,1); legend('reference', 'FL-MPC'); subplot(3,1,3); xlabel('time (s)')

figure;
subplot(3,1,[1 2]); plot(tk, Ps(XR(:,1))/1e6, 'r', 'linewidth', 1.5); hold on; plot(tk, Ps(Xmpc(:,1))/1e6, 'b')
ylabel('P_s (MW)'); legend('P_{s,ref}', 'P_s'); grid on
subplot(3,1,3); plot(tk, (Ps(Xpi(:,1)) - Ps(XR(:,1)))/1e3, 'g'); hold on
plot(tk, (Ps(Xmpc(:,1)) - Ps(XR(:,1)))/1e3, 'b'); ylim([-250 250])
xlabel('time (s)'); ylabel('error (kW)'); legend('PI', 'FL-MPC'); grid on
end
end


%% ============================ functions ============================

function n = names_ctrl(c)
nm = {'FL-MPC', 'FL only', 'PI'}; n = nm{c};
end

function x = rk4(f, x, h)
k1 = f(x); k2 = f(x + h/2*k1); k3 = f(x + h/2*k2); k4 = f(x + h*k3);
x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
end

function dz = chaos_f(z, g, s, e, c)
% dimensionless DFIG model, Eq. (5)
dz = [-c*z(1) - z(3)*z(2) + g*z(3) + e(1);
      -c*z(2) + z(3)*z(1) + e(2);
       s*z(1) - s*z(3) + e(3)];
end

function a = dfig_coef(P)
% coefficients of Eq. (4)
Rs = P(1); Rr = P(2); Lm = P(3); Ls = P(4); Lr = P(5); p = P(6); J = P(7); D = P(8);
a.ws  = 2*pi*P(10);
a.psi = sqrt(2)*P(9)/sqrt(3)/a.ws;
sig   = 1 - Lm^2/(Ls*Lr);
a.a1 = -Rs*Lm^2/(sig*Ls^2*Lr) - Rr/(sig*Lr);
a.a2 = -Lm*a.psi/(sig*Lr*Ls);
a.a3 = -Lm/(sig*Ls*Lr);
a.a4 = 1/(sig*Lr);
a.a5 = Rs*Lm*a.psi/(sig*Ls^2*Lr);
a.a6 = 3*p^2*Lm*a.psi/(2*J*Ls);
a.a7 = D/J;
a.c1 = a.a3*(-a.ws*a.psi);          % u_ds = -ws*psi
a.c2 = a.a5;                        % u_qs = 0
a.p = p; a.J = J;
a.rho = P(11); a.R = P(12); a.G = P(13);
end

function T = aero(v, wr, a)
% aerodynamic torque on the generator shaft
Wm  = max(wr, 1)/a.p;
lam = a.R*Wm./(a.G*max(v, 0.5));
lam = min(max(lam, 2), 13);
li  = 1./(1./lam - 0.035);
Cp  = max(0.5176*(116./li - 5).*exp(-21./li) + 0.0068*lam, 0);
T   = 0.5*a.rho*pi*a.R^2*Cp.*v.^3./Wm;
end

function dx = dfig_f(x, a, v)
% DFIG model, Eq. (3), T_L = -T_a
a8 = -a.p*aero(v, x(3), a)/a.J;
dx = [ a.a1*x(1) + (a.ws - x(3))*x(2) + a.a2*x(3) + a.c1;
      -(a.ws - x(3))*x(1) + a.a1*x(2) + a.c2;
       a.a6*x(1) - a.a7*x(3) - a8];
end

function [mpc, K] = mpc_init(Ts, N, Q, r)
% error model with integral state : xi(k+1) = A xi(k) + B v(k)
A = [1 0; Ts 1]; B = [Ts; Ts^2/2];

% terminal weight P and gain K from the LMI (15) = solution of the DARE
% (doubling algorithm, no toolbox needed)
Ak = A; Gk = B*B'/r; Hk = Q;
for it = 1:200
    W  = eye(2) + Gk*Hk;
    A1 = Ak/W*Ak;  G1 = Gk + Ak/W*Gk*Ak';  H1 = Hk + Ak'*Hk/W*Ak;
    if norm(H1 - Hk, 'fro') <= 1e-13*norm(H1, 'fro'), Hk = H1; break; end
    Ak = A1; Gk = G1; Hk = H1;
end
P = (Hk + Hk')/2;
K = -(r + B'*P*B) \ (B'*P*A);

% check of the LMI (15) with X = inv(P), Y = K*X
X = inv(P); Y = K*X; Qh = chol(Q);
LMI = [X, (A*X+B*Y)', X*Qh', sqrt(r)*Y';
       A*X+B*Y, X, zeros(2), zeros(2,1);
       Qh*X, zeros(2), eye(2), zeros(2,1);
       sqrt(r)*Y, zeros(1,2), zeros(1,2), 1];
fprintf('LMI check: min eig = %.2e   K = [%.2f  %.2f]\n', min(eig((LMI+LMI')/2)), K);

% prediction matrices
Phi = zeros(2*N, 2); Gam = zeros(2*N, N);
for i = 1:N
    Phi(2*i-1:2*i, :) = A^i;
    for j = 0:i-1
        Gam(2*i-1:2*i, j+1) = A^(i-1-j)*B;
    end
end
Wb = zeros(2*N);
for i = 1:N-1, Wb(2*i-1:2*i, 2*i-1:2*i) = chol(Q); end
Wb(2*N-1:2*N, 2*N-1:2*N) = chol(Q + P);
mpc.N  = N;
mpc.WG = [Wb*Gam; sqrt(r)*eye(N)];
mpc.WP = [Wb*Phi; zeros(N,2)];
mpc.H  = mpc.WG'*mpc.WG;
end

function v0 = mpc_step(mpc, xi, lb, ub)
% QP (14): min ||WG*V + WP*xi||^2 , lb <= V <= ub  -> first move
if lb > ub, lb = (lb+ub)/2; ub = lb; end
g  = mpc.WG'*(mpc.WP*xi);
lo = lb*ones(mpc.N,1); hi = ub*ones(mpc.N,1);
% active set method for box constraints (same result as quadprog)
V = min(max(-mpc.H\g, lo), hi);
for it = 1:10*mpc.N + 20
    gr = mpc.H*V + g;
    fix = (V <= lo & gr >= 0) | (V >= hi & gr <= 0);
    fr = ~fix;
    if ~any(fr), break; end
    Vf = -mpc.H(fr,fr) \ (g(fr) + mpc.H(fr,fix)*V(fix));
    d  = Vf - V(fr);
    if norm(d, inf) <= 1e-12*max(1, norm(V, inf)), break; end
    Vc = V(fr); l = lo(fr); h = hi(fr); al = 1;
    if any(d < 0), al = min(al, min((l(d<0) - Vc(d<0))./d(d<0))); end
    if any(d > 0), al = min(al, min((h(d>0) - Vc(d>0))./d(d>0))); end
    V(fr) = min(max(Vc + max(al,0)*d, l), h);
end
v0 = V(1);
end
