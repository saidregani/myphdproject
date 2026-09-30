function x = box_qp(H, g, lb, ub)
%BOX_QP  min 0.5 x'Hx + g'x  s.t. lb <= x <= ub  (H symmetric positive definite).
%   Primal active-set method; exact after a finite number of iterations.
%   (quadprog gives the same result if the Optimization Toolbox is available.)
x = min(max(-H \ g, lb), ub);
for it = 1:10 * numel(g) + 20
    grad  = H * x + g;
    fixed = (x <= lb & grad >= 0) | (x >= ub & grad <= 0);
    free  = ~fixed;
    if ~any(free), break; end
    xf = -H(free, free) \ (g(free) + H(free, fixed) * x(fixed));
    p  = xf - x(free);
    if norm(p, inf) <= 1e-12 * max(1, norm(x, inf)), break; end
    xl = lb(free);  xu = ub(free);  xc = x(free);  alpha = 1;
    neg = p < 0;  pos = p > 0;
    if any(neg), alpha = min(alpha, min((xl(neg) - xc(neg)) ./ p(neg))); end
    if any(pos), alpha = min(alpha, min((xu(pos) - xc(pos)) ./ p(pos))); end
    x(free) = min(max(xc + max(alpha, 0) * p, xl), xu);
end
end
