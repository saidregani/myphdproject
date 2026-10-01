# ICRAMI 2026 — Paper 763183: point-by-point response (camera-ready)

**Paper:** "Hybrid Model Predictive and Nonlinear Feedback Control for Chaos Suppression and MPPT Enhancement in DFIG-Based Wind Energy Systems"

**Revised source:** `paper/main.tex` (compiled: `paper/main.pdf`, 6 pages).
**Simulation code:** `simulations/` (every number and figure can be regenerated with `simulations/run_all.sh`).
**Submitted version:** `original_submission/`.

Equation, figure and table numbers below refer to the revised paper.

---

## Reviewer 1

| Comment | Response |
|---|---|
| Table I: L_m = 0.0811 H exceeds L_s = 0.0022 H and L_r = 0.0033 H, which is physically impossible. | Table I now holds a physically consistent 2-MW-class parameter set: L_m = 2.5 mH and L_s = L_r = 2.587 mH, so L_s, L_r > L_m. The table also lists every parameter used in the model (n_p, V_s, psi_s, J, D, R, G, lambda_opt, C_p,max). |
| The leakage coefficient sigma is about -905; it must lie in (0, 1). | sigma = 0.0661 (Table I). Sec. III-B also shows that the chaos in the submitted version came from sigma < 0. With sigma > 0, the coupling coefficient gamma in Eq. (6) is always negative. |
| The controlled rotor speed converges to about -400 rad/s (Fig. 4), which is physically meaningless. | The stabilization target is now z* = (2.02, -2.00, 2.02), which corresponds to omega_r = 1.2 omega_s (positive, super-synchronous). It is sustained by u_2 alone (Sec. VI-A). |
| The natural chaotic equilibrium is not industrially relevant. | Agreed. Sec. III-B now says explicitly that, for the machine of Table I, chaos requires D/J of about 250 s^-1 and a q-axis rotor voltage of several kV. Chaos is therefore a severe fault or detuning scenario, not a nominal operating regime. It is studied on the dimensionless model (5), as in Ren & Liu [24] and Messadi & Mellit [25]. MPPT tracking is studied in physical units. |
| System (10): the derivatives dx1/dt, dx2/dt, dx3/dt are printed as "11 =", "12 =", "13 =". | These are rendering errors in the PDF that was reviewed; the LaTeX source uses `\dot{x}`. The model is now Eq. (3) and renders correctly in the new PDF. The final PDF should still be checked after PDF eXpress conversion. |
| Eq. (18): the constants +8517 and -0.6228 are not derived from Table I. | Removed. The constants are now defined symbolically as c_1 = a_3 u_ds + a_4 u_dr^0 and c_2 = a_5 + a_3 u_qs + a_4 u_qr^0 (Eq. 4). All coefficients a_1 to a_7 are given numerically for Table I. The paper also shows that a_3 u_ds exactly cancels a_2 omega_s (both 3.18e6 A/s). |
| Fig. 6: the power level (350 kW) implies R of about 20 m. | The turbine is now explicitly sized: R = 40 m, G = 80, 2-MW class, with stator power between 0.57 and 2.1 MW (Fig. 6). |
| trace(J) < 0 (dissipativity). | This is now stated analytically for the dimensionless model: div = -(2 + s) < 0. It is also checked numerically: the Lyapunov exponents sum to -10 = -(2 + s). |

## Reviewer 2

| Comment | Response |
|---|---|
| Duplicate definition of a6. | Fixed (Eq. 4): a_6 = 3 n_p^2 L_m psi_s / (2 J L_s) and a_7 = D/J. The coefficients are now numbered a_1 to a_8 without gaps. |
| Origin of 8517 and -0.6228. | See Reviewer 1: they are replaced by c_1 and c_2 (Eq. 4), with numerical values. |
| The title announces MPC, but Eq. (22) is pure feedback linearization. | An actual MPC is now formulated and implemented (Sec. V-B, Eqs. 13–14). It has a quadratic cost, a prediction horizon N, input constraints derived from the actuator limits, integral action and a receding-horizon QP solved at every sample. The title is therefore accurate and was kept. |
| Relationship between K1, K2 (LMI of Theorem 1) and the diagonal K of Eq. (22). | Theorem 1 was reformulated. The LMI (15) yields a single terminal weight P and gain K = [k_e, k_I], and these are exactly what the MPC uses (Remark i): without active constraints the MPC reduces to v = K xi. The pure feedback-linearization law of the submitted version is the special case k_I = 0 without constraints (Remark ii). The previous K1/K2 matrices are no longer used. |
| The conclusion mentions Lyapunov exponents and bifurcation analysis that are not in the paper. | Both are now included. Fig. 1(c)–(d) shows the bifurcation diagram and the largest Lyapunov exponent versus epsilon_2. Sec. III-B gives the full Lyapunov spectrum (1.416, 0.003, -11.419) and the Kaplan–Yorke dimension (2.12). |
| Add quantitative metrics and compare with at least one baseline. | Two baselines were added, both using the same LMI gains: FL only (the law of the submitted version) and PI. Metrics are reported in Table II (IAE, 2 % settling time, final error) and Table III (RMS errors of P_s, i_dr, omega_r). |
| Test parametric uncertainty and grid-code compliance, or remove these claims from the abstract. | Parametric uncertainty is tested with ±20 % mismatch (Table II) and with the mismatch sets M1/M2 on R_s, R_r, L_m and J (Table III). Grid-code compliance is not tested, so that claim was removed from the abstract. |

## Reviewer 3

Only the beginning of Reviewer 3's comment was available when preparing this revision ("…requires substantial technical corrections. The parameters in Table I violate the physical inductance condition L_m^2 …"). The inductance and sigma issues are addressed as for Reviewer 1. **Please check the full comment on Sciencesconf and make sure every remaining point is covered.**

## Additional change (requested by the supervisor)

The control now acts **only on the rotor voltages** $u_1=a_4\Delta u_{dr}$ and $u_2=a_4\Delta u_{qr}$, the only inputs of the rotor-side converter. The fictitious input $u_3$ on the speed equation was removed. The speed is now controlled by an outer loop, Eq. (12), that generates the torque-current reference $i^*_{dr}$; FL–MPC acts on the two current loops. All simulations, Tables II–III and Figs. 3–6 were recomputed with this structure. The PI baseline is now the classical cascaded PI vector control.

## Organizing committee: references

- All 40 references follow IEEE style, are numbered by first citation, and each one is cited in the text (and vice versa). The submitted version cited [33] nowhere; that is fixed.
- Corrected entries:
  - Heier: 3rd ed., 2014 (the submitted "4th ed., 2020" does not exist).
  - Simões & Farret: the 3rd ed. (2015) is titled *Modeling and Analysis with Induction Generators*.
  - IEA WEO 2024 and UNEP EGR 2024: invented subtitles removed.
  - IEA *Renewables 2024*: the horizon is 2030, not 2028.
  - The 117 GW / 1136 GW statistic is now attributed to GWEC *Global Wind Report 2025*, not to the IEA.
  - Morren & de Haan: the published title is "Ridethrough …".
  - Chhipa et al.: 8 authors, so the entry uses "et al.".
  - Takhi et al. (EPJ ST): full author list added.
  - Bouguettah et al.: full author list added.
  - The irrelevant STATCOM reference was removed.
  - A fixed-speed-turbine paper that had been cited for DFIG chaos is now cited only for oscillatory transients.
- New and recent references:
  - DFIG chaos: Yu et al. 2011 [21] and Van et al. 2023 [22].
  - Chaos in wind turbines: Meehan 2023 [23].
  - Feedback linearization + MPC for MPPT: Jiang et al. 2023 [35].
  - MPC stability: Mayne et al. 2000 [39] and Kothare et al. 1996 [40].
  - Lyapunov exponents: Wolf et al. 1985 [38].
- DOIs are given where they could be verified. **Still to check on IEEE Xplore or the publisher sites:** the DOIs of [7], [8], [16], [24], [25], [26], [29], [30], [38], [40] ([32] probably has no DOI).
- [36] (own paper) is listed as "submitted for publication". Update it if it has been accepted.

## Other items for the authors to verify before upload

1. **Scientific framing.** The main change is that chaos now appears as a fault or detuning scenario on a dimensionless model, not under "parameter deviations" of a real machine. This follows from the physics: with sigma > 0, the submitted chaotic regime does not exist. Please confirm that all co-authors agree with this framing.
2. **Author names.** "Kemih Karim" was changed to "Karim Kemih" (given name first, as IEEE requires). Please confirm this, the author order, the affiliations, and whether e-mail addresses should be added.
3. **Page limit.** The revised paper is 6 pages. Check this against the ICRAMI camera-ready instructions (the page could not be reached from this environment).
4. **Fig. 3** was redrawn to match the controller that is actually implemented. The previous figure showed a power-error/torque loop that the paper does not use.
5. Run the final PDF through IEEE PDF eXpress, and add the IEEE copyright notice line if the conference instructions require it.
