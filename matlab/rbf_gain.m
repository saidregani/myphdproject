function [g, net] = rbf_gain(net, en, den, Ts)
%RBF_GAIN  Online ANN tuning of a damping-injection gain multiplier.
% Cost E = 0.5*en^2. Since the closed-loop error obeys L*de/dt = -K*e + ...,
% dE/dK ~ -e^2*Ts/L < 0: steepest descent raises the gain while the error is
% large; the sigma-modification leakage brings it back to nominal (g = 1)
% in steady state and keeps the weights bounded. g stays in [gmin, gmax]
% (> 0), so the Lyapunov proofs of the passivity-based loops still hold.
x   = [clamp(en, -1.5, 1.5); clamp(den, -1.5, 1.5)];
d2  = sum((net.C - x*ones(1, size(net.C, 2))).^2, 1);
phi = exp(-d2' / (2*net.width^2));
a   = net.w'*phi + net.b0;
sg  = 1/(1 + exp(-a));
g   = net.gmin + (net.gmax - net.gmin)*sg;
grad = (net.gmax - net.gmin)*sg*(1 - sg)*phi;     % dg/dw
net.w = net.w + Ts*(net.eta*min(en^2, 4)*grad - net.sigma*net.w);
end
