%% Parameters of the Simulink model PMSG_WECS_blocks (run automatically by InitFcn)
% Scenario selection (can be set in the Command Window before sim):
%   scenario = 'step' | 'nominal' | 'robust' ;  useANN = 1 | 0
if ~exist('scenario', 'var'), scenario = 'robust'; end
if ~exist('useANN', 'var'),   useANN = 1;         end

%% Turbine
rho = 1.225;  R = 40;  Pn = 2e6;  Wn = 2.23;  Tn = Pn/Wn;
J = 2.8e6;  B = 1e3;  lopt = 8.1;  vn = Wn*R/lopt;
lam_tab = linspace(1, 16, 301);
li_tab  = 1./(1./lam_tab - 0.035);
cp_tab  = max(0.5176*(116./li_tab - 5).*exp(-21./li_tab) + 0.0068*lam_tab, 0);

%% PMSG (Hasan & Shatil, AJSE 2021, Table I)
p = 26;  Rs = 0.78e-3;  Ls = 1.57e-3;  psi = 9.18;

%% DC link, filter, grid
C = 20e-3;  Vdcr = 1200;  Vgm = 690*sqrt(2/3);  wg = 2*pi*50;
Lf = 0.15e-3;  Rf = 2e-3;  fsw = 2160;
In = Pn/(1.5*Vgm);  Temax = 1.2*Tn;  Igmax = 1.3*In;  Wmin = 0.5*Wn;  Wmax = Wn;

%% Sampling and simulation
Ts = 1/(2*fsw);  Tend = 40;  Tlog = 10*Ts;

%% Wind
Vm = 8.5;  Aw = [1.5 0.2 0.3];  fw = [0.03 0.16 0.17];
sig_t = 0.5;  tau_t = 1.5;  seed = 12345;  tau_a = 1.0;
Tn_w = 4*Ts;  an = exp(-Tn_w/tau_t);  gn = sqrt(1 - an^2)*sig_t;

%% Control
wr = 1;  wW = 2;  k11 = 2*wW;  k12 = wW^2;  wv = 60;  k21 = 2*wv;  k22 = wv^2;
wi = 500;  Ra = 2*wi*Ls - Rs;  Ki = wi^2*Ls;  Rb = 2*wi*Lf - Rf;  Kig = wi^2*Lf;
taud = 2e-3;  kI = k12*(1 - useANN);
[c1g, c2g] = meshgrid(linspace(0.5, 1.1, 5), linspace(0.5, 1.1, 5));
c1 = c1g(:);  c2 = c2g(:);  b = 0.15;  Gam = 1e7;  sig = 0.02;

%% True plant (robustness scenario: parameter mismatch + 50 % grid voltage dip)
kTw = 1;  Jt = J;  Rst = Rs;  Lst = Ls;  psit = psi;  Rft = Rf;  Lft = Lf;  Bt = B;
windStep = 0;  v0 = Vm;  kdip = 0;  tdip = 25;  ddip = 0.15;
switch scenario
  case 'step'
    windStep = 1;  v0 = 9;
  case 'robust'
    kTw = 1.10;  Jt = 1.2*J;  Rst = 1.5*Rs;  Lst = 1.2*Ls;  psit = 0.95*psi;
    Rft = 1.5*Rf;  Lft = 1.25*Lf;  kdip = 0.5;
end

%% Initial equilibrium (MPPT at v0, isd = 0, unity power factor)
cpf  = @(l) max(0.5176*(116./(1./(1./l - 0.035)) - 5).*exp(-21./(1./(1./l - 0.035))) + 0.0068*l, 0);
aero = @(W, v) 0.5*rho*pi*R^2*cpf(W*R/v)*v^3/W;
W0   = min(max(lopt*v0/R, Wmin), Wmax);
isq0 = -(kTw*aero(W0, v0) - Bt*W0)/(1.5*p*psit);
we0  = p*W0;
us0  = [-we0*Lst*isq0; Rst*isq0 + we0*psit];
Pdc0 = -1.5*us0(2)*isq0;
igd0 = (-Vgm + sqrt(Vgm^2 + 4*Rft*Pdc0/1.5))/(2*Rft);
ui0  = [Rft*igd0 + Vgm; wg*Lft*igd0];
Te0c = 1.5*p*psi*isq0;
zW0  = (B*W0 - aero(W0, v0) - Te0c)/(J*k12) * (1 - useANN);
