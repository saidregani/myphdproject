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
* **ANN adaptatif (6-10-2)** → compensation en ligne u_AI ajoutée aux boucles plates, sans toucher aux gains nominaux
  (même méthode que [2]).

### Schéma bloc

```
                    ┌──── ANN adaptatif 6-10-2 : u_AI = [ΔT_e ; ΔP_g] ────┐
                    ▼ (+ΔT_e)                                       (+ΔP_g) ▼
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

### 3.4 Compensation adaptative par ANN (même méthode que l'article *Mathematics* [2])
L'ANN **ne remplace pas** la commande nominale et **ne modifie pas ses gains**. Il ajoute un signal de compensation :

**u = u_N + u_AI**,  u_AI = [ΔT_e ; ΔP_g], ajouté aux entrées des deux boucles plates (T_e* et P_g*).

* **Entrées (6)** : z = [e_Ω, e_y2, e_isq, ė_Ω, ė_y2, ė_isq]ᵀ, normalisées : z_n = S_in⁻¹ z.
* **Structure 6-10-2** : h = tanh(W₁ z_n + b₁), y = W₂ h + b₂, u_AI = K_AI · sat(y).
* **Signal d'apprentissage** (direction de commande) : r = Bᵀe = [e_Ω ; e_y2]. T_e et P_g entrent avec un signe
  positif dans ė_Ω et ė_y2.
* **Zone morte** : r_a = r si ‖e‖ > δ, sinon r_a = 0.
* **Lois d'adaptation** :
  * Ẇ₂ = −Γ r_a hᵀ − σW₂,  ḃ₂ = −Γ r_a − σb₂
  * δ_h = (1 − h²) ⊙ (W₂ᵀ r_a)
  * Ẇ₁ = −Γ δ_h z_nᵀ − σW₁,  ḃ₁ = −Γ δ_h − σb₁
* **Stabilité** (comme le Théorème 2 de [2]) : la commande nominale est stable (boucles plates + PBC, §3.1–3.3).
  Avec une erreur d'approximation bornée, les termes σ et la zone morte, l'erreur est **uniformément ultimement
  bornée** (V = ½eᵀPe + ‖Θ̃‖²/(2Γ), dV/dt ≤ −α‖e‖² + c_ε‖e‖).
* **Réglage** : Γ = 5, σ = 0,01, δ = 0,1 (en erreur normalisée), K_AI = 1, saturation 3, ce qui donne
  u_AI ∈ [−0,3 T_n ; 0,3 T_n] et [−0,3 P_n ; 0,3 P_n].
  Avec Γ ≥ 20, la boucle bus DC devient instable, donc il faut garder une marge.

[2] S. Regani, M. Messadi, K. Kemih, « A Novel Chaos Control Approach with Adaptive ANN Compensation for a
DFIG-Based Wind Turbine », *Mathematics* (soumis).

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

Paramètres de la machine selon [1]. ANN selon [2] (Γ = 5).

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
| robustesse | Plate+PBC | 0,0181 | 2,59 | 10,9 | 9,40 / 0,18 | 16,34 / 10,13 | 0,4656 | 3,469 |
| robustesse | Plate+PBC+ANN | **0,0128** | **1,93** | **10,4** | 9,40 / 0,36 | 16,63 / 10,73 | 0,4655 | 3,467 |

Apport de l'ANN en robustesse (même gains nominaux, comme dans [2]) :

| Indice | Sans ANN | Avec ANN | Amélioration |
|---|---|---|---|
| IAE vitesse | 0,0181 | 0,0128 | −29 % |
| ISE V_dc | 2,59 | 1,93 | −25 % |
| max abs(ΔV_dc) | 10,9 V | 10,4 V | −5 % |

### 6.2 Modèle commuté MLI (`main_mli.m`, f_MLI = 2160 Hz [1])
| Commande | THD i_ga (régime établi) |
|---|---|
| PI | 2,29 % |
| Plate+PBC+ANN | 2,30 % |

### 6.3 Lecture (à garder honnête dans l'article)
* **Bus DC, face à un PI équitable (PI+FF)** : ISE 1,9 contre 9,4 (÷ 5), écart max 10 V contre 18 V.
* **ANN** :
  * En nominal, il ne s'active pas : l'erreur reste dans la zone morte.
  * En robustesse, il réduit l'erreur de vitesse de 29 % et l'ISE du bus DC de 25 %, sans retoucher les gains.
  * L'erreur de courant e_s augmente légèrement (0,18 → 0,36 A, < 0,02 % du nominal), car l'ANN modifie T_e*.
  * Γ ≥ 20 rend la boucle bus DC instable : la garantie est seulement UUB, à condition que les paramètres restent bornés.
* **Vitesse / MPPT** : l'IAE est 7,6 fois plus petit que le PI. Mais le C_p moyen est quasiment identique et
  l'énergie est ≈ 0,4 % plus faible. Il ne faut pas annoncer de gain d'énergie.
* **THD** : identique au PI.
