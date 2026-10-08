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
* Tous les paramètres sont dans `matlab/pmsg_params.m`.
  * **Turbine** : données de l'encadrant + modèle C_p standard (Heier).
  * **PMSG (cas pôles lisses), bus DC, réseau, filtre, fréquence MLI** : tirés de la référence [1].
  * **J, B, R_f** : non donnés dans [1], ce sont nos hypothèses.

| Grandeur | Valeur | Source |
|---|---|---|
| P_n | 2 MW | encadrant ; [1] Tab. I |
| R | 40 m | encadrant |
| Ω_n | 2,23 rad/s | encadrant |
| T_n | 0,897 MN·m | encadrant (P_n/Ω_n) |
| λ_opt / C_p,max | 8,1 / 0,48 | [1] éq. (3), Fig. 1 |
| p (paires de pôles) | 26 | [1] Tab. I (non-salient) |
| R_s | 0,78 mΩ | [1] Tab. I |
| L_s = L_d = L_q | 1,57 mH | [1] Tab. I |
| ψ_f | 9,18 Wb | [1] Tab. I |
| C | 20 mF | [1] Tab. I |
| V_dc* | 1200 V | [1] Fig. 4a, Fig. 12 |
| Réseau | 690 V, 50 Hz | [1] Tab. I |
| L_f | 0,15 mH | [1] Fig. 4a |
| f_MLI | 2160 Hz | [1] Sec. IV |
| J | 2,8·10⁶ kg·m² (H ≈ 3,5 s) | hypothèse |
| B | 1000 N·m·s/rad | hypothèse |
| R_f | 2 mΩ | hypothèse |

Vérification de cohérence : avec ψ_f = 9,18 Wb à 9,75 Hz (fréquence nominale de [1]), on a
E = 9,18 × 2π × 9,75 = 562 V. C'est bien la tension crête de phase du réseau 690 V (563 V).

Remarque : dans [1], le générateur fait 2,2 MVA et tourne à 2,355 rad/s nominal. Ici il travaille avec la turbine de
l'encadrant (2 MW, 2,23 rad/s), donc légèrement en dessous de ses valeurs nominales.

[1] S. M. M. Hasan, A. H. M. Shatil, « Design and Comparison of Grid Connected Permanent Magnet Synchronous Generator
Non-salient Pole and Salient Pole Rotor Wind Turbine », *AIUB Journal of Science and Engineering (AJSE)*, vol. 20,
n° 2, pp. 40–46, 2021.

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
Deux réseaux RBF, avec deux rôles :

**ANN 1 — réglage des gains.** Un RBF par boucle règle les gains proportionnels / d'amortissement.
* Gains réglés : R_a = g_s R_a0, R_b = g_g R_b0, k₁₁ = g_Ω k₁₁⁰, k₂₁ = g_v k₂₁⁰.
* Entrées : erreur normalisée e_n et sa dérivée. 9 neurones. Sortie sigmoïde → g ∈ [0,5 ; 3].
* Apprentissage : ẇ = η e_n² ∂g/∂w − σ w, car ∂E/∂K ≈ −e² T_s/L < 0. Le gain monte pendant les transitoires
  puis revient au nominal.
* Stabilité : dH/dt = −(R + R_a(t))‖e‖² ≤ 0 pour tout R_a(t) > 0. Même chose pour les boucles plates
  (dV/dt = −k₁(t)e²).

**ANN 2 — correction du modèle aérodynamique.** La platitude est basée sur le modèle, et C_p(λ) n'est jamais connu
exactement.
* Un RBF (25 neurones sur (λ/λ_opt, v/11)) apprend l'erreur : T_w = T̂_w,modèle + T_n Ŵᵀφ(λ, v) + ε.
* Loi d'apprentissage de Lyapunov : dŴ/dt = −γ φ e_Ω − σŴ, avec e_Ω = Ω* − Ω.
* Avec V = ½J e² + ½J k₁₂ z² + W̃ᵀW̃/(2γ), le terme croisé s'annule : dV/dt = −J k₁₁ e² (à ε et σ près).

### 3.5 Commandes de comparaison
Toutes sont réglées sur les mêmes pôles nominaux (courants τ = 2 ms, vitesse ω_n = 2 rad/s, ζ = 0,9, bus DC ω_n = 60 rad/s).

| Nom | Description | Rôle dans l'article |
|---|---|---|
| PI | commande vectorielle classique (PI vitesse, PI bus DC, PI courants + découplage) | référence |
| PI+FF | PI + anticipation de P_msc dans la boucle bus DC | référence **équitable** (même information que la platitude) |
| Plate+PBC | commande proposée **sans ANN** (gains fixes) | montre l'apport de l'ANN |
| Plate+PBC+ANN | commande proposée complète | — |

## 4. Simulation (`matlab/`)
* `main.m` — **modèle moyen**, 10 s, 4 commandes (PI, PI+FF, Plate+PBC, Plate+PBC+ANN) × 2 scénarios (nominal / robustesse).
  * Scénario **nominal** : vent 8 → 10 → 11 → 9 m/s + turbulence.
  * Scénario **robustesse** : la machine réelle a R_s ×1,5, L_s ×1,2, ψ_f ×0,92, et le filtre R_f ×1,5, L_f ×1,25.
    Les contrôleurs ne connaissent que les valeurs nominales. Le modèle C_p utilisé par la platitude a 10 % d'erreur.
    Creux de tension réseau de 20 % à t = 8 s pendant 200 ms.
* `main_mli.m` — **modèle commuté** : redresseur MLI + onduleur MLI deux niveaux.
  * SVPWM, porteuse 2160 Hz [1], échantillonnage régulier double mise à jour, pas d'intégration ≈ 1 µs.
  * Vent de 10 m/s puis 11 m/s à t = 0,45 s. THD de i_ga mesuré en régime établi (0,1–0,3 s).
* Fonctionne sous MATLAB et GNU Octave.
* Pour Simulink : `ctrl_fpbc_ann.m` et `ctrl_pi.m` → bloc *MATLAB Function* ; `plant_rhs.m` → modèle Simscape
  (PMSM + ponts IGBT + filtre L).

## 5. Plan pour la soumission (10 octobre)
1. ✅ Paramètres de la machine pris de [1] (Hasan & Shatil, AJSE 2021).
2. Figures : schéma bloc, vitesse/MPPT, C_p, V_dc, P/Q réseau, courants, gains ANN, formes d'onde MLI + THD.
3. Tableau d'indices (IAE vitesse, ISE V_dc, erreur de courant RMS, énergie produite).
4. Rédaction : Introduction → Modélisation → Commande plate + passive + ANN (+ preuve) → Résultats → Conclusion.

## 6. Résultats

Paramètres de la machine selon [1].

### 6.1 Modèle moyen (`main.m`, 10 s)
Erreurs de courant RMS en A : [t < 1 s] / [t ≥ 1 s].

| Scénario | Commande | IAE Ω | ISE V_dc | max abs(ΔV_dc) [V] | RMS e_s [A] | RMS e_g [A] | C_p moyen | Énergie [kWh] |
|---|---|---|---|---|---|---|---|---|
| nominal | PI | 0,0905 | 422,2 | 13,3 | 0,20 / 0,05 | 1,61 / 0,16 | 0,4652 | 3,504 |
| nominal | PI+FF | 0,0905 | 0,15 | 2,5 | 0,20 / 0,05 | 1,68 / 0,16 | 0,4652 | 3,504 |
| nominal | Plate+PBC | 0,0000 | 0,02 | 0,15 | 0,04 / 0,00 | 0,15 / 0,00 | 0,4654 | 3,485 |
| nominal | Plate+PBC+ANN | 0,0000 | 0,02 | 0,15 | 0,04 / 0,00 | 0,15 / 0,00 | 0,4654 | 3,485 |
| robustesse | PI | 0,0976 | 1278,8 | 119,6 | 3,06 / 0,17 | 9,11 / 4,51 | 0,4652 | 3,481 |
| robustesse | PI+FF | 0,0976 | 9,4 | 18,3 | 3,06 / 0,17 | 8,95 / 12,29 | 0,4652 | 3,481 |
| robustesse | Plate+PBC | 0,0181 | 2,6 | 10,9 | 9,40 / 0,18 | 16,34 / 10,13 | 0,4656 | 3,469 |
| robustesse | Plate+PBC+ANN | **0,0048** | **2,3** | 11,0 | 9,37 / 0,21 | 15,67 / 10,11 | 0,4654 | 3,465 |

### 6.2 Modèle commuté MLI (`main_mli.m`, f_MLI = 2160 Hz [1])
| Commande | THD i_ga (régime établi) |
|---|---|
| PI | 2,29 % |
| Plate+PBC+ANN | 2,29 % |

Les deux sont sous la limite de 5 % (IEEE 519). [1] annonce < 2 %, mais son modèle inclut un transformateur
35 kV/690 V et une ligne, dont les inductances filtrent davantage.

### 6.3 Lecture (à garder honnête dans l'article)
* **Bus DC, face à un PI équitable (PI+FF)** :
  * ISE V_dc : 2,3 contre 9,4 (÷ 4).
  * Écart max pendant le creux : 11 V contre 18 V. En nominal : 0,15 V contre 2,5 V.
  * Face au PI sans anticipation (120 V), la comparaison n'est pas équitable.
* **Apport de l'ANN** :
  * En nominal, il n'apporte rien : le modèle est exact.
  * En robustesse (10 % d'erreur sur C_p), l'ANN 2 divise l'IAE de vitesse par 3,8 (0,0181 → 0,0048).
    C'est la contribution principale de l'ANN.
  * L'ANN 1 (gains) a un effet faible : il ne s'active que pendant les grands transitoires.
* **Vitesse / MPPT** : l'IAE est 20 fois plus petit que le PI. Mais le C_p moyen est quasiment identique, et
  l'énergie injectée est ≈ 0,5 % plus faible (le rotor stocke plus d'énergie cinétique). Il ne faut pas annoncer de
  gain d'énergie.
* **Courants** : avec désaccord paramétrique, la PBC (qui utilise les valeurs nominales) a des erreurs plus grandes
  que le PI au démarrage et pendant le creux. Elles restent < 0,7 % du courant nominal.
* **THD** : identique au PI (2,29 %).
