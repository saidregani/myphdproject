%TEST_BLOCKS  Runs the Simulink block functions (blk_*.m) in a plain loop,
%exactly as wired in PMSG_FPBC_ANN.slx (controller at Ts, plant RK4), and
%compares with simulate.m. Works in MATLAB and Octave.
addpath('..');
scen = {'nominal', 'robust'};  ctr = {'FPBC', 'PI'};
P = pmsg_params();  T = 2;  N = round(T/P.Ts);
for c = 1:numel(ctr)
for s = 1:numel(scen)
  rob = strcmp(scen{s}, 'robust');
  clear blk_mppt blk_flat_speed blk_pbc_msc blk_flat_dc blk_pbc_gsc blk_ann blk_pi
  Pp = plant_pp(P, rob);
  [x, u0] = init_state(P, Pp, wind_speed(0));
  vs_prev = u0(1:2);  uAI = [0; 0];
  X = zeros(N/10, 6);
  for n = 0:N-1
    t = n*P.Ts;  vw = blk_wind(t);  vg = blk_grid(t, rob);
    is = x(1:2);  w = x(3);  Vdc = x(4);  ig = x(5:6);
    if strcmp(ctr{c}, 'FPBC')
      [wr, dwr] = blk_mppt(vw);
      [~, isqr, ew, satw] = blk_flat_speed(wr, dwr, w, vw, uAI(1), rob);
      [vs, es] = blk_pbc_msc(isqr, is, w, Vdc);
      [igr, ey, satv] = blk_flat_dc(Vdc, is, vs_prev, ig, vg, uAI(2));
      vi  = blk_pbc_gsc(igr, ig, vg, Vdc);
      uAI = blk_ann(ew, ey, es(2), satw, satv, 1);
      u = [vs; vi];
    else
      u = blk_pi(vw, is, w, Vdc, ig, vg, vs_prev, 0);
    end
    vs_prev = u(1:2);
    if mod(n, 10) == 0, X(n/10 + 1, :) = x'; end
    k1 = plant_blocks_rhs(x, u, vw, vg, rob);          k2 = plant_blocks_rhs(x + P.Ts/2*k1, u, vw, vg, rob);
    k3 = plant_blocks_rhs(x + P.Ts/2*k2, u, vw, vg, rob);  k4 = plant_blocks_rhs(x + P.Ts*k3, u, vw, vg, rob);
    x = x + P.Ts/6*(k1 + 2*k2 + 2*k3 + k4);
  end
  P2 = P;  P2.Tend = T;
  o = simulate(P2, ctr{c}, scen{s});
  d = max(abs(X - o.x(1:size(X,1), :)), [], 1);
  printf('%-5s %-8s max |blocks - simulate.m|: isd %.2e isq %.2e w %.2e Vdc %.2e igd %.2e igq %.2e\n', ...
         ctr{c}, scen{s}, d);
end
end
