# PMSG_WECS_blocks — Simulink model with standard blocks only

No MATLAB Function block: Integrator, Gain, Sum, Product, 1-D Lookup Table, Discrete-Time Integrator,
Unit Delay, Saturation, Switch, Mux/Demux, Relational Operator, Random Number, Sine Wave, Step.

Files (keep them in the same folder):
- `pmsg_blocks_init.m`  — parameters, scenario and initial equilibrium (run by the model InitFcn)
- `build_pmsg_blocks.m` — creates `PMSG_WECS_blocks.slx`
- `plot_pmsg_blocks.m`  — figures (reference vs measured, wind, Cp, powers, ANN)

Use:
```matlab
cd <this folder>
build_pmsg_blocks                    % once: creates PMSG_WECS_blocks.slx
scenario = 'robust'; useANN = 1;     % 'step' | 'nominal' | 'robust'
out = sim('PMSG_WECS_blocks');
plot_pmsg_blocks
```

Structure: Wind -> Turbine -> PMSG and shaft -> DC link -> L filter and grid, and
Control (flatness + PBC + RBF-ANN) = MPPT reference, turbine model, RBF network, flatness speed loop,
flatness DC-link loop, PBC machine side, PBC grid side, one-sample delay (Unit Delay).
Solver: fixed-step ode4, step Ts = 1/(2 fsw); controller integrators: forward Euler at Ts.
