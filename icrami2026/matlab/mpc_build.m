function mpc = mpc_build(Ts, N, Q, r)
%MPC_BUILD Condensed MPC matrices for the QP of Eq. (14).
%   Cost: sum_{j=1..N} ||xi_j||_Q^2 + ||xi_N||_P^2 + r sum_{j=0..N-1} v_j^2
%   written as || WG*V + WP*xi0 ||^2, V = [v_0 ... v_{N-1}]'.
[A, B] = error_model(Ts);
[P, K, lmiMinEig] = lmi_terminal(Ts, Q, r);
Phi = zeros(2*N, 2);  Gam = zeros(2*N, N);
for i = 1:N
    Phi(2*i-1:2*i, :) = A^i;
    for j = 0:i-1
        Gam(2*i-1:2*i, j+1) = A^(i-1-j) * B;
    end
end
Wb = zeros(2*N);
for i = 1:N
    if i < N, w = chol(Q); else, w = chol(Q + P); end
    Wb(2*i-1:2*i, 2*i-1:2*i) = w;
end
mpc.N = N;  mpc.P = P;  mpc.K = K;  mpc.lmiMinEig = lmiMinEig;
mpc.WG = [Wb * Gam; sqrt(r) * eye(N)];
mpc.WP = [Wb * Phi; zeros(N, 2)];
mpc.H  = mpc.WG' * mpc.WG;
end
