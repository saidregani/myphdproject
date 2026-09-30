# Simulations for the revised ICRAMI 2026 paper

Python (numpy, scipy, matplotlib). `./run_all.sh` regenerates every number, table and figure of `../paper/main.tex` (about 1 h on one core).

| File | Purpose |
|---|---|
| `lyapunov_spectrum.py` | Lyapunov spectra of the dimensionless DFIG model (Eq. 5), QR/variational method |
| `bifurcation.py` | Bifurcation diagram and largest Lyapunov exponent versus epsilon_2 → `bif.json` |
| `ctrl.py` | LMI terminal ingredients (P, K) and the constrained MPC with integral action (bounded least squares) |
| `caseA.py` | Chaos suppression in the dimensionless model: FL–MPC vs FL only vs PI, 0/±20 % mismatch → `caseA.json` (Table II) |
| `caseB.py`, `runB.py` | MPPT tracking of the 2-MW-class DFIG under turbulent wind: nominal, M1 and M2 plants (Table III) |
| `fig1.py`, `fig3.py`, `fig4.py`, `fig256.py` | Figures written to `../paper/` |
| `results_metrics.txt` | Raw metrics printed by the runs used in the paper |

Notes:
- All three controllers use the same LMI-derived gain `K = [k_e, k_I]`, so the comparison isolates the effect of feedback linearization and of the constrained MPC.
- The terminal weight `P` is the maximal-volume solution of LMI (15); it is computed in closed form (DARE), and `ctrl.lmi_terminal` checks numerically that the LMI holds.
