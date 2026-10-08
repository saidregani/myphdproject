function [Pmsc, idc] = blk_rectifier(vs, is, Vdc)
%BLK_RECTIFIER  [Simulink block] PWM rectifier (MSC), average model:
%lossless power transfer P_msc = 1.5 (vsd isd + vsq isq), i_dc = P/Vdc.
Pmsc = 1.5*(vs(1)*is(1) + vs(2)*is(2));
idc  = Pmsc/Vdc;
end
