function [Pgsc, idc] = blk_inverter(vi, ig, Vdc)
%BLK_INVERTER  [Simulink block] PWM inverter (GSC), average model.
Pgsc = 1.5*(vi(1)*ig(1) + vi(2)*ig(2));
idc  = Pgsc/Vdc;
end
