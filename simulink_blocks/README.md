# PMSG_WECS_blocks — one Simulink model, standard blocks only

Run `PMSG_WECS_simulink.m` once in MATLAB: it creates `PMSG_WECS_blocks.slx`, a self-contained
Simulink model (parameters stored in the model InitFcn, no MATLAB Function block).
Then open `PMSG_WECS_blocks.slx` and press Run. Scopes: speed, isq, igd, powers, Vdc, ANN.
Scenario: type `scenario = 'step';` (or 'nominal', 'robust') and `useANN = 0/1;` before Run.
