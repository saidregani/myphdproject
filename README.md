# myphdproject

PhD project: control of a **2 MW direct-drive PMSG wind turbine** connected to the grid through a
**back-to-back converter** (rectifier → DC bus → inverter → L filter → grid).

Proposed control: **flatness-based control** (outer loops: speed/MPPT, DC-bus energy) + **passivity-based
control** (inner current loops of the PWM rectifier and PWM inverter) + **adaptive ANN compensation**
(6-10-2 MLP, u = u_N + u_AI, same scheme as the authors' Mathematics paper on DFIG). Compared with classical PI vector control.

| Folder | Content |
|---|---|
| `docs/modelisation_commande.md` | full model, control laws, Lyapunov proof, simulation plan (French) |
| `matlab/` | MATLAB / GNU Octave simulation (average + switched PWM models) |
| `results/` | figures and `results.mat` produced by `matlab/main.m` |
| `paper/main.tex` | IEEE conference paper draft |

## Run
```matlab
cd matlab
main          % average model, 4 cases (~6 min in Octave, much faster in MATLAB)
main_mli      % switched model, PWM rectifier + PWM inverter, THD (~8 min in Octave)
```
