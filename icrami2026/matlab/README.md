# MATLAB code for the revised ICRAMI 2026 paper

This is a MATLAB version of the Python code in `../simulations/`. It reproduces **Table II, Table III and Figs. 1, 2, 4, 5 and 6** of the paper.

- It runs on plain MATLAB and needs **no toolbox** (no Control, Optimization or Robust Control toolbox).
- It was tested in GNU Octave, where it gives the **same numbers** as the paper.

## How to run

In MATLAB, open this folder and run:

```matlab
run_all
```

You can also run each part on its own:

| Script | What it produces | Time |
|---|---|---|
| `caseA_chaos_suppression.m` | Table II + `fig4_matlab.png` | ~1 min |
| `caseB_mppt_tracking.m` | Table III + `fig2_matlab.png`, `fig5_matlab.png`, `fig6_matlab.png` | ~10 min |
| `chaos_analysis.m` | Lyapunov spectrum, Kaplan–Yorke dimension, `fig1_matlab.png` | 10–30 min (set `FAST = true` for a quick version) |

## Files

| File | Role | Equation in paper |
|---|---|---|
| `dfig_params.m` | Parameters of Table I | Table I |
| `dfig_coeffs.m` | Coefficients a1…a7, c1, c2 | (4) |
| `dfig_rhs.m`, `aero_torque.m` | DFIG + turbine model | (1)–(3) |
| `chaos_rhs.m` | Dimensionless model | (5) |
| `error_model.m` | Sampled error model with integral state | (13) |
| `lmi_terminal.m` | P and K from the LMI (computed through the DARE) and a numerical check that the LMI holds | (15)–(16) |
| `mpc_build.m`, `mpc_solve.m`, `box_qp.m` | Constrained MPC; the QP is solved by an active-set method | (14) |
| `run_chaos_case.m` | Chaos suppression: FL–MPC / FL only / PI | Sec. VI-A |
| `run_mppt_case.m` | MPPT tracking: nominal plant, M1, M2 | Sec. VI-B |
| `wind_profile.csv` | Exact wind realization used in the paper, so Table III is reproduced exactly | (7) |

## Notes

- `ctrl` selects the controller: `'mpc'` (proposed), `'fl'` (feedback linearization only) or `'pi'`.
- All three controllers use the same gain K obtained from the LMI, so the comparison is fair.
- To test other parameters, edit `dfig_params.m`. To use another wind profile, replace `wind_profile.csv` (two columns: time in s and speed in m/s, with a 1 ms step).
- If you have the Optimization Toolbox, you can replace `box_qp` with `quadprog`: the result is identical.
