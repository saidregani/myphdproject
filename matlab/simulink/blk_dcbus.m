function dVdc = blk_dcbus(Pmsc, Pgsc, Vdc)
%BLK_DCBUS  [Simulink block] DC link: C Vdc dVdc/dt = P_msc - P_gsc.
P = pmsg_params();
dVdc = (Pmsc - Pgsc)/(P.C*Vdc);
end
