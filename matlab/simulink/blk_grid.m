function vg = blk_grid(t, robust)
%BLK_GRID  [Simulink block] Grid voltage in the grid-voltage-oriented dq
%frame (ideal PLL). Robust scenario: dip of P.ksag pu at P.tsag.
P  = pmsg_params();
k  = 1;
if robust && t >= P.tsag && t < P.tsag + P.dsag, k = 1 - P.ksag; end
vg = [k*P.Vgm; 0];
end
