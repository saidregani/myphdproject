function [dig, Pg, Qg] = blk_filter(vi, ig, vg, robust)
%BLK_FILTER  [Simulink block] L filter + grid (grid-voltage-oriented dq):
%  Lf dig/dt = -Rf ig + wg Lf J ig + vi - vg
Pp = plant_pp(pmsg_params(), robust);
dig = [(-Pp.Rf*ig(1) + Pp.wg*Pp.Lf*ig(2) + vi(1) - vg(1))/Pp.Lf;
       (-Pp.Rf*ig(2) - Pp.wg*Pp.Lf*ig(1) + vi(2) - vg(2))/Pp.Lf];
Pg = 1.5*(vg(1)*ig(1) + vg(2)*ig(2));
Qg = 1.5*(vg(2)*ig(1) - vg(1)*ig(2));
end
