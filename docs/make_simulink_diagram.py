import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import sys

C = dict(plant="#dbe9f6", plant_e="#2f6fa8", flat="#dff0d8", flat_e="#3c7d3c",
         pbc="#fde7cf", pbc_e="#b8650f", ann="#ece2f5", ann_e="#6a3d9a",
         pi="#eeeeee", pi_e="#666666", io="#ffffff", io_e="#333333")

fig, ax = plt.subplots(figsize=(22, 14.5))
ax.set_xlim(0, 22); ax.set_ylim(0, 14.5); ax.axis("off")

def box(x, y, w, h, title, sub="", kind="plant", fs=10.5):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.12",
                 fc=C[kind], ec=C[kind + "_e"], lw=1.6))
    ax.text(x + w/2, y + h*0.66 if sub else y + h/2, title, ha="center", va="center",
            fontsize=fs, fontweight="bold", color="#111")
    if sub:
        ax.text(x + w/2, y + h*0.30, sub, ha="center", va="center", fontsize=8.6, color="#222")
    return (x, y, w, h)

def frame(x, y, w, h, title, col):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.2",
                 fc="none", ec=col, lw=2.2, ls="--"))
    ax.text(x + 0.15, y + h - 0.12, title, ha="left", va="top", fontsize=12.5, fontweight="bold", color=col)

def arr(p, q, label="", col="#222", ls="-", lw=1.4, lpos=0.5, off=(0, 0.13), cs="arc3,rad=0"):
    ax.add_patch(FancyArrowPatch(p, q, arrowstyle="-|>", mutation_scale=13, color=col, lw=lw,
                 ls=ls, connectionstyle=cs, shrinkA=0, shrinkB=0))
    if label:
        ax.text(p[0] + (q[0]-p[0])*lpos + off[0], p[1] + (q[1]-p[1])*lpos + off[1], label,
                ha="center", va="bottom", fontsize=9, color=col)

def path(pts, label="", col="#222", lw=1.4, li=0, off=(0, 0.08), ls="-", ha="center"):
    for a, b in zip(pts[:-2], pts[1:-1]):
        ax.plot([a[0], b[0]], [a[1], b[1]], color=col, lw=lw, ls=ls, solid_capstyle="round")
    ax.add_patch(FancyArrowPatch(pts[-2], pts[-1], arrowstyle="-|>", mutation_scale=13, color=col, lw=lw, ls=ls, shrinkA=0, shrinkB=0))
    if label:
        a, b = pts[li], pts[li+1]
        ax.text((a[0]+b[0])/2 + off[0], (a[1]+b[1])/2 + off[1], label, ha=ha, va="bottom", fontsize=9.5, color=col, fontweight="bold")

def R(b): return (b[0] + b[2], b[1] + b[3]/2)
def Lf(b): return (b[0], b[1] + b[3]/2)
def T(b, f=0.5): return (b[0] + b[2]*f, b[1] + b[3])
def Bo(b, f=0.5): return (b[0] + b[2]*f, b[1])

ax.text(11, 14.15, "PMSG_FPBC_ANN.slx  —  2 MW direct-drive PMSG wind chain with Flatness + PBC + adaptive ANN control",
        ha="center", fontsize=15, fontweight="bold")
ax.text(11, 13.75, "Turbine → PMSG → PWM rectifier → DC bus → PWM inverter → L filter → 690 V grid  (average model, ode4, Ts = 100 µs)",
        ha="center", fontsize=11, color="#333")

# ---------------- PLANT ----------------
frame(0.3, 9.0, 21.4, 3.9, "Subsystem 1 — Plant: Turbine-PMSG-Back-to-back-L filter-Grid", C["plant_e"])
wind = box(0.6, 10.9, 1.6, 1.0, "Wind profile", "v(t)", "io")
tur  = box(2.8, 10.7, 2.0, 1.4, "Turbine", "Cp(λ,β), R = 40 m\nTw = ½ρπR²Cp v³/Ω")
sh   = box(5.4, 10.7, 1.9, 1.4, "Drive train", "J dΩ/dt = Tw−Te−BΩ\n∫ → Ω")
pm   = box(7.9, 10.7, 2.2, 1.4, "PMSG (dq)", "p=26, Rs=0.78 mΩ\nLs=1.57 mH, ψ=9.18 Wb")
rec  = box(10.7, 10.7, 1.9, 1.4, "PWM rectifier", "MSC (average)\nP_msc = 1.5 vsᵀis")
dc   = box(13.2, 10.7, 1.8, 1.4, "DC bus", "C = 20 mF\nC Vdc dVdc/dt = ΔP")
inv  = box(15.6, 10.7, 1.9, 1.4, "PWM inverter", "GSC (average)\nP_gsc = 1.5 viᵀig")
fil  = box(18.1, 10.7, 1.6, 1.4, "L filter", "Lf = 0.15 mH\nRf = 2 mΩ")
grd  = box(20.2, 10.9, 1.3, 1.0, "Grid", "690 V, 50 Hz", "io")
arr(R(wind), Lf(tur), "v")
arr(R(tur), Lf(sh), "Tw")
arr(R(sh), Lf(pm), "Ω")
arr(R(pm), Lf(rec), "is, Te")
arr(R(rec), Lf(dc), "P_msc")
arr(Lf(inv), R(dc), "P_gsc")
arr(R(inv), Lf(fil), "vi")
arr(R(fil), Lf(grd), "ig")
arr(Bo(pm, 0.2), (5.4 + 1.9*0.8, 10.7), "Te", cs="arc3,rad=-0.4", off=(0, -0.45))
ax.text(0.6, 9.2, "Outputs: is, Ω, Vdc, ig, Tw, Te, Cp, P, Q   |   ROBUST = 1: Rs×1.5, Ls×1.2, ψ×0.92, Rf×1.5, Lf×1.25", ha="left", fontsize=9.2, color=C["plant_e"])

# measurement bus
meas = box(19.3, 7.6, 2.2, 0.9, "Measurements + ZOH (Ts)", "m = [is Ω Vdc ig vg v]", "io", fs=9.5)
arr((20.5, 9.0), T(meas), "", col="#555", ls="--")

# ---------------- PROPOSED CONTROL ----------------
frame(0.3, 3.55, 18.6, 5.3, "Subsystem 2 — Control: Flatness + PBC + adaptive ANN (proposed)", C["flat_e"])
mp  = box(0.6, 6.7, 1.8, 1.1, "MPPT", "Ω* = λopt v/R\n+ 2nd-order filter", "flat", fs=10)
fs_ = box(3.0, 6.5, 3.1, 1.5, "Flatness: speed", "y1 = Ω\nTe* = T̂w − BΩ − J(Ω̇* + k11e + k12∫e) + ΔTe", "flat", fs=10.5)
pbm = box(6.8, 6.5, 3.4, 1.5, "PBC: rectifier currents", "vs* = −Ls di*/dt − Rs i* + ωeLsJi*\n+ ωeψ eq + Ra e + Ki∫e", "pbc", fs=10.5)
fdc = box(3.0, 4.1, 3.1, 1.5, "Flatness: DC bus", "y2 = ½CVdc² + ¾Lf|ig|²\nPg* = P_msc − 1.5Rf|ig|² − ν2 + ΔPg", "flat", fs=10.5)
pbg = box(6.8, 4.1, 3.4, 1.5, "PBC: inverter currents", "vi* = Lf di*/dt + Rf i* − ωgLfJi*\n+ vg − Rb e − Ki∫e", "pbc", fs=10.5)
ann = box(11.3, 4.6, 3.5, 2.6, "Adaptive ANN 6-10-2", "u = u_N + u_AI\nz = [eΩ ey eisq ėΩ ėy ėisq]\nh = tanh(W1 z + b1), y = W2 h + b2\nr = Bᵀe (dead-zone δ), σ-modif.\nẆ2 = −Γ r hᵀ − σW2 (+ backprop W1)", "ann", fs=11)
z1  = box(15.5, 5.55, 0.8, 0.6, "z⁻¹", "", "io", fs=10)
arr(R(mp), Lf(fs_), "Ω*, Ω̇*")
arr(R(fs_), Lf(pbm), "isq*")
arr(R(fdc), Lf(pbg), "ig*")
P_ = C["pbc_e"]; A_ = C["ann_e"]
# control voltages to the converters
path([(9.9, 8.0), (9.9, 9.6), (11.65, 9.6), (11.65, 10.7)], "vs*", P_, 2.0, li=1)
path([(10.2, 4.35), (17.6, 4.35), (17.6, 9.75), (16.55, 9.75), (16.55, 10.7)], "vi*", P_, 2.0, li=0, off=(2.5, 0.05))
# errors to the ANN
path([(4.55, 8.0), (4.55, 8.28), (13.05, 8.28), (13.05, 7.2)], "eΩ", A_, li=1, off=(1.5, 0.03))
path([(10.2, 7.0), (11.3, 7.0)], "eisq", A_, li=0)
path([(4.55, 4.1), (4.55, 3.85), (13.05, 3.85), (13.05, 4.6)], "ey", A_, li=1, off=(2.6, 0.02))
# ANN outputs through the unit delay
arr(R(ann), Lf(z1), "", col=A_)
path([(16.3, 5.85), (16.8, 5.85), (16.8, 8.13), (3.6, 8.13), (3.6, 8.0)], "ΔTe", A_, li=2, off=(-3.5, -0.32))
path([(16.8, 5.85), (16.8, 3.68), (3.6, 3.68), (3.6, 4.1)], "ΔPg", A_, li=1, off=(-5.5, 0.0))
ax.text(11, 0.02, "Same nominal gains with/without ANN (ANN_ON = 0/1)   |   PBC: H = ½eᵀLe + ½Ki zᵀz → dH/dt = −(R+Ra)‖e‖² ≤ 0   |   with ANN: uniformly ultimately bounded (UUB)",
        ha="center", fontsize=10, color=C["flat_e"])
arr((19.3, 8.05), (18.9, 8.05), "m", col="#555", ls="--", lpos=0.5, off=(0, 0.05))

# ---------------- PI + SELECTOR ----------------
frame(0.3, 0.3, 9.6, 3.0, "Subsystem 3 — Control: PI vector control (comparison)", C["pi_e"])
pi_ = box(0.7, 0.75, 4.2, 1.9, "PI controllers", "PI speed + PI currents (MSC, decoupling)\nPI DC bus (+ P_msc feed-forward if PI_FF = 1)\nPI currents (GSC, decoupling)\nsame poles as the proposed control", "pi", fs=11)
sel = box(10.8, 0.9, 2.4, 1.6, "Multiport switch", "CTRL_SEL\n1 = PI, 2 = proposed", "io", fs=10.5)
ax.text(7.4, 1.7, "vs*, vi*\n(PI)", ha="center", fontsize=9.5)
arr(R(pi_), Lf(sel), "", col=C["pi_e"])
arr((13.2, 1.7), (14.6, 1.7), "vs*, vi*", col="#222")
ax.text(14.7, 1.7, "→ to Subsystem 1\n(rectifier & inverter inputs)", ha="left", va="center", fontsize=9.5)
arr((12.0, 3.55), (12.0, 2.5), "vs*, vi* (proposed)", col=C["flat_e"], lpos=0.5, off=(1.25, -0.1))

# switches & logging
box(18.0, 0.5, 3.6, 2.6, "Settings / logging", "ROBUST 0/1   ANN_ON 0/1\nPI_FF 0/1   CTRL_SEL 1/2\nTo Workspace: x_log, wr_log,\npq_log, cp_log, uai_log, vw_log\nScopes: Ω, Vdc, P/Q, torques, ANN", "io", fs=10.5)

# legend
for i, (k, t) in enumerate([("plant", "Plant (physics)"), ("flat", "Flatness control"), ("pbc", "Passivity-based control"),
                            ("ann", "Adaptive ANN"), ("pi", "PI (comparison)")]):
    ax.add_patch(FancyBboxPatch((0.6 + i*3.3, 13.05), 0.35, 0.3, boxstyle="round,pad=0.01", fc=C[k], ec=C[k + "_e"]))
    ax.text(1.05 + i*3.3, 13.2, t, va="center", fontsize=10)

out = sys.argv[1]
fig.savefig(out + ".png", dpi=130, bbox_inches="tight")
fig.savefig(out + ".svg", bbox_inches="tight")
