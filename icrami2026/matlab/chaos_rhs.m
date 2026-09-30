function dz = chaos_rhs(z, g, s, e, c)
%CHAOS_RHS Dimensionless DFIG model, Eq. (5).  z = [z1; z2; z3], e = [eps1; eps2; eps3].
%   c scales the unit damping terms (c = 1 nominal; used for mismatch tests).
if nargin < 5, c = 1; end
dz = [ -c*z(1) - z(3)*z(2) + g*z(3) + e(1);
       -c*z(2) + z(3)*z(1)          + e(2);
        s*z(1) - s*z(3)             + e(3) ];
end
