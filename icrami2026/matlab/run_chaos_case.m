function out = run_chaos_case(ctrl, dlt)
%RUN_CHAOS_CASE Chaos suppression in model (5); controller switched on at t_on = 6.
%   ctrl: 'mpc' (FL-MPC, proposed), 'fl' (FL only), 'pi' (PI).  dlt: plant mismatch (0, -0.2, 0.2).
g0 = -1; s0 = 8; e0 = [0; -85; 0];
tau = 0.0321; ws = 2*pi*50;
z3s = 0.2*ws*tau;                                   % omega_r = 1.2 omega_s
zt  = [z3s; (-z3s + g0*z3s + e0(1))/z3s; z3s];      % target, u1* = u3* = 0
U = 120;  T = 16;  t_on = 6;  Ts = 0.01;  sub = 5;  h = Ts/sub;
gp = g0*(1+dlt); sp = s0*(1+dlt); ep = e0*(1+dlt); cp = 1+dlt;   % perturbed plant
mpc = mpc_build(Ts, 15, diag([1 10]), 1e-4);
ke = -mpc.K(1);  ki = -mpc.K(2);                    % same LMI gain for all controllers
z = [0.3; 0.6; 1.0];  I = zeros(3,1);  n = round(T/Ts);
out.t = zeros(n,1); out.z = zeros(n,3); out.u = zeros(n,3); out.zt = zt;
for k = 1:n
    t = (k-1)*Ts;
    if t < t_on
        u = zeros(3,1);
    else
        e  = z - zt;
        ff = -chaos_rhs(z, g0, s0, e0);             % x_d constant -> xd_dot = 0
        switch ctrl
            case 'mpc'
                v = zeros(3,1);
                for i = 1:3
                    v(i) = mpc_solve(mpc, [e(i); I(i)], -U - ff(i), U - ff(i));
                end
                u = ff + v;
                I = I + (abs(u) < U - 1e-9) .* e * Ts;      % conditional integration
            case 'fl'
                u = min(max(ff - ke*e, -U), U);
            case 'pi'
                ucmd = -ke*e - ki*I;
                u = min(max(ucmd, -U), U);
                I = I + (ucmd == u) .* e * Ts;               % clamping anti-windup
        end
    end
    f = @(zz) chaos_rhs(zz, gp, sp, ep, cp) + u;
    for j = 1:sub
        k1 = f(z); k2 = f(z + h/2*k1); k3 = f(z + h/2*k2); k4 = f(z + h*k3);
        z = z + h/6*(k1 + 2*k2 + 2*k3 + k4);
    end
    out.t(k) = t + Ts;  out.z(k,:) = z';  out.u(k,:) = u';
end
% metrics (Table II)
m  = out.t >= t_on;  tt = out.t(m);
en = sqrt(sum((out.z(m,:) - zt').^2, 2));
out.IAE = sum(en) * Ts;
idx = find(en > 0.02*norm(zt));
if isempty(idx), out.ts = 0; elseif idx(end) == numel(en), out.ts = NaN; else, out.ts = tt(idx(end)) - t_on; end
out.ef = en(end);
end
