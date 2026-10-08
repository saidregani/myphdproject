function S = ctrl_init(P, type, x0, vw0, u0)
%CTRL_INIT  Controller gains and internal states.
%   type = 'PI'   : classical vector control (cascaded PI loops)
%   type = 'PIFF' : same + feed-forward of P_msc in the DC-bus loop
%   type = 'FPBC': flatness (outer) + passivity-based (inner) control
%                  + adaptive ANN compensation u = u_N + u_AI
%   type = 'FPBC0': same as FPBC with the ANN disabled (fixed gains)
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

S.ff = strcmp(type, 'PIFF');
switch type
  case {'PI', 'PIFF'}
    % current loops: Kp = L/tau, Ki = L/(4 tau^2) -> double pole 1/(2 tau)
    S.Kps = P.Ls/tau_i;  S.Kis = P.Ls/(4*tau_i^2);
    S.Kpg = P.Lf/tau_i;  S.Kig = P.Lf/(4*tau_i^2);
    % speed loop:  J s^2 + Kp s + Ki
    S.Kpw = 2*zw*wnw*P.J;  S.Kiw = wnw^2*P.J;
    % DC bus (linearised):  C Vdc s^2 + 1.5 vgd (Kp s + Ki)
    S.Kpv = 2*zv*wnv*P.C*P.Vdc_ref/(1.5*P.Vgm);
    S.Kiv = wnv^2   *P.C*P.Vdc_ref/(1.5*P.Vgm);
    % integrator states (stored as integral-term values)
    S.Iw = Tw0;  S.Iv = x0(5)*(~S.ff);  S.Is = [0; 0];  S.Ig = [0; 0];

  case {'FPBC', 'FPBC0'}
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
    % adaptive ANN compensator (6-10-2), see ann_init.m / ann_step.m
    A = P.ann;
    S.nn  = ann_init(6, 10, 2, A);
    S.nn.on = strcmp(type, 'FPBC');                  % FPBC0: nominal only
    S.uAI = [0; 0];  S.satw = false;  S.satv = false;
    S.sw = A.e_w*P.wn;                               % input normalisation S_in
    S.sy = A.e_y;  S.si = A.e_i*S.Ibs;
    S.tz = A.tz;   S.tau_z = A.tau_z;  S.e_f = [0; 0; 0];
    S.uT = A.uT*P.Tn;  S.uP = A.uP*P.Pn;             % output scaling
  otherwise
    error('unknown controller type');
end
end
