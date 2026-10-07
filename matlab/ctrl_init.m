function S = ctrl_init(P, type, x0, vw0, u0)
%CTRL_INIT  Controller gains and internal states.
%   type = 'PI'  : classical vector control (cascaded PI loops)
%   type = 'FPBC': flatness (outer) + passivity-based (inner) control
%                  with ANN online gain tuning
S.type = type;
S.u    = u0;                                  % last applied voltages
% common MPPT reference generator
S.vf = vw0;  S.wr = x0(3);  S.dwr = 0;

% Base quantities (normalisation, ANN inputs)
S.Ibs = P.Tn/(1.5*P.p*P.psi);
S.Ibg = P.Pn/(1.5*P.Vgm);

% Design targets shared by both controllers (same nominal bandwidths)
tau_i = 2e-3;                % current loops time constant          [s]
wnw = 2;  zw = 0.9;          % speed loop natural freq / damping
wnv = 60; zv = 1;            % DC-bus loop natural freq / damping

Tw0 = 1.5*P.p*P.psi*x0(2) + P.B*x0(3);

switch type
  case 'PI'
    % current loops: Kp = L/tau, Ki = L/(4 tau^2) -> double pole 1/(2 tau)
    S.Kps = P.Ls/tau_i;  S.Kis = P.Ls/(4*tau_i^2);
    S.Kpg = P.Lf/tau_i;  S.Kig = P.Lf/(4*tau_i^2);
    % speed loop:  J s^2 + Kp s + Ki
    S.Kpw = 2*zw*wnw*P.J;  S.Kiw = wnw^2*P.J;
    % DC bus (linearised):  C Vdc s^2 + 1.5 vgd (Kp s + Ki)
    S.Kpv = 2*zv*wnv*P.C*P.Vdc_ref/(1.5*P.Vgm);
    S.Kiv = wnv^2   *P.C*P.Vdc_ref/(1.5*P.Vgm);
    % integrator states (stored as integral-term values)
    S.Iw = Tw0;  S.Iv = x0(5);  S.Is = [0; 0];  S.Ig = [0; 0];

  case 'FPBC'
    % outer loops (flatness): e_dot + k1 e + k2 int(e) = 0  (same poles as PI)
    S.k11 = 2*zw*wnw;  S.k12 = wnw^2;      % speed   (flat output Omega)
    S.k21 = 2*zv*wnv;  S.k22 = wnv^2;      % DC bus  (flat output energy y2)
    S.zw = 0;  S.zv = 0;
    % inner loops (PBC): damping injection Ra, Rb + integral injection
    S.Ra0 = P.Ls/tau_i;  S.Kis = P.Ls/(4*tau_i^2);  S.zs = [0; 0];
    S.Rb0 = P.Lf/tau_i;  S.Kig = P.Lf/(4*tau_i^2);  S.zg = [0; 0];
    % dirty-derivative filters for the current references
    S.tau_d = 2e-3;
    S.is_f = [0; x0(2)];  S.ig_f = [x0(5); 0];
    S.en_s = 0; S.en_g = 0; S.en_w = 0; S.en_v = 0;   % ANN de/dt
    % ANN gain tuners: (gmin, gmax, learning rate, leakage)
    S.nn_s = rbf_init(0.5, 3, 100, 5);
    S.nn_g = rbf_init(0.5, 3, 100, 5);
    S.nn_w = rbf_init(0.5, 3, 20, 1);
    S.nn_v = rbf_init(0.5, 3, 50, 3);
  otherwise
    error('unknown controller type');
end
end
