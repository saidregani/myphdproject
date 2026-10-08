function dw = blk_shaft(Tw, Te, w, robust)
%BLK_SHAFT  [Simulink block] One-mass drive train: J dOmega/dt = Tw - Te - B Omega.
Pp = plant_pp(pmsg_params(), robust);
dw = (Tw - Te - Pp.B*w)/Pp.J;
end
