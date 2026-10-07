function out = simulate(P, ctrlType, scenario)
%SIMULATE  Closed-loop simulation of the complete PMSG wind chain.
%   ctrlType: 'PI' | 'APBC'
%   scenario: 'nominal' | 'robust' (plant parameters differ from the values
%             known by the controller + 20 % grid voltage dip at t = 8 s)
Pp = P;                                  % "true" plant parameters
if strcmp(scenario, 'robust')
  Pp.Rs  = 1.5*P.Rs;   Pp.Ls = 1.2*P.Ls;  Pp.psi = 0.92*P.psi;
  Pp.Rf  = 1.5*P.Rf;   Pp.Lf = 1.25*P.Lf;
end
vgfun = @(t) P.Vgm*[1 - 0.2*(strcmp(scenario,'robust') && t >= 8 && t < 8.2); 0];

% steady-state initial condition at t = 0 (MPPT operating point)
vw0 = wind_speed(0);
w0  = P.lopt*vw0/P.R;
Tw0 = 0.5*Pp.rho*pi*Pp.R^2*aero_cp(P.lopt, 0)*vw0^3/w0;
isq0 = (Tw0 - Pp.B*w0)/(1.5*Pp.p*Pp.psi);
we0 = Pp.p*w0;
us0 = [we0*Pp.Ls*isq0; we0*Pp.psi - Pp.Rs*isq0];
Pg0 = 1.5*us0(2)*isq0;
igd0 = Pg0/(1.5*P.Vgm);
ui0 = [P.Vgm + Pp.Rf*igd0; Pp.wg*Pp.Lf*igd0];
x  = [0; isq0; w0; P.Vdc_ref; igd0; 0];
u  = [us0; ui0];

S = ctrl_init(P, ctrlType, x, vw0, u);
if strcmp(ctrlType, 'PI'), ctrl = @ctrl_pi; else, ctrl = @ctrl_apbc_ann; end

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
