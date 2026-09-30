function dx = dfig_rhs(x, a, v)
%DFIG_RHS Drift F(x) of the DFIG model (3), x = [i_dr; i_qr; omega_r], with T_L = -T_a.
a8 = -a.np * aero_torque(v, x(3), a) / a.J;
dx = [ a.a1*x(1) + (a.ws - x(3))*x(2) + a.a2*x(3) + a.c1;
      -(a.ws - x(3))*x(1) + a.a1*x(2) + a.c2;
       a.a6*x(1) - a.a7*x(3) - a8 ];
end
