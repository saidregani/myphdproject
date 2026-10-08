function dx = plant_blocks_rhs(x, u, vw, vg, rob)
%PLANT_BLOCKS_RHS  Plant assembled from the Simulink block functions, with
%the same wiring as PMSG_FPBC_ANN.slx (used by test_blocks.m).
[Tw, ~, ~] = blk_turbine(x(3), vw);
[dis, Te]  = blk_pmsg(u(1:2), x(1:2), x(3), rob);
dw   = blk_shaft(Tw, Te, x(3), rob);
Pmsc = blk_rectifier(u(1:2), x(1:2), x(4));
Pgsc = blk_inverter(u(3:4), x(5:6), x(4));
dV   = blk_dcbus(Pmsc, Pgsc, x(4));
dig  = blk_filter(u(3:4), x(5:6), vg, rob);
dx = [dis; dw; dV; dig];
end
