function net = rbf_init(gmin, gmax, eta, sigma)
%RBF_INIT  Gaussian RBF network used as an online gain tuner.
% 2 inputs (normalised error and error derivative), 3x3 grid of centres,
% scalar output mapped to a bounded gain multiplier g in [gmin, gmax].
[c1, c2]  = meshgrid([-1 0 1], [-1 0 1]);
net.C     = [c1(:)'; c2(:)'];          % centres (2 x 9)
net.width = 0.7;
net.w     = zeros(9, 1);               % output weights (trained online)
net.gmin  = gmin;
net.gmax  = gmax;
net.b0    = log((1 - gmin)/(gmax - 1));% g = 1 when w = 0
net.eta   = eta;                       % learning rate
net.sigma = sigma;                     % leakage (sigma-modification)
net.off   = false;                     % true -> fixed gain g = 1 (no ANN)
end
