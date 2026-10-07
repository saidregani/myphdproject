function out = simulate(P, ctrlType, scenario)
%SIMULATE  Closed-loop simulation of the complete PMSG wind chain.
%   ctrlType: 'PI' | 'PIFF' | 'FPBC0' | 'FPBC'
%   scenario: 'nominal' | 'robust' (plant parameters differ from the values
%             known by the controller, 10 % error on the Cp model,
%             + grid voltage dip (P.ksag at P.tsag, default 20 % at 8 s))
Pp = plant_true(P, scenario);
if strcmp(scenario, 'robust'), P.kTw = 0.9; end   % 10 % error on the Cp model
vgfun = @(t) P.Vgm*[1 - P.ksag*(strcmp(scenario,'robust') && t >= P.tsag && t < P.tsag + P.dsag); 0];

vw0 = wind_speed(0);
[x, u] = init_state(P, Pp, vw0);       % steady-state MPPT operating point

S = ctrl_init(P, ctrlType, x, vw0, u);
if strncmp(ctrlType, 'PI', 2), ctrl = @ctrl_pi; else, ctrl = @ctrl_fpbc_ann; end

N    = round(P.Tend/P.Ts);
dec  = 10;                                  % logging decimation
nlog = floor(N/dec);
out.t = zeros(nlog,1); out.x = zeros(nlog,6); out.u = zeros(nlog,4);
out.vw = zeros(nlog,1); out.lg = zeros(nlog,13); out.Tw = zeros(nlog,1);
out.Cp = zeros(nlog,1); out.vg = zeros(nlog,1);
k = 0;
for n = 0:N-1
  t  = n*P.Ts;
  vw = wind_speed(t);
  vg = vgfun(t);
  m  = struct('isd',x(1),'isq',x(2),'w',x(3),'Vdc',x(4),'igd',x(5), ...
              'igq',x(6),'vg',vg,'vw',vw);
  [u, S, lg] = ctrl(m, S, P);
  if mod(n, dec) == 0 && k < nlog
    k = k + 1;
    lam = x(3)*P.R/vw;  cp = aero_cp(lam, 0);
    out.t(k) = t; out.x(k,:) = x'; out.u(k,:) = u'; out.vw(k) = vw;
    out.lg(k,:) = lg; out.Cp(k) = cp; out.vg(k) = vg(1);
    out.Tw(k) = 0.5*P.rho*pi*P.R^2*cp*vw^3/x(3);
  end
  % RK4 with zero-order-hold input (wind / grid held over one step)
  h  = P.Ts;
  k1 = plant_rhs(x,          u, vw, vg, Pp);
  k2 = plant_rhs(x + h/2*k1, u, vw, vg, Pp);
  k3 = plant_rhs(x + h/2*k2, u, vw, vg, Pp);
  k4 = plant_rhs(x + h*k3,   u, vw, vg, Pp);
  x  = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
end
out.P = P; out.Pp = Pp; out.ctrl = ctrlType; out.scenario = scenario;
% derived signals
out.Te    = 1.5*Pp.p*Pp.psi*out.x(:,2);
out.Pgrid = 1.5*(out.vg.*out.x(:,5));
out.Qgrid = -1.5*(out.vg.*out.x(:,6));
end
