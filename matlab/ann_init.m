function nn = ann_init(nin, nh, nout, A)
%ANN_INIT  Adaptive MLP compensator (nin - nh - nout, tanh hidden layer), as
%in Regani, Messadi, Kemih, "A Novel Chaos Control Approach with Adaptive
%ANN Compensation for a DFIG-Based Wind Turbine" (Mathematics).
% W1, b1 get a small deterministic initialisation (no rng dependence) so
% that the hidden layer is active; W2 = 0, b2 = 0 so u_AI(0) = 0.
nn.W1 = 0.5*sin((1:nh)'*(1:nin)*0.7 + 0.3);
nn.b1 = 0.1*cos((1:nh)'*1.3);
nn.W2 = zeros(nout, nh);
nn.b2 = zeros(nout, 1);
nn.eta   = A.eta;      % adaptation gains Gamma_W1 = Gamma_b1 = Gamma_W2 = Gamma_b2
nn.sigma = A.sigma;    % regularisation (sigma-modification) coefficients
nn.delta = A.delta;    % dead-zone threshold on the normalised error
nn.ysat  = A.ysat;     % output saturation
nn.KAI   = A.KAI;      % ANN coefficient
nn.on    = true;
end
