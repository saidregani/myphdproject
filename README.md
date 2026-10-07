# myphdproject

PhD project: control of a **2 MW direct-drive PMSG wind turbine** connected to the grid through a
**back-to-back converter** (rectifier → DC bus → inverter → L filter → grid).

Proposed control: **adaptive passivity-based control (APBC)** with damping-injection gains **tuned online by
RBF neural networks (ANN)**, compared with classical PI vector control.

| Folder | Content |
|---|---|
| `docs/modelisation_commande.md` | full model, control laws, Lyapunov proof, simulation plan (French) |
| `matlab/` | MATLAB / GNU Octave simulation (average model) |
| `results/` | figures and `results.mat` produced by `matlab/main.m` |
| `paper/main.tex` | IEEE conference paper draft |

## Run
```matlab
cd matlab
main          % ~6 min in Octave, much faster in MATLAB
```
