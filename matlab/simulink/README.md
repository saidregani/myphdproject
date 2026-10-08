# Simulink model — PMSG_FPBC_ANN

Complete 2 MW direct-drive PMSG chain (turbine → PMSG → PWM rectifier → DC bus → PWM inverter → L filter → grid)
with the proposed **flatness + PBC + adaptive ANN** control and the **PI** control used for comparison.
Diagram: `../../results/simulink_diagram.png`.

## Build and run (MATLAB + Simulink)
```matlab
cd matlab/simulink
build_pmsg_simulink          % creates PMSG_FPBC_ANN.slx
CTRL_SEL = 2; ANN_ON = 1; ROBUST = 0; PI_FF = 0;
sim('PMSG_FPBC_ANN');
plot_simulink
```

| Variable | Meaning |
|---|---|
| `CTRL_SEL` | 1 = PI, 2 = flatness + PBC (+ ANN) |
| `ANN_ON` | 0 = nominal control only, 1 = with adaptive ANN 6-10-2 |
| `PI_FF` | 1 = PI with P_msc feed-forward (fair baseline) |
| `ROBUST` | 1 = parameter mismatch + 10 % Cp error + 20 % grid dip at 8 s |

## Structure
* **Subsystem 1 – Plant**: `blk_turbine`, `blk_shaft`, `blk_pmsg`, `blk_rectifier`, `blk_dcbus`, `blk_inverter`,
  `blk_filter` + 4 integrators (is, Ω, Vdc, ig).
* **Subsystem 2 – Proposed control** (Ts = 100 µs): `blk_mppt`, `blk_flat_speed`, `blk_pbc_msc`, `blk_flat_dc`,
  `blk_pbc_gsc`, `blk_ann` (+ unit delays).
* **Subsystem 3 – PI control**: `blk_pi`.
* Each block is a *MATLAB Function* block calling the `blk_*.m` file of the same name.

## Verification
* `test_blocks.m` (runs in MATLAB or Octave) executes the same blocks with the same wiring and compares with
  `../simulate.m`: difference < 1e-10 for PI and FPBC, nominal and robust.
* The wiring of `build_pmsg_simulink.m` (76 blocks, all ports) was checked with a mock of the Simulink API.
  The script itself has **not yet been run in real MATLAB/Simulink**. If a block raises an error on your version,
  send me the message.
