function [P, K, lmiMinEig] = lmi_terminal(Ts, Q, r)
%LMI_TERMINAL Terminal weight P and local gain K of Theorem 1 (Eq. 15-16).
%   Error model per channel: xi+ = A xi + B v, A = [1 0; Ts 1], B = [Ts; Ts^2/2].
%   The maximal-volume solution of LMI (15) is X = P^-1, where P solves the
%   discrete algebraic Riccati equation (DARE). P is computed here with the
%   structure-preserving doubling algorithm (no toolbox needed), and LMI (15)
%   is then checked numerically (lmiMinEig must be >= -1e-9).
[A, B] = error_model(Ts);
n = size(A, 1);
% --- DARE by structured doubling:  Ak, Gk, Hk -> Hk converges to P
Ak = A;  Gk = B * (1 / r) * B';  Hk = Q;
for it = 1:200
    W  = eye(n) + Gk * Hk;
    A1 = Ak / W * Ak;
    G1 = Gk + Ak / W * Gk * Ak';
    H1 = Hk + Ak' * Hk / W * Ak;
    done = norm(H1 - Hk, 'fro') <= 1e-13 * norm(H1, 'fro');
    Ak = A1;  Gk = G1;  Hk = H1;
    if done, break; end
end
P = (Hk + Hk') / 2;
K = -((r + B' * P * B) \ (B' * P * A));
% --- numerical check of LMI (15) with X = P^-1, Y = K X
X = inv(P);  Y = K * X;  Qh = chol(Q);           % Qh' * Qh = Q
M = [X,              (A*X + B*Y)',   X*Qh',        sqrt(r)*Y';
     A*X + B*Y,      X,              zeros(n),     zeros(n,1);
     Qh*X,           zeros(n),       eye(n),       zeros(n,1);
     sqrt(r)*Y,      zeros(1,n),     zeros(1,n),   1];
lmiMinEig = min(eig((M + M') / 2));
end
