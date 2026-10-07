function out = simulate_mli(P, ctrlType, Tend)
%SIMULATE_MLI  Switched model of the chain: two-level PWM rectifier (MSC)
%and two-level PWM inverter (GSC), SVPWM (min-max zero-sequence injection),
%triangular carrier at P.fsw, regular sampling with double update
%(controller period = 1/(2 fsw)). The PMSG, DC bus and L filter are
%integrated with step P.hsw. Wind: 10 m/s, step to 11 m/s at t = 0.45 s.
%THD of i_ga is measured in steady state over 0.1-0.3 s (10 periods).
if nargin < 3, Tend = 0.8; end   % must be > 0.3 s (THD window)
Pp  = P;
Tc  = 1/(2*P.fsw);                  % controller sample time
Pc  = P;  Pc.Ts = Tc;               % controller works at Tc
h   = P.hsw;  nsub = round(Tc/h);
vwf = @(t) 10 + 0.5*(1 + tanh((t - 0.45)/0.05));
[x, u] = init_state(P, Pp, vwf(0));
S   = ctrl_init(Pc, ctrlType, x, vwf(0), u);
if strncmp(ctrlType, 'PI', 2), ctrl = @ctrl_pi; else, ctrl = @ctrl_fpbc_ann; end

N    = round(Tend/h);
dec  = 5;  nlog = floor(N/dec);
out.t = zeros(nlog,1); out.x = zeros(nlog,6); out.iga = zeros(nlog,1);
out.isa = zeros(nlog,1); out.van = zeros(nlog,1);
th_e = 0;  k = 0;  ds = [0.5;0.5;0.5];  di = ds;
a3 = [0; -2*pi/3; 2*pi/3];
for n = 0:N-1
  t   = n*h;
  vw  = vwf(t);
  th_g = P.wg*t;
  if mod(n, nsub) == 0                     % sampling instant (carrier peak/valley)
    m = struct('isd',x(1),'isq',x(2),'w',x(3),'Vdc',x(4),'igd',x(5), ...
               'igq',x(6),'vg',[P.Vgm; 0],'vw',vw);
    [u, S] = ctrl(m, S, Pc);
    ds = duty(u(1:2), th_e + 1.5*P.p*x(3)*Tc, x(4), a3);   % +1.5 Tc delay comp.
    di = duty(u(3:4), th_g + 1.5*P.wg*Tc,     x(4), a3);
  end
  c  = abs(mod(t*P.fsw, 1)*2 - 1);         % triangular carrier 1 -> 0 -> 1
  Ss = double(ds > c);  Si = double(di > c);
  vs = park(x(4)*(Ss - mean(Ss)), th_e, a3);   % converter dq voltages
  vi = park(x(4)*(Si - mean(Si)), th_g, a3);
  dx = plant_rhs(x, [vs; vi], vw, [P.Vgm; 0], Pp);
  x  = x + h*dx;
  th_e = th_e + h*P.p*x(3);
  if mod(n, dec) == 0 && k < nlog
    k = k + 1;  out.t(k) = t;  out.x(k,:) = x';
    out.iga(k) = x(5)*cos(th_g) - x(6)*sin(th_g);
    out.isa(k) = x(1)*cos(th_e) - x(2)*sin(th_e);
    out.van(k) = vi(1)*cos(th_g) - vi(2)*sin(th_g);
  end
end
out.ctrl = ctrlType;  out.P = P;
% THD of the grid current (phase a), steady state 0.1-0.3 s (before the wind step)
dtl = out.t(2) - out.t(1);
nw  = round(10/P.fg/dtl);
k1  = find(out.t >= 0.3 - 1e-9, 1) - 1;
if isempty(k1) || k1 < nw, out.THD_ig = NaN; return; end
ia  = out.iga(k1-nw+1:k1);
Y   = abs(fft(ia))/nw*2;
f0  = 11;                                    % 50 Hz bin (10 periods)
out.THD_ig = sqrt(sum(Y([2:f0-1, f0+1:40*10+1]).^2))/Y(f0)*100;  % up to h40
end

function d = duty(vdq, th, Vdc, a3)
% inverse Park + min-max zero sequence (SVPWM) -> duty ratios
vabc = vdq(1)*cos(th + a3) - vdq(2)*sin(th + a3);
v0   = -(max(vabc) + min(vabc))/2;
d    = clamp(0.5 + (vabc + v0)/Vdc, 0, 1);
end

function vdq = park(vabc, th, a3)
vdq = (2/3)*[cos(th + a3)'; -sin(th + a3)']*vabc;
end
