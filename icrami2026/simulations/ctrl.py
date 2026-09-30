"""Feedback linearization + constrained MPC with LMI-designed terminal ingredients.
Per channel, the linearised error model is augmented with the integral of the error:
    xi = [e, s],  xi+ = A xi + B v,  A = [[1,0],[Ts,1]],  B = [Ts, Ts^2/2]'.
"""
import numpy as np
from scipy.linalg import solve_discrete_are
from scipy.optimize import lsq_linear

def model(Ts):
    A = np.array([[1.0, 0.0], [Ts, 1.0]]); B = np.array([[Ts], [Ts**2/2]])
    return A, B

def lmi_terminal(Ts, Q, r):
    """Find X = P^-1 > 0 and Y = K X such that (Schur complement of the terminal condition)
       [[X, (AX+BY)', X Q^1/2, Y' r^1/2], [AX+BY, X, 0, 0], [Q^1/2 X, 0, I, 0], [r^1/2 Y, 0, 0, I]] >= 0,
       which is equivalent to (A+BK)'P(A+BK) - P + Q + K'rK <= 0."""
    A, B = model(Ts); n = 2
    Qh = np.linalg.cholesky(Q).T
    # The maximal-volume solution of this LMI is X = P^-1 with P the stabilising DARE solution;
    # it is computed in closed form and then checked against the LMI numerically.
    P = solve_discrete_are(A, B, Q, r*np.eye(1))
    K = -np.linalg.solve(r*np.eye(1) + B.T@P@B, B.T@P@A)
    Xv = np.linalg.inv(P); Yv = K@Xv
    Mv = np.block([[Xv, (A@Xv + B@Yv).T, Xv@Qh.T, np.sqrt(r)*Yv.T],
                   [A@Xv + B@Yv, Xv, np.zeros((n, n)), np.zeros((n, 1))],
                   [Qh@Xv, np.zeros((n, n)), np.eye(n), np.zeros((n, 1))],
                   [np.sqrt(r)*Yv, np.zeros((1, n)), np.zeros((1, n)), np.eye(1)]])
    lmi_min_eig = np.linalg.eigvalsh(0.5*(Mv + Mv.T)).min()
    Acl = A + B@K
    res = np.linalg.eigvalsh(Acl.T@P@Acl - P + Q + r*K.T@K).max()
    return P, K, res, np.abs(np.linalg.eigvals(Acl)).max(), lmi_min_eig

class MPC:
    def __init__(self, Ts, N, Q, r):
        self.Ts, self.N = Ts, N
        A, B = model(Ts)
        self.P, self.K, self.res, self.rho, self.lmi = lmi_terminal(Ts, Q, r)
        Phi = np.vstack([np.linalg.matrix_power(A, i) for i in range(1, N+1)])
        Gam = np.zeros((2*N, N))
        for i in range(1, N+1):
            for j in range(i):
                Gam[2*(i-1):2*i, j] = (np.linalg.matrix_power(A, i-1-j)@B).ravel()
        W = [np.linalg.cholesky(Q).T]*(N-1) + [np.linalg.cholesky(Q + self.P).T]
        Wb = np.zeros((2*N, 2*N))
        for i, w in enumerate(W): Wb[2*i:2*i+2, 2*i:2*i+2] = w
        self.WG = np.vstack([Wb@Gam, np.sqrt(r)*np.eye(N)])
        self.WP = Wb@Phi
    def solve(self, xi0, lb, ub):
        b = np.concatenate([-self.WP@xi0, np.zeros(self.N)])
        if lb > ub: lb = ub = 0.5*(lb+ub)
        sol = lsq_linear(self.WG, b, bounds=(np.full(self.N, lb), np.full(self.N, ub+1e-12)), method='bvls')
        return sol.x[0]
