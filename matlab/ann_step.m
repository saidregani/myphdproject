function [uAI, nn] = ann_step(nn, zn, en, Ts, learn)
%ANN_STEP  One step of the adaptive ANN compensator (Eqs. (52)-(68) of the
%Mathematics paper):
%   h = tanh(W1 zn + b1),  y = W2 h + b2,  u_AI = K_AI sat(y)
%   r_a = B'e if ||e|| > delta, 0 otherwise           (dead-zone)
%   dW2 = -G r_a h' - s W2,  db2 = -G r_a - s b2
%   d_h = (1 - h.^2) .* (W2' r_a)                     (back-propagation)
%   dW1 = -G d_h zn' - s W1, db1 = -G d_h - s b1
% en is the normalised control-direction error B'e (one entry per output).
if ~nn.on, uAI = zeros(size(nn.b2)); return; end
h   = tanh(nn.W1*zn + nn.b1);
y   = nn.W2*h + nn.b2;
uAI = nn.KAI*min(max(y, -nn.ysat), nn.ysat);
if ~learn, return; end
ra  = en*(norm(en) > nn.delta && norm(en) <= nn.rmax);
dh  = (1 - h.^2).*(nn.W2'*ra);
G = nn.eta;  s = nn.sigma;
if nn.norm, G = G/(1 + zn'*zn); end            % normalized gradient
nn.W2 = nn.W2 + Ts*(-G*ra*h'  - s*nn.W2);
nn.b2 = nn.b2 + Ts*(-G*ra     - s*nn.b2);
nn.W1 = nn.W1 + Ts*(-G*dh*zn' - s*nn.W1);
nn.b1 = nn.b1 + Ts*(-G*dh     - s*nn.b1);
end
