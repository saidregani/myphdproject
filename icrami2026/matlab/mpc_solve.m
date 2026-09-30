function v0 = mpc_solve(mpc, xi0, lb, ub)
%MPC_SOLVE Solve the box-constrained QP (14) and return the first move v(k|k).
if lb > ub, lb = (lb + ub) / 2; ub = lb; end
g = mpc.WG' * (mpc.WP * xi0(:));
V = box_qp(mpc.H, g, lb * ones(mpc.N, 1), ub * ones(mpc.N, 1));
v0 = V(1);
end
