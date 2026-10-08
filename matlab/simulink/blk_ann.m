function uAI = blk_ann(ew, ey, eisq, satw, satv, on)
%BLK_ANN  [Simulink block, Ts] Adaptive ANN compensator 6-10-2 (scheme of
%the Mathematics paper): u_AI = [dTe; dPg], learning signal r = B'e with
%dead-zone, sigma-modification and back-propagation (see ann_step.m).
%Its output is used at the next sample (Unit Delay in the model).
persistent nn ef
P = pmsg_params();  A = P.ann;
if isempty(nn), nn = ann_init(6, 10, 2, A); ef = [0; 0; 0]; end
nn.on = (on ~= 0);
Ibs = P.Tn/(1.5*P.p*P.psi);
e   = [ew/(A.e_w*P.wn); ey/A.e_y; eisq/(A.e_i*Ibs)];
de  = (e - ef)/A.tau_z;  ef = ef + P.Ts*de;
zn  = [e; de.*A.tz];
[y, nn] = ann_step(nn, zn, e(1:2), P.Ts, ~(satw || satv));
uAI = y.*[A.uT*P.Tn; A.uP*P.Pn];
end
