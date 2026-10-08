%% Main program
function RES = PMSG_WECS(mode, opt)

if nargin < 1, mode = 'full'; end
P = wecs_params();
if strcmp(mode, 'quick'), P.Tend = 5; end
if strcmp(mode, 'single')
  if isfield(opt, 'set')
    f = fieldnames(opt.set);
    for j = 1:numel(f), P = setfield_path(P, f{j}, opt.set.(f{j})); end
  end
  RES = wecs_simulate(P, opt.ctrl, opt.scen);
  M = RES.M;  fprintf('RES %s %s IAE_W=%.5g RMSisq=%.4g dVmax=%.4g dVdip=%.4g E=%.5g eta=%.4f Testd=%.4g\n', ...
    opt.scen, opt.ctrl, M.IAE_W, M.RMS_isq, M.dV_max, M.dV_dip, M.E_kWh, M.eta_mppt, M.Te_std);
  return
end

ctrls = {'PI', 'FP', 'FPANN'};
scens = {'nominal', 'robust'};
RES = struct();
for s = 1:numel(scens)
  for c = 1:numel(ctrls)
    t0 = tic;
    r = wecs_simulate(P, ctrls{c}, scens{s});
    RES.(scens{s}).(ctrls{c}) = r;
    fprintf('%-8s %-6s done in %5.1f s\n', scens{s}, ctrls{c}, toc(t0));
  end
end
wecs_table(RES, scens, ctrls);
wecs_export(RES, scens, ctrls);
wecs_plots(RES, P);
end

%% Parameter override
function P = setfield_path(P, name, val)
k = strfind(name, '_');
if ~isempty(k) && isfield(P, name(1:k(1)-1)) && isstruct(P.(name(1:k(1)-1)))
  P.(name(1:k(1)-1)).(name(k(1)+1:end)) = val;
else
  P.(name) = val;
end
end

%% Parameters
function P = wecs_params()
P.rho  = 1.225;
P.R    = 40;
P.Pn   = 2e6;
P.Wn   = 2.23;
P.Tn   = P.Pn/P.Wn;
P.J    = 2.8e6;
P.B    = 1e3;
P.lopt = 8.1;  P.Cpmax = 0.48;
P.vn   = P.Wn*P.R/P.lopt;
P.p    = 26;  P.Rs = 0.78e-3;  P.Ls = 1.57e-3;  P.psi = 9.18;
P.C    = 20e-3;  P.Vdcr = 1200;
P.Vgll = 690;  P.Vgm = P.Vgll*sqrt(2/3);  P.fg = 50;  P.wg = 2*pi*P.fg;
P.Lf   = 0.15e-3;  P.Rf = 2e-3;  P.Qr = 0;
P.fsw  = 2160;
P.In    = P.Pn/(1.5*P.Vgm);
P.Temax = 1.2*P.Tn;
P.Isqmx = P.Temax/(1.5*P.p*P.psi);
P.Igmax = 1.3*P.In;
P.Wmin  = 0.5*P.Wn;  P.Wmax = P.Wn;
P.Ts   = 1/(2*P.fsw);
P.Tend = 40;
P.dec  = 10;
P.Vm   = 8.5;  P.Aw = [1.5 0.2 0.3];  P.fw = [0.03 0.16 0.17];
P.sig_t = 0.5;  P.tau_t = 1.5;  P.seed = 12345;
P.tau_a = 1.0;
P.wr   = 1.0;
P.wW = 2;    P.k11 = 2*P.wW;  P.k12 = P.wW^2;
P.wv = 60;   P.k21 = 2*P.wv;  P.k22 = P.wv^2;
P.wi = 500;
P.Ra  = 2*P.wi*P.Ls - P.Rs;  P.Ki  = P.wi^2*P.Ls;
P.Rb  = 2*P.wi*P.Lf - P.Rf;  P.Kig = P.wi^2*P.Lf;
P.taud = 2e-3;
[c1, c2] = meshgrid(linspace(0.5, 1.1, 5), linspace(0.5, 1.1, 5));
P.nn.c   = [c1(:)'; c2(:)'];  P.nn.b = 0.15;
P.nn.Gam = 1e7;
P.nn.sig = 0.02;
P.rob.kTw = 1.10;  P.rob.kJ = 1.2;  P.rob.kRs = 1.5;  P.rob.kLs = 1.2;
P.rob.kpsi = 0.95; P.rob.kRf = 1.5; P.rob.kLf = 1.25;
P.rob.tdip = 25;   P.rob.ddip = 0.15;  P.rob.kdip = 0.5;
end

%% Power coefficient Cp
function cp = heier_cp(lam)
lam  = max(lam, 1);
li   = 1./(1./lam - 0.035);
cp   = 0.5176*(116./li - 5).*exp(-21./li) + 0.0068*lam;
cp   = max(cp, 0);
end

%% Aerodynamic torque
function Tw = aero_torque(P, W, v)
lam = W*P.R/max(v, 0.1);
Tw  = 0.5*P.rho*pi*P.R^2*heier_cp(lam)*v^3/max(W, 0.05);
end

%% Wind profile
function v = wind_profile(P, t)
n  = numel(t);  dt = t(2) - t(1);
a  = exp(-dt/P.tau_t);  g = sqrt(1 - a^2)*P.sig_t;
s  = P.seed;  vt = zeros(1, n);  x = 0;  k = 1;
while k <= n
  s = mod(16807*s, 2147483647);  u1 = s/2147483647;
  s = mod(16807*s, 2147483647);  u2 = s/2147483647;
  r = sqrt(-2*log(u1));
  z = [r*cos(2*pi*u2), r*sin(2*pi*u2)];
  for j = 1:2
    if k > n, break; end
    x = a*x + g*z(j);  vt(k) = x;  k = k + 1;
  end
end
v = P.Vm + vt;
for k = 1:numel(P.Aw)
  v = v + P.Aw(k)*sin(2*pi*P.fw(k)*t);
end
end

%% Plant model: PMSG + DC link + L filter + grid
function dx = plant(x, u, Tw, vg, Q)
we  = Q.p*x(3);
Te  = 1.5*Q.p*Q.psi*x(2);
Pin = -1.5*(u(1)*x(1) + u(2)*x(2));
Pi  =  1.5*(u(3)*x(5) + u(4)*x(6));
dx  = [ (u(1) - Q.Rs*x(1) + we*Q.Ls*x(2))/Q.Ls;
        (u(2) - Q.Rs*x(2) - we*Q.Ls*x(1) - we*Q.psi)/Q.Ls;
        (Tw + Te - Q.B*x(3))/Q.J;
        (Pin - Pi)/(Q.C*x(4));
        (u(3) - Q.Rf*x(5) + Q.wg*Q.Lf*x(6) - vg(1))/Q.Lf;
        (u(4) - Q.Rf*x(6) - Q.wg*Q.Lf*x(5) - vg(2))/Q.Lf ];
end

%% Simulation
function r = wecs_simulate(P, ctrl, scen)
Ts = P.Ts;  N = round(P.Tend/Ts);  t = (0:N)*Ts;
v  = wind_profile(P, t);
Q = P;  kTw = 1;  dip = false;
if strcmp(scen, 'robust')
  Q.J = P.J*P.rob.kJ;  Q.Rs = P.Rs*P.rob.kRs;  Q.Ls = P.Ls*P.rob.kLs;
  Q.psi = P.psi*P.rob.kpsi;  Q.Rf = P.Rf*P.rob.kRf;  Q.Lf = P.Lf*P.rob.kLf;
  kTw = P.rob.kTw;  dip = true;
end
W0  = min(max(P.lopt*v(1)/P.R, P.Wmin), P.Wmax);
Tw0 = kTw*aero_torque(P, W0, v(1));
isq0 = -(Tw0 - Q.B*W0)/(1.5*Q.p*Q.psi);
Pg0 = (Tw0 - Q.B*W0)*W0 - 1.5*Q.Rs*isq0^2;
igd0 = Pg0/(1.5*P.Vgm);
x   = [0; isq0; W0; P.Vdcr; igd0; 0];
we0 = Q.p*W0;
us  = [-we0*Q.Ls*isq0; Q.Rs*isq0 + we0*Q.psi];
ui  = [Q.Rf*igd0 + P.Vgm; Q.wg*Q.Lf*igd0];
u   = [us; ui];
S = struct('vm', v(1), 'Wr', W0, 'dWr', 0, 'zW', 0, 'zy', 0, ...
           'zs', [0;0], 'zg', [0;0], 'isf', [0; isq0], 'igf', [igd0; 0], ...
           'W', zeros(1, size(P.nn.c, 2)), 'u', u, 'Dh', 0);
Te0c = 1.5*P.p*P.psi*isq0;
if strcmp(ctrl, 'PI')
  S.zW = -Te0c/(P.J*P.k12);
  S.zy = Pg0/P.k22;
else
  S.zW = (P.B*W0 - aero_torque(P, W0, v(1)) - Te0c)/(P.J*P.k12);
  if strcmp(ctrl, 'FPANN'), S.zW = 0; end
  S.zy = 0;
end
nl = floor(N/P.dec) + 1;  L = zeros(nl, 18);  kl = 0;
for k = 1:N+1
  tk = t(k);
  vg = [P.Vgm; 0];
  if dip && tk >= P.rob.tdip && tk < P.rob.tdip + P.rob.ddip
    vg = (1 - P.rob.kdip)*vg;
  end
  S.vm = S.vm + Ts/P.tau_a*(v(k) - S.vm);
  [unew, S, lg] = controller(P, ctrl, x, S, vg);
  if mod(k-1, P.dec) == 0
    kl = kl + 1;
    Tw = kTw*aero_torque(Q, x(3), v(k));
    lam = x(3)*P.R/v(k);
    Pg = 1.5*(vg(1)*x(5) + vg(2)*x(6));  Qg = 1.5*(vg(2)*x(5) - vg(1)*x(6));
    L(kl,:) = [tk, v(k), x', lg.Wr, lg.isqr, lg.igdr, Tw, lam, ...
               heier_cp(lam)*kTw, Pg, Qg, lg.Dh, lg.Twh];
  end
  if k > N, break; end
  h  = Ts;  vk = v(k);
  k1 = plant(x,  u, kTw*aero_torque(Q, x(3), vk),  vg, Q);
  x2 = x + h/2*k1;  k2 = plant(x2, u, kTw*aero_torque(Q, x2(3), vk), vg, Q);
  x3 = x + h/2*k2;  k3 = plant(x3, u, kTw*aero_torque(Q, x3(3), vk), vg, Q);
  x4 = x + h*k3;    k4 = plant(x4, u, kTw*aero_torque(Q, x4(3), vk), vg, Q);
  x  = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
  u  = unew;
end
L = L(1:kl, :);
r.ctrl = ctrl;  r.scen = scen;
names = {'t','v','isd','isq','W','Vdc','igd','igq','Wr','isqr','igdr', ...
         'Tw','lam','Cp','Pg','Qg','Dh','Twh'};
for j = 1:numel(names), r.(names{j}) = L(:, j); end
r = wecs_metrics(P, Q, r, dip);
end

%% Controllers: MPPT, flatness, PBC, RBF network, PI
function [u, S, lg] = controller(P, ctrl, x, S, vg)
Ts = P.Ts;  Jm = [0 1; -1 0];
isd = x(1); isq = x(2); W = x(3); Vdc = x(4); ig = x(5:6); is = x(1:2);
we  = P.p*W;
Wopt = min(max(P.lopt*S.vm/P.R, P.Wmin), P.Wmax);
ddWr = P.wr^2*(Wopt - S.Wr) - 2*P.wr*S.dWr;
S.Wr = S.Wr + Ts*S.dWr;  S.dWr = S.dWr + Ts*ddWr;
eW   = W - S.Wr;
phi = zeros(size(S.W));  Dh = 0;  Twh = NaN;
if strcmp(ctrl, 'PI')
  Ter = -P.J*(P.k11*eW + P.k12*S.zW);
else
  Twh = aero_torque(P, W, S.vm);
  if strcmp(ctrl, 'FPANN')
    zn  = [W/P.Wn; S.vm/P.vn];
    d2  = sum((P.nn.c - zn*ones(1, size(P.nn.c, 2))).^2, 1);
    phi = exp(-d2/(2*P.nn.b^2));
    Dh  = S.W*phi';
  end
  kI  = P.k12;  if strcmp(ctrl, 'FPANN'), kI = 0; end
  nu1 = S.dWr - P.k11*eW - kI*S.zW;
  Ter = P.J*nu1 + P.B*W - Twh - Dh;
end
Terl = min(max(Ter, -P.Temax), 0);
satW = (Terl ~= Ter);
if ~satW, S.zW = S.zW + Ts*eW; end
if strcmp(ctrl, 'FPANN') && ~satW
  S.W = S.W + Ts*(P.nn.Gam*phi*eW - P.nn.sig*S.W);
end
S.Dh = Dh;
isr  = [0; Terl/(1.5*P.p*P.psi)];
Pin  = -1.5*(S.u(1)*isd + S.u(2)*isq);
y2   = 0.5*P.C*Vdc^2 + 0.75*P.Lf*(ig'*ig);
y2r  = 0.5*P.C*P.Vdcr^2 + 0.75*P.Lf*(S.igf'*S.igf);
ey   = y2 - y2r;
if strcmp(ctrl, 'PI')
  Pgr = P.k21*ey + P.k22*S.zy;
else
  Pgr = Pin - 1.5*P.Rf*(ig'*ig) + P.k21*ey + P.k22*S.zy;
end
igdr  = 2*Pgr/(3*vg(1));
igdrl = min(max(igdr, -P.Igmax), P.Igmax);
if igdrl == igdr, S.zy = S.zy + Ts*ey; end
igr  = [igdrl; -2*P.Qr/(3*vg(1))];
disr = (isr - S.isf)/P.taud;  S.isf = S.isf + Ts*disr;
digr = (igr - S.igf)/P.taud;  S.igf = S.igf + Ts*digr;
es = is - isr;  eg = ig - igr;
if strcmp(ctrl, 'PI')
  vs = -(P.Ra*es + P.Ki*S.zs) - we*P.Ls*Jm*is + we*P.psi*[0; 1];
  vi = -(P.Rb*eg + P.Kig*S.zg) - P.wg*P.Lf*Jm*ig + vg;
else
  vs = P.Ls*disr + P.Rs*isr - we*P.Ls*Jm*isr + we*P.psi*[0; 1] ...
       - P.Ra*es - P.Ki*S.zs;
  vi = P.Lf*digr + P.Rf*igr - P.wg*P.Lf*Jm*igr + vg ...
       - P.Rb*eg - P.Kig*S.zg;
end
vmax = Vdc/sqrt(3);
if norm(vs) > vmax, vs = vs*vmax/norm(vs); else, S.zs = S.zs + Ts*es; end
if norm(vi) > vmax, vi = vi*vmax/norm(vi); else, S.zg = S.zg + Ts*eg; end
u = [vs; vi];  S.u = u;
lg.Wr = S.Wr;  lg.isqr = isr(2);  lg.igdr = igr(1);  lg.Dh = Dh;  lg.Twh = Twh;
end

%% Performance metrics
function r = wecs_metrics(P, Q, r, dip)
dt   = r.t(2) - r.t(1);
r.Te = 1.5*Q.p*Q.psi*r.isq;
r.Pw = r.Tw.*r.W;
kTw  = max(r.Cp)/max(heier_cp(r.lam));
Pmax = 0.5*P.rho*pi*P.R^2*P.Cpmax*kTw*r.v.^3;
win  = r.t >= 1;
idip = false(size(r.t));
if dip, idip = r.t >= P.rob.tdip - 0.05 & r.t < P.rob.tdip + P.rob.ddip + 0.5; end
M.IAE_W   = sum(abs(r.W(win) - r.Wr(win)))*dt;
M.RMS_isq = sqrt(mean((r.isq(win) - r.isqr(win)).^2));
M.RMS_igd = sqrt(mean((r.igd(win) - r.igdr(win)).^2));
M.dV_max  = max(abs(r.Vdc(win & ~idip) - P.Vdcr));
M.dV_dip  = NaN;  if dip, M.dV_dip = max(abs(r.Vdc(idip) - P.Vdcr)); end
M.ISE_V   = sum((r.Vdc(win) - P.Vdcr).^2)*dt;
M.E_kWh   = sum(r.Pg(win))*dt/3.6e6;
M.eta_mppt = sum(r.Pw(win))/sum(Pmax(win))*100;
M.Te_std  = std(diff(r.Te(win)))/dt/1e6;
r.M = M;
end

%% Results table and power-balance check
function wecs_table(RES, scens, ctrls)
f = {'IAE_W','RMS_isq','RMS_igd','dV_max','dV_dip','ISE_V','E_kWh','eta_mppt','Te_std'};
for s = 1:numel(scens)
  fprintf('\n%s\n%-10s', upper(scens{s}), 'metric');
  fprintf('%12s', ctrls{:});  fprintf('\n');
  for j = 1:numel(f)
    fprintf('%-10s', f{j});
    for c = 1:numel(ctrls), fprintf('%12.5g', RES.(scens{s}).(ctrls{c}).M.(f{j})); end
    fprintf('\n');
  end
end
P = wecs_params();  err = 0;
s = 1;
for k = 1:200
  s = mod(16807*s, 2147483647);  x = [3000*(s/2147483647-0.5); -2500*(s/2147483647);
       0.5 + 2*(s/2147483647); 1100 + 200*(s/2147483647); 2000*(s/2147483647); 300*(s/2147483647-0.5)];
  s = mod(16807*s, 2147483647);  u = 600*([s; s/3; s/5; s/7]/2147483647 - 0.3);
  Tw = 5e5*(s/2147483647);  vg = [P.Vgm; 30];
  dx = plant(x, u, Tw, vg, P);
  dE = P.J*x(3)*dx(3) + P.C*x(4)*dx(4) + 1.5*P.Ls*x(1:2)'*dx(1:2) + 1.5*P.Lf*x(5:6)'*dx(5:6);
  loss = P.B*x(3)^2 + 1.5*P.Rs*(x(1:2)'*x(1:2)) + 1.5*P.Rf*(x(5:6)'*x(5:6));
  Pg = 1.5*(vg'*x(5:6));
  err = max(err, abs(Tw*x(3) - dE - loss - Pg)/P.Pn);
end
fprintf('\nModel power-balance check: max |Pw - dE/dt - losses - Pg| / Pn = %.2e\n', err);
end

%% CSV export
function wecs_export(RES, scens, ctrls)
for s = 1:numel(scens)
  for c = 1:numel(ctrls)
    r = RES.(scens{s}).(ctrls{c});
    M = [r.t r.v r.W r.Wr r.Tw r.Te r.Cp r.lam r.isd r.isq r.isqr r.Vdc ...
         r.igd r.igq r.igdr r.Pg r.Qg r.Dh r.Twh];
    fid = fopen(sprintf('res_%s_%s.csv', scens{s}, ctrls{c}), 'w');
    fprintf(fid, 't,v,W,Wr,Tw,Te,Cp,lam,isd,isq,isqr,Vdc,igd,igq,igdr,Pg,Qg,Dh,Twh\n');
    fprintf(fid, [repmat('%.7g,', 1, size(M, 2)-1) '%.7g\n'], M');
    fclose(fid);
  end
end
end

%% Figures
function wecs_plots(RES, P)
r = RES.robust.FPANN;  n = RES.nominal;  b = RES.robust;
figure('Name', 'Wind and MPPT');
subplot(3,1,1); plot(r.t, r.v); ylabel('v (m/s)'); grid on;
subplot(3,1,2); plot(r.t, r.Wr, 'k--', r.t, r.W); ylabel('\Omega (rad/s)'); legend('\Omega^*', '\Omega'); grid on;
subplot(3,1,3); plot(r.t, r.Cp); ylabel('C_p'); xlabel('t (s)'); grid on;
figure('Name', 'Torques and currents');
subplot(3,1,1); plot(r.t, r.Tw/1e6, r.t, -r.Te/1e6); ylabel('MN.m'); legend('T_w', '-T_e'); grid on;
subplot(3,1,2); plot(r.t, r.isd, r.t, r.isq, r.t, r.isqr, 'k--'); ylabel('i_s (A)'); legend('i_{sd}', 'i_{sq}', 'i_{sq}^*'); grid on;
subplot(3,1,3); plot(r.t, r.igd, r.t, r.igq); ylabel('i_g (A)'); legend('i_{gd}', 'i_{gq}'); xlabel('t (s)'); grid on;
figure('Name', 'DC link and grid power');
subplot(2,1,1); plot(b.PI.t, b.PI.Vdc, b.FP.t, b.FP.Vdc, b.FPANN.t, b.FPANN.Vdc); ylabel('V_{dc} (V)'); legend('PI', 'flat+PBC', 'flat+PBC+ANN'); grid on;
subplot(2,1,2); plot(r.t, r.Pg/1e6, r.t, r.Qg/1e6); ylabel('MW, Mvar'); legend('P_g', 'Q_g'); xlabel('t (s)'); grid on;
figure('Name', 'Speed error and ANN');
subplot(2,1,1); plot(b.PI.t, b.PI.W - b.PI.Wr, b.FP.t, b.FP.W - b.FP.Wr, r.t, r.W - r.Wr); ylabel('\Omega-\Omega^* (rad/s)'); legend('PI', 'flat+PBC', 'flat+PBC+ANN'); grid on;
subplot(2,1,2); plot(r.t, r.Dh/1e6); ylabel('\Delta T_w estimate (MN.m)'); xlabel('t (s)'); grid on;
end
