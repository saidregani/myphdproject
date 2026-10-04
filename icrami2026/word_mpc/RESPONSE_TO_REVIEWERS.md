# Response to the reviewers – ICRAMI 2026, paper 763183

We thank the reviewers for their careful reading and constructive comments. All changes are in the revised manuscript. Equation, table and figure numbers refer to the revised version.

---

## Reviewer 1

**1. Unphysical equilibrium speed (Fig. 4): the rotor speed stabilizes at about −400 rad/s, which is physically absurd for a power-generating turbine.**

We agree. The negative speed resulted from the previous parameter set and from the choice of the stabilized point. In the revised paper:

- The model is simulated with a new, physically consistent parameter set (Table I).
- The controller drives the system to a chosen operating point instead of the natural equilibrium: ω_r* = 1.05 ω_s = 329.9 rad/s (positive, super-synchronous), i_qr* = ψ_s/L_m = 22.1 A (unity power factor), and i_dr* = 98.0 A.
- This operating point is held with realistic rotor voltages: u_dr = 29.3 V and u_qr = −8.4 V.

Fig. 4 now shows the speed converging to this positive target.

**2. The natural chaotic equilibrium point (Fig. 4) lacks industrial relevance.**

We agree. As explained in point 1, the controller now drives the machine to a chosen, industrially meaningful operating point (super-synchronous speed, Q_s = 0), not to the natural equilibrium. Section III gives the three natural equilibria (E₁, E₂, E₃) only to characterize the chaotic dynamics; all three are unstable.

**3. Equation formatting (System 10): the state derivatives are printed as "11 =", "12 =", "13 =".**

The LaTeX source uses `\dot{x}_1`, `\dot{x}_2`, `\dot{x}_3`. These characters were lost in the PDF conversion used for the review. The revised PDF displays them correctly.

**4. Arbitrary constants in Eq. (18): +8517 and −0.6228 have no algebraic derivation from Table I.**

The constants have been removed. Eq. (18) now has exactly the structure of Eq. (10):

- ẋ₁ = a₁x₁ + (ω_s − x₃)x₂ + a₂x₃ + a₃u_ds + a₄u₁
- ẋ₂ = −(ω_s − x₃)x₁ + a₁x₂ + a₅ + a₃u_qs + a₄u₂
- ẋ₃ = a₆x₁ − a₇x₃ − a₈

Every coefficient is computed from Table I and given numerically in the paper:

- The constant term of the first line is a₃u_ds = 1.0079 × 10⁵ A/s, with u_ds = −ω_sψ_s.
- The constant term of the second line is a₅ = 0.1946 A/s.
- The two control inputs are the rotor voltages, u₁ = u_dr and u₂ = u_qr.
- In open loop (u₁ = 2.539 V, u₂ = −2.936 V), Eq. (18) reduces exactly to the chaotic system (10).

---

## Reviewer 2

**1. Duplicate definition of coefficient a₆.**

Corrected:
- a₆ = 3n_p²L_mψ_s/(2JL_s)
- a₇ = D/J
- a₈ = n_pT_L/J

The coefficients are now numbered a₁ to a₈ without gaps (the text previously mentioned a₁ to a₁₀).

**2. Origin of the numerical constants 8517 and −0.6228 in Eq. (18).**

See Reviewer 1, point 4. The constants are now expressed symbolically (a₃u_ds and a₅) and numerically from Table I, so the derivation is fully reproducible.

**3. The title announces Model Predictive Control, but the implemented controller (Eq. 22) is pure feedback linearization.**

We added a full MPC formulation (Section V-C), so the title now matches the method:

- **Prediction model:** each current channel uses a discrete model of the error augmented with its integral, Eq. (21).
- **Cost function:** quadratic, with prediction horizon N = 10 and a terminal weight P, Eq. (22).
- **Constraints:** the converter voltage limit |u_dr|, |u_qr| ≤ 200 V.
- **Receding horizon:** a quadratic program is solved at every sample (T_s = 1 ms) and only the first move is applied.
- **Stability:** the terminal weight and the local gain come from an LMI (Theorem 1, Eq. 23), which guarantees nominal stability.

The MPC is combined with nonlinear feedback compensation, Eq. (20), and an outer speed loop, Eq. (19). The control acts only on the two rotor voltages; there is no input on the speed equation.

**4. Relationship between the full gain matrices K₁, K₂ obtained from the LMI and the diagonal gain matrix K used in Eq. (22).**

The previous formulation was replaced, so a single gain now serves both purposes:

- The LMI (23) gives one terminal weight P and one gain K = [k_e, k_I] = [−619.2, −1069.5], common to the two current channels.
- The maximal-volume solution of the LMI is the Riccati solution. Therefore, when no constraint is active, the MPC applies exactly v = Kξ.
- The pure feedback-linearization law is the special case k_I = 0 without constraints.

The matrices K₁, K₂ and the diagonal K are no longer used (Section V, Remarks).

**5. The conclusion mentions Lyapunov exponents and bifurcation analysis that are not shown in the paper.**

- **Lyapunov exponents:** now computed and given in Section III: (0.202, −0.010, −2.582). Their sum equals the divergence −2.391, and the Kaplan–Yorke dimension is 2.08.
- **Bifurcation analysis:** not shown in the paper, so the claim was removed from the conclusion.

**6. Add quantitative performance metrics (tracking error, settling time) and compare with at least one baseline controller.**

Two baselines were added, both using the same gains as the proposed controller:
- the pure feedback-linearization law ("FL only");
- the classical cascaded PI vector control.

The metrics are:
- **Table II (chaos suppression):** IAE of the speed error and settling time.
- **Table III (MPPT tracking):** RMS errors of the speed, of the stator power and of i_dr.

The results are as follows:
- **Chaos suppression:** all controllers suppress chaos without steady-state error. The PI has a lower IAE, while FL–MPC settles faster in two of the three cases.
- **MPPT tracking:** FL–MPC reduces the speed error 5–146 times and the power error 2.4–7.7 times compared with the PI. The speed reaches its reference in 0.13 s with FL–MPC, versus 0.75 s with the PI.

**7. Test parametric uncertainty and grid-code compliance if these claims are kept in the abstract.**

- **Parametric uncertainty:** now tested on two mismatched plants, for both chaos suppression and MPPT tracking:
  - M1: R_s, R_r +20 %, L_m −10 %, J +20 %;
  - M2: R_s, R_r −20 %, L_m +10 %, J −20 %.
- **Grid-code compliance:** not tested in this work, so the claim was removed from the abstract.
