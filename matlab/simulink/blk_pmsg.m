function [dis, Te] = blk_pmsg(vs, is, w, robust)
%BLK_PMSG  [Simulink block] PMSG in the rotor dq frame (generator
%convention, Ld = Lq = Ls):
%  Ls dis/dt = -Rs is + we Ls J is + we psi e_q - vs,  Te = 1.5 p psi isq
Pp = plant_pp(pmsg_params(), robust);
we = Pp.p*w;
dis = [(-Pp.Rs*is(1) + we*Pp.Ls*is(2) - vs(1))/Pp.Ls;
       (-Pp.Rs*is(2) - we*Pp.Ls*is(1) + we*Pp.psi - vs(2))/Pp.Ls];
Te = 1.5*Pp.p*Pp.psi*is(2);
end
