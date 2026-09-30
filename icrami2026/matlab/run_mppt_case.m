function out = run_mppt_case(ctrl, plant)
%RUN_MPPT_CASE MPPT tracking of the 2-MW-class DFIG under turbulent wind (Sec. VI-B).
%   ctrl : 'mpc' (FL-MPC, proposed), 'fl' (FL only), 'pi' (PI)
%   plant: 'nom', 'm1' (Rs,Rr +20 %, Lm -10 %, J +20 %), 'm2' (Rs,Rr -20 %, Lm +10 %, J -20 %)
pn = dfig_params();  pp = pn;
switch plant
    case 'm1', f = [1.2 1.2 0.9 1.2];
    case 'm2', f = [0.8 0.8 1.1 0.8];
    otherwise, f = [1 1 1 1];
end
lls = pp.Ls - pp.Lm;  llr = pp.Lr - pp.Lm;           % leakage kept constant -> Ls, Lr > Lm
pp.Rs = pp.Rs*f(1);  pp.Rr = pp.Rr*f(2);  pp.Lm = pp.Lm*f(3);
pp.Ls = pp.Lm + lls;  pp.Lr = pp.Lm + llr;  pp.J = pp.J*f(4);
an = dfig_coeffs(pn);  ap = dfig_coeffs(pp);         % controller model / plant
% ---- wind (same realization as in the paper) and MPPT references, Eqs. (7)-(10)
W = csvread('wind_profile.csv', 1, 0);  t = W(:,1);  v = W(:,2);  Ts = t(2) - t(1);
vf = v;  for k = 2:numel(v), vf(k) = vf(k-1) + Ts/2.0*(v(k) - vf(k-1)); end
x3r = an.np*an.G*an.lopt*vf/an.R;
dx3r = gradient(x3r, Ts);
a8 = -an.np*aero_torque(v, x3r, an)/an.J;
x1r = (dx3r + an.a7*x3r + a8)/an.a6;
x2r = an.psi/an.Lm*ones(size(t));
xr = [x1r x2r x3r];  dxr = [gradient(x1r,Ts) gradient(x2r,Ts) gradient(x3r,Ts)];
% ---- controller
Umax = [200*an.a4; 200*an.a4; 2000*an.np/an.J];     % |du_dr|,|du_qr| <= 200 V, |dT| <= 2 kN m
sc = [1e3; 1e3; 100];                                % error scaling (A, A, rad/s)
mpc = mpc_build(Ts, 10, diag([1 3]), 1e-6);
ke = -mpc.K(1);  ki = -mpc.K(2);                     % same LMI gain for all controllers
% ---- simulation
sub = 4;  h = Ts/sub;  n = numel(t) - 1;
x = [0; 0; 0.9*x3r(1)];  I = zeros(3,1);
X = zeros(n,3);  U = zeros(n,3);
for k = 1:n
    e  = x - xr(k,:)';
    ff = -dfig_rhs(x, an, v(k)) + dxr(k,:)';
    switch ctrl
        case 'mpc'
            vv = zeros(3,1);
            for i = 1:3
                vv(i) = sc(i)*mpc_solve(mpc, [e(i); I(i)]/sc(i), (-Umax(i) - ff(i))/sc(i), (Umax(i) - ff(i))/sc(i));
            end
            u = min(max(ff + vv, -Umax), Umax);
            I = I + (abs(u) < Umax - 1e-9) .* e ./ sc * Ts;   % conditional integration
        case 'fl'
            u = min(max(ff - ke*e, -Umax), Umax);
        case 'pi'
            ucmd = -ke*e - ki*I;
            u = min(max(ucmd, -Umax), Umax);
            I = I + (ucmd == u) .* e * Ts;
    end
    fp = @(xx) dfig_rhs(xx, ap, v(k)) + u;
    for j = 1:sub
        k1 = fp(x); k2 = fp(x + h/2*k1); k3 = fp(x + h/2*k2); k4 = fp(x + h*k3);
        x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
    end
    X(k,:) = x';  U(k,:) = u';
end
out.t = t(2:end);  out.x = X;  out.xr = xr(2:end,:);  out.u = U;  out.a = an;
out.tw = t;  out.vw = v;  out.vf = vf;
% ---- metrics (Table III), t >= 5 s
m  = out.t >= 5;  err = out.x(m,:) - out.xr(m,:);
out.rmse = sqrt(mean(err.^2, 1));
Ps = @(x1) -1.5*an.ws*an.psi*an.Lm/an.Ls*x1;
out.rmse_P_pct = 100*sqrt(mean((Ps(out.x(m,1)) - Ps(out.xr(m,1))).^2))/2e6;
out.dT_rms = sqrt(mean(out.u(m,3).^2))*an.J/an.np;
end
