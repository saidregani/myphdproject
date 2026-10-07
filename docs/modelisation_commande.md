# Chaîne éolienne PMSG 2 MW « back-to-back » : modélisation et commande Plate + Passive + ANN

> Note de travail de la réunion avec l'encadrant (sujet de conférence, **date limite de l'article complet : 10 octobre** ;
> conférence en Algérie les 14–15 décembre ; notification le 10 décembre).

## 1. Système étudié

```
 vent ─► Turbine ─► PMSG ─► Redresseur MLI (MSC) ─► Bus DC (C) ─► Onduleur MLI (GSC) ─► Filtre L ─► Réseau
        (R = 40 m)  (entraînement            Vdc = 1200 V                     (Rf, Lf)    690 V / 50 Hz
                     direct)
```

* Chaîne de conversion « **back-to-back** », PMSG à **attaque directe** (direct drive, sans multiplicateur).
* Éolienne standard de **2 MW** : R = 40 m, Ω_n = 2,23 rad/s, couple nominal T_n = P_n/Ω_n ≈ 0,9 MN·m
  (λ_opt = 8,1, C_p,max = 0,48 → vitesse du vent nominale ≈ 11 m/s).
* Tous les paramètres sont dans `matlab/pmsg_params.m`. Les données de la turbine sont celles données par l'encadrant ;
  les données de la machine, du filtre et du bus sont un dimensionnement en p.u. cohérent (S_b = 2 MVA, 690 V)
  **à recouper avec un article de référence avant soumission**.

| Grandeur | Valeur | Grandeur | Valeur |
|---|---|---|---|
| P_n | 2 MW | p (paires de pôles) | 30 |
| R | 40 m | R_s | 0,8 mΩ |
| Ω_n | 2,23 rad/s | L_s = L_d = L_q | 1,07 mH (0,3 p.u.) |
| T_n | 0,897 MN·m | ψ_f | 7,57 Wb |
| J | 2,8·10⁶ kg·m² (H ≈ 3,5 s) | C | 20 mF |
| λ_opt / C_p,max | 8,1 / 0,48 | V_dc* | 1200 V |
| Réseau | 690 V, 50 Hz | R_f / L_f | 2 mΩ / 0,2 mH |

## 2. Modélisation du système complet

### 2.1 Turbine
P_w = ½ ρ π R² C_p(λ, β) v³,  T_w = P_w / Ω,  λ = Ω R / v

C_p(λ,β) = 0,5176 (116/λ_i − 0,4β − 5) e^(−21/λ_i) + 0,0068 λ,  1/λ_i = 1/(λ+0,08β) − 0,035/(β³+1)

Arbre (modèle à une masse) :  J dΩ/dt = T_w − T_e − B Ω

### 2.2 PMSG (repère dq rotorique, convention générateur, pôles lisses)
L_s di_sd/dt = −R_s i_sd + ω_e L_s i_sq − v_sd
L_s di_sq/dt = −R_s i_sq − ω_e L_s i_sd + ω_e ψ_f − v_sq
T_e = (3/2) p ψ_f i_sq,  ω_e = p Ω

Forme vectorielle (Euler-Lagrange / Hamiltonienne à ports) avec 𝐉 = [0 1; −1 0] **antisymétrique** :

L_s di_s/dt = −R_s i_s + ω_e L_s 𝐉 i_s + ω_e ψ_f e_q − v_s

Le terme ω_e L_s 𝐉 i_s est un couplage « **sans travail** » (i_sᵀ 𝐉 i_s = 0) : c'est la structure exploitée par la commande passive.

### 2.3 Bus continu (modèle moyen, convertisseurs sans pertes)
C V_dc dV_dc/dt = P_msc − P_gsc,  P_msc = (3/2)(v_sd i_sd + v_sq i_sq),  P_gsc = (3/2)(v_id i_gd + v_iq i_gq)

Énergie stockée : W = ½ C V_dc²  ⇒  dW/dt = P_msc − P_gsc.

### 2.4 Filtre L et réseau (repère orienté tension réseau, PLL idéale : v_gd = V_m, v_gq = 0)
L_f di_g/dt = −R_f i_g + ω_g L_f 𝐉 i_g + v_i − v_g
P = (3/2) v_gd i_gd,  Q = −(3/2) v_gd i_gq

Limite de tension des convertisseurs (MLI vectorielle) : |v| ≤ V_dc/√3.

## 3. Stratégie de commande proposée : commande plate + commande passive + ANN

Idée de l'encadrant : la **commande par platitude (flatness)** et la **commande passive (PBC)** sont chacune
classiques, mais **leur association**, avec un **réseau de neurones (ANN) qui règle les paramètres (gains) en ligne**,
n'a pas été faite pour cette chaîne. Répartition :

* **Boucles externes → platitude** (vitesse/MPPT côté MSC, énergie du bus DC côté GSC).
* **Boucles internes de courant → passivité** (redresseur MLI et onduleur MLI + filtre L).
* **ANN (RBF)** → réglage en ligne des gains proportionnels / d'amortissement de chaque boucle.

### Schéma bloc

```
                    ┌──────────── ANN (RBF) : g_Ω, g_s, g_v, g_g ────────────┐
                    ▼                                                        ▼
 v ─►┌──────┐ Ω*,Ω̇* ┌────────────────────┐ T_e* ┌───────────┐ i_s* ┌────────────────────┐ v_s* ┌──────┐ ┌───────────────┐
     │ MPPT │──────►│ PLATITUDE vitesse  │─────►│ i_sq*=T_e*│─────►│ PASSIVE courant MSC│─────►│SVPWM │►│ Redresseur MLI│
     └──────┘       │ y1 = Ω             │      │ /(1.5pψ)  │      │ (PBC + amort. R_a) │      └──────┘ └───────────────┘
                    └────────────────────┘      │ i_sd* = 0 │      └────────────────────┘
                                                └───────────┘
 V_dc* ─►┌──────────────────────────┐ P_g* ┌─────────────┐ i_g* ┌────────────────────┐ v_i* ┌──────┐ ┌─────────────┐
         │ PLATITUDE bus DC         │─────►│ i_gd*=2P/3v │─────►│ PASSIVE courant GSC│─────►│SVPWM │►│ Onduleur MLI│► Filtre L ► Réseau
         │ y2 = ½CV_dc² + ¾L_f|i_g|²│      │ i_gq*=−2Q/3v│      │ (PBC + amort. R_b) │      └──────┘ └─────────────┘
         └──────────────────────────┘      └─────────────┘      └────────────────────┘
```

### 3.1 Boucle de vitesse — commande par platitude (côté MSC)
Sortie plate y₁ = Ω. Toutes les grandeurs s'expriment en fonction de y₁ et de ses dérivées :
T_e = T_w(Ω, v) − BΩ − J Ω̇. La loi par platitude est donc :

T_e* = T̂_w − BΩ − J·ν₁,  ν₁ = Ω̇* + k₁₁(t)(Ω* − Ω) + k₁₂ ∫(Ω* − Ω)

* Ω* = λ_opt v/R (MPPT), Ω̇* vient d'un filtre de référence d'ordre 2.
* T̂_w est calculé par le modèle aérodynamique C_p(λ) à partir du vent mesuré.
* Erreur : ė + k₁₁ e + k₁₂ ∫e = 0, avec k₁₁ = 2ζω_n et k₁₂ = ω_n² (ω_n = 2 rad/s, ζ = 0,9).
* Références de courant : i_sq* = T_e*/(1,5 p ψ_f) et i_sd* = 0.

### 3.2 Boucle bus DC — commande par platitude (côté GSC)
Sortie plate y₂ = énergie stockée = ½ C V_dc² + ¾ L_f (i_gd² + i_gq²).

dy₂/dt = P_msc − P_g − 1,5 R_f |i_g|²,  avec P_g = 1,5 v_gd i_gd

⇒ P_g* = P_msc − 1,5 R_f |i_g|² − ν₂,  ν₂ = k₂₁(t)(y₂* − y₂) + k₂₂ ∫(y₂* − y₂)

⇒ i_gd* = 2P_g*/(3 v_gd),  i_gq* = −2Q*/(3 v_gd)  (Q* = 0)

* y₂* = ½ C V_dc*² + ¾ L_f |i_g*|².
* Gains : k₂₁ = 2ζω_n, k₂₂ = ω_n², avec ω_n = 60 rad/s.

### 3.3 Boucles de courant — commande passive (PBC)
La PBC exploite la structure Euler-Lagrange : le couplage ω L 𝐉 i est « sans travail » (𝐉 antisymétrique).
Elle impose une dynamique désirée en préservant ce couplage et en injectant de l'amortissement (+ action intégrale).

* Redresseur MLI : v_s* = −L_s di_s*/dt − R_s i_s* + ω_e L_s 𝐉 i_s* + ω_e ψ_f e_q + R_a(t) e_s + K_i z_s
* Onduleur MLI : v_i* = L_f di_g*/dt + R_f i_g* − ω_g L_f 𝐉 i_g* + v_g − R_b(t) e_g − K_ig z_g
* Notations : e = i − i*, ż = e.

Dynamique de l'erreur (MSC) : L_s ė_s = −(R_s + R_a(t)) e_s + ω_e L_s 𝐉 e_s − K_i z_s

Fonction de stockage : H = ½ e_sᵀ L_s e_s + ½ K_i z_sᵀ z_s

⇒ **dH/dt = −(R_s + R_a(t)) ‖e_s‖² ≤ 0**  (car e_sᵀ𝐉e_s = 0). Même résultat pour l'onduleur.

### 3.4 ANN pour régler les paramètres en ligne
* Un réseau RBF par boucle.
* Entrées : erreur normalisée e_n et sa dérivée. 9 neurones gaussiens. Sortie sigmoïde → g ∈ [0,5 ; 3].
* Gains réglés : R_a = g_s R_a0, R_b = g_g R_b0, k₁₁ = g_Ω k₁₁⁰, k₂₁ = g_v k₂₁⁰.
* Apprentissage en ligne : critère E = ½ e_n². Comme ∂E/∂K ≈ −e² T_s/L < 0, la mise à jour est
  ẇ = η e_n² ∂g/∂w − σ w. Le gain augmente pendant les transitoires et revient au nominal en régime établi
  (σ-modification, poids bornés).
* **Argument de stabilité** : l'ANN ne modifie que les gains proportionnels / d'amortissement.
  * Pour les boucles de courant, dH/dt = −(R + R_a(t))‖e‖² ≤ 0 pour **tout** R_a(t) > 0.
  * Pour les boucles plates, V = ½e² + ½k₂ z² donne dV/dt = −k₁(t) e² ≤ 0.
  * Donc l'ANN améliore les transitoires sans casser la stabilité, puisque g est borné et positif.

### 3.5 Commande de référence (comparaison)
Commande vectorielle classique à PI (vitesse, courants MSC/GSC avec découplage, bus DC). Elle est réglée sur les mêmes
pôles nominaux (courants τ = 2 ms, vitesse ω_n = 2 rad/s, ζ = 0,9, bus DC ω_n = 60 rad/s).

## 4. Simulation (`matlab/`)
* `main.m` — **modèle moyen**, 10 s, 4 cas : PI / Plate+PBC+ANN × nominal / robustesse.
  * Scénario **nominal** : vent 8 → 10 → 11 → 9 m/s + turbulence.
  * Scénario **robustesse** : la machine réelle a R_s ×1,5, L_s ×1,2, ψ_f ×0,92, et le filtre R_f ×1,5, L_f ×1,25.
    Les contrôleurs ne connaissent que les valeurs nominales. Le modèle C_p utilisé par la platitude a 10 % d'erreur.
    Creux de tension réseau de 20 % à t = 8 s pendant 200 ms.
* `main_mli.m` — **modèle commuté** : redresseur MLI + onduleur MLI deux niveaux.
  * SVPWM, porteuse 5 kHz, échantillonnage régulier double mise à jour, pas d'intégration 1 µs.
  * Vent de 10 m/s puis 11 m/s à t = 0,45 s. THD de i_ga mesuré en régime établi (0,1–0,3 s).
* Fonctionne sous MATLAB et GNU Octave.
* Pour Simulink : `ctrl_fpbc_ann.m` et `ctrl_pi.m` → bloc *MATLAB Function* ; `plant_rhs.m` → modèle Simscape
  (PMSM + ponts IGBT + filtre L).

## 5. Plan pour la soumission (10 octobre)
1. Valider les paramètres 2 MW avec une référence (Wu et al., *Power Conversion and Control of Wind Energy Systems*, ou
   un article IEEE sur PMSG 2 MW) et les citer.
2. Figures : schéma bloc, vitesse/MPPT, C_p, V_dc, P/Q réseau, courants, gains ANN, formes d'onde MLI + THD.
3. Tableau d'indices (IAE vitesse, ISE V_dc, erreur de courant RMS, énergie produite).
4. Rédaction : Introduction → Modélisation → Commande plate + passive + ANN (+ preuve) → Résultats → Conclusion.

## 6. Résultats

### 6.1 Modèle moyen (`main.m`, 10 s)
Erreurs de courant RMS en A : [t < 1 s] / [t ≥ 1 s].

| Scénario | Commande | IAE Ω | ISE V_dc | max abs(ΔV_dc) [V] | RMS e_s [A] | RMS e_g [A] | C_p moyen | Énergie [kWh] |
|---|---|---|---|---|---|---|---|---|
| nominal | PI | 0,0905 | 421,6 | 13,3 | 0,23 / 0,06 | 1,20 / 0,12 | 0,4652 | 3,503 |
| nominal | Plate+PBC+ANN | 0,0000 | 0,04 | 0,2 | 0,04 / 0,00 | 0,14 / 0,00 | 0,4654 | 3,484 |
| robustesse | PI | 0,0976 | 1264,9 | 116,6 | 4,16 / 0,20 | 8,94 / 4,40 | 0,4652 | 3,479 |
| robustesse | Plate+PBC+ANN | 0,0179 | 3,7 | 15,2 | 10,51 / 0,22 | 13,15 / 9,99 | 0,4656 | 3,466 |

### 6.2 Modèle commuté MLI (`main_mli.m`, f_sw = 5 kHz)
| Commande | THD i_ga (régime établi) |
|---|---|
| PI | 0,31 % |
| Plate+PBC+ANN | 0,56 % |

Les deux sont largement sous la limite de 5 % (IEEE 519).

### 6.3 Lecture (à garder honnête dans l'article)
* **Bus DC** : c'est le gain principal. En nominal, l'écart max est de 0,2 V contre 13 V pour le PI.
  Pendant le creux de tension, il est de 15 V contre 117 V. Ce gain vient de la loi plate en énergie, qui inverse
  le modèle avec P_msc (anticipation). Un relecteur peut demander un PI avec la même anticipation.
* **Vitesse / MPPT** : le suivi est quasi parfait en nominal, mais seulement parce que T_w est calculé avec le modèle
  C_p exact et le vent mesuré. Avec 10 % d'erreur sur le modèle (scénario robustesse), l'IAE reste environ 5 fois
  plus petit que celui du PI. Le C_p moyen est à peine meilleur. L'énergie injectée est légèrement plus faible
  (≈ 0,5 %), parce que la loi plate stocke plus d'énergie cinétique dans le rotor pendant les rafales.
* **Courants** : en robustesse, la PBC utilise les paramètres nominaux dans ses anticipations.
  * Pendant la première seconde, ses erreurs sont plus grandes que celles du PI.
  * Pendant le creux réseau, l'erreur sur i_g est plus grande, parce que i_gd* saute instantanément.
  * En dehors de ces deux phases, elle est équivalente au PI.
* **ANN** : les gains montent pendant les transitoires (démarrage, rafales, creux à 8 s) puis reviennent à 1.
* **THD** : légèrement plus élevé qu'avec le PI. L'ondulation MLI de P_msc passe par l'anticipation de la boucle plate
  (un filtre sur P_msc est une amélioration possible).
