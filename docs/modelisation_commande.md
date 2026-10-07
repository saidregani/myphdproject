# Chaîne éolienne PMSG 2 MW « back-to-back » : modélisation et commande APBC-ANN

> Note de travail de la réunion avec l'encadrant (sujet de conférence, **date limite de l'article complet : 10 octobre** ;
> conférence en Algérie les 14–15 décembre ; notification le 10 décembre).

## 1. Système étudié

```
 vent ─► Turbine ─► PMSG ─► Redresseur (MSC) ─► Bus DC (C) ─► Onduleur (GSC) ─► Filtre L ─► Réseau
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

## 3. Stratégie de commande proposée : APBC-ANN

Idée de l'encadrant : la **commande passive (PBC)** et la **commande adaptative** sont chacune classiques pour
cette chaîne, mais **leur association** (avec un **réseau de neurones** qui règle les paramètres en ligne)
n'a pas été proposée. Structure :

| Boucle | Erreur | Loi PBC (amortissement injecté) | Lois d'adaptation (Lyapunov) | ANN |
|---|---|---|---|---|
| Vitesse (MPPT) | e_Ω = Ω − Ω* | T_e* = T̂_w − BΩ − J dΩ*/dt + k_Ω(t) e_Ω | dT̂_w/dt = γ_T e_Ω | k_Ω = g_Ω·k_Ω0 |
| Courants MSC | e_s = i_s − i_s* | v_s = −L̂_s di_s*/dt − R̂_s i_s* + ω_e L̂_s 𝐉 i_s* + ω_e ψ̂ e_q + K_a(t) e_s | dR̂_s/dt = −γ_R e_sᵀ i_s* ; dL̂_s/dt = γ_L e_sᵀ(ω_e 𝐉 i_s* − di_s*/dt) ; dψ̂/dt = γ_ψ ω_e e_sq | K_a = g_s·K_a0 |
| Bus DC (énergie) | e_W = ½C(V_dc² − V_dc*²) | P_gsc* = P_msc + d̂ + k_v(t) e_W | dd̂/dt = γ_d e_W | k_v = g_v·k_v0 |
| Courants GSC | e_g = i_g − i_g* | v_i = L̂_f di_g*/dt + R̂_f i_g* − ω_g L̂_f 𝐉 i_g* + v_g − K_b(t) e_g | dR̂_f/dt = −γ_Rf e_gᵀ i_g* ; dL̂_f/dt = γ_Lf e_gᵀ(ω_g 𝐉 i_g* − di_g*/dt) | K_b = g_g·K_b0 |

Références : Ω* = λ_opt v/R (filtrée), i_sd* = 0, i_sq* = T_e*/(1,5 p ψ̂), i_gd* = 2P_gsc*/(3 v_gd), i_gq* = −2Q*/(3 v_gd).

### 3.1 Preuve de stabilité (boucle de courant MSC — les autres sont identiques)
En injectant la loi de commande dans le modèle :

L_s ė_s = −(R_s + K_a(t)) e_s + ω_e L_s 𝐉 e_s − R̃_s i_s* + L̃_s(ω_e 𝐉 i_s* − di_s*/dt) + ω_e ψ̃ e_q,   (θ̃ = θ − θ̂)

Fonction de stockage : V = ½ e_sᵀ L_s e_s + R̃_s²/(2γ_R) + L̃_s²/(2γ_L) + ψ̃²/(2γ_ψ)

Avec les lois d'adaptation du tableau et e_sᵀ𝐉e_s = 0 :

**dV/dt = −(R_s + K_a(t)) ‖e_s‖² ≤ 0**  ⇒ e_s, θ̃ bornés, et (Barbalat) e_s → 0.

**Point clé de l'article** : la dérivée reste négative **pour tout gain K_a(t) > 0**. Le réseau de neurones peut donc
modifier les gains en ligne sans jamais casser la preuve de stabilité, à condition que le gain reste borné et
positif — garanti par la sortie sigmoïde g ∈ [g_min, g_max] = [0,5 ; 3].

Boucle de vitesse : J ė_Ω = −k_Ω(t) e_Ω + T̃_w ; V = ½J e_Ω² + T̃_w²/(2γ_T) ⇒ dV/dt = −k_Ω e_Ω² (T_w lentement variable).
Bus DC : ė_W = −k_v(t) e_W + d̃ ; V = ½ e_W² + d̃²/(2γ_d) ⇒ dV/dt = −k_v e_W².
(Les saturations de couple/courant/tension sont traitées par gel de l'adaptation ; à mentionner comme limite.)

### 3.2 Réglage en ligne des gains par ANN (RBF)
* Entrées : erreur normalisée e_n et sa dérivée ; 9 neurones gaussiens (grille 3×3) ; sortie sigmoïde → g ∈ [0,5 ; 3].
* Critère : E = ½ e_n². Comme L ė = −K e + …, on a ∂E/∂K ≈ −e² T_s/L < 0 : la descente de gradient
  augmente le gain quand l'erreur est grande (transitoires).
* Mise à jour : ẇ = η e_n² ∂g/∂w − σ w (σ-modification : retour au gain nominal en régime établi et poids bornés).

### 3.3 Commande de référence (comparaison)
Commande vectorielle classique à PI (vitesse, courants MSC/GSC avec découplage, bus DC), réglée **sur les mêmes
pôles nominaux** que l'APBC (courants τ = 2 ms, vitesse ω_n = 2 rad/s, ζ = 0,9, bus DC ω_n = 60 rad/s).

## 4. Simulation (`matlab/`)
* `main.m` : lance les 4 cas (PI / APBC-ANN × nominal / robustesse), affiche le tableau de comparaison et sauvegarde
  les figures dans `results/`.
* Scénario **nominal** : profil de vent 8 → 10 → 11 → 9 m/s + turbulence.
* Scénario **robustesse** : machine réelle R_s ×1,5, L_s ×1,2, ψ_f ×0,92 ; filtre R_f ×1,5, L_f ×1,25 (les
  contrôleurs ne connaissent que les valeurs nominales) + creux de tension réseau de 20 % à t = 8 s pendant 200 ms.
* Modèle **moyen** (pas de MLI), RK4, T_s = 100 µs. Fonctionne sous MATLAB et GNU Octave.
* Pour Simulink : chaque contrôleur (`ctrl_pi.m`, `ctrl_apbc_ann.m`) peut être mis dans un bloc *MATLAB Function*,
  et `plant_rhs.m` peut être remplacé par le modèle commuté (Simscape Electrical : PMSM + ponts IGBT + filtre L).

## 5. Plan pour la soumission (10 octobre)
1. Valider les paramètres 2 MW avec une référence (Wu et al., *Power Conversion and Control of Wind Energy Systems*, ou
   un article IEEE sur PMSG 2 MW) et les citer.
2. Vérifier avec l'encadrant l'interprétation « commande adaptative » (dans l'audio : « par l'attitude »).
3. Figures : vitesse/MPPT, C_p, V_dc, P/Q réseau, courants, gains ANN, estimation des paramètres.
4. Tableau d'indices (IAE vitesse, ISE V_dc, erreur de courant RMS, énergie produite).
5. Rédaction : Introduction → Modélisation → Commande APBC-ANN (+ preuve) → Résultats → Conclusion.

## 6. Premiers résultats (Octave, `matlab/main.m`)

Erreurs de courant RMS en A : [t < 1 s, phase d'apprentissage] / [t ≥ 1 s].

| Scénario | Commande | IAE Ω | ISE V_dc | max abs(ΔV_dc) [V] | RMS e_s [A] | RMS e_g [A] | C_p moyen | Énergie [kWh] |
|---|---|---|---|---|---|---|---|---|
| nominal | PI | 0,0905 | 421,6 | 13,3 | 0,23 / 0,06 | 1,20 / 0,12 | 0,4652 | 3,503 |
| nominal | APBC-ANN | 0,0697 | 0,05 | 0,6 | 0,01 / 0,01 | 0,01 / 0,01 | 0,4667 | 3,497 |
| robustesse | PI | 0,0976 | 1264,9 | 116,6 | 4,16 / 0,20 | 8,94 / 4,40 | 0,4652 | 3,479 |
| robustesse | APBC-ANN | 0,0679 | 6,8 | 17,8 | 13,85 / 0,02 | 20,56 / 9,55 | 0,4667 | 3,476 |

Lecture :
* **Bus DC** : c'est le gain principal (écart max 0,6 V contre 13 V en nominal ; 18 V contre 117 V pendant le creux
  de tension). Ce gain vient surtout de l'anticipation de P_msc dans la loi énergétique PBC. Un relecteur peut demander
  une comparaison avec un PI qui utilise la même anticipation.
* **Vitesse / MPPT** : IAE réduit d'environ 25 % grâce au terme J dΩ*/dt ; C_p et énergie sont pratiquement identiques
  (la boucle de vitesse adaptative est équivalente à un PI quand T_w est constant).
* **Courants** : l'APBC est meilleure une fois les paramètres appris (estimations → R_s ≈ 1,6, L_s = 1,20, ψ = 0,92 × nominal).
  Elle est moins bonne pendant la première seconde (apprentissage). Pendant le creux réseau, l'erreur de i_g est plus
  grande parce que la référence i_gd* saute instantanément.
* Le gain ANN de vitesse monte à ≈ 2 lors des rafales et revient à 1 (σ-modification).
