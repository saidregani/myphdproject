%% ========================================================================
%  CHAÎNE ÉOLIENNE PMSG 2 MW À ATTAQUE DIRECTE — COMMANDE PLATE + PASSIVE + ANN
%  ========================================================================
%
%  Script unique et autonome : il ne dépend d'aucun autre fichier.
%  Lancer :  >> PMSG_Plate_PBC_ANN        (MATLAB R2016b ou plus récent)
%
%  SYSTÈME ÉTUDIÉ (chaîne « back-to-back ») :
%
%   vent → Turbine → PMSG → Redresseur MLI → Bus DC → Onduleur MLI → Filtre L → Réseau
%          (R=40 m)  (attaque  (MSC)          (C)      (GSC)          (Rf,Lf)    690 V
%                     directe)                                                   50 Hz
%
%  COMMANDE PROPOSÉE :
%   * Boucles externes  → commande par PLATITUDE
%        - vitesse de rotation (MPPT), sortie plate  y1 = Ω
%        - énergie du bus DC,          sortie plate  y2 = ½·C·Vdc² + ¾·Lf·|ig|²
%   * Boucles internes  → commande PASSIVE (PBC) des courants
%        - courants du générateur (redresseur MLI)
%        - courants injectés au réseau (onduleur MLI + filtre L)
%   * Compensation ADAPTATIVE par réseau de neurones (ANN 6-10-2)
%        u = u_N + u_AI : l'ANN ajoute ΔTe et ΔPg aux lois plates, SANS modifier
%        les gains nominaux (même méthode que l'article Mathematics, DFIG).
%
%  ORGANISATION DU SCRIPT :
%    1. Choix du scénario
%    2. Paramètres (turbine, PMSG, bus DC, réseau, filtre)
%    3. Réglage de la commande (gains et paramètres de l'ANN)
%    4. Simulation (et, en option, la même simulation sans ANN)
%    5. Indices de performance
%    6. Figures
%    Fonctions locales (en fin de fichier) :
%       simuler, modele_chaine, couple_eolien, coefficient_Cp, profil_vent,
%       tension_reseau, ann_init, ann_pas, saturer, saturer_vecteur
%
%  Modèle MOYEN des convertisseurs (pas de commutation MLI), intégration RK4,
%  période d'échantillonnage de la commande Ts = 100 µs.
%
%  Références :
%   [1] S. M. M. Hasan, A. H. M. Shatil, « Design and Comparison of Grid Connected
%       PMSG Non-salient Pole and Salient Pole Rotor Wind Turbine », AJSE, vol. 20,
%       n° 2, pp. 40-46, 2021  → paramètres de la PMSG, du bus DC, du réseau.
%   [2] S. Regani, M. Messadi, K. Kemih, « A Novel Chaos Control Approach with
%       Adaptive ANN Compensation for a DFIG-Based Wind Turbine », Mathematics
%       (soumis)  → structure et lois d'adaptation de l'ANN.
%  ========================================================================

clear; close all; clc;


%% ========================================================================
%  1. CHOIX DU SCÉNARIO
%  ========================================================================
%  ROBUSTE = 0 : la commande connaît les vrais paramètres (cas nominal).
%  ROBUSTE = 1 : cas difficile pour tester la robustesse :
%     - la vraie machine a  Rs ×1,5   Ls ×1,2   ψf ×0,92  (échauffement, saturation)
%     - le vrai filtre a    Rf ×1,5   Lf ×1,25
%     - le modèle Cp utilisé par la commande est faux de 10 %
%     - creux de tension réseau de 20 % entre t = 8 s et t = 8,2 s
%  La commande, elle, utilise toujours les valeurs NOMINALES.

cfg.ROBUSTE          = 1;      % 0 = nominal, 1 = robustesse
cfg.ANN              = 1;      % 1 = avec compensation ANN, 0 = sans
cfg.COMPARER_SANS_ANN = true;  % refait la même simulation sans ANN pour comparer
cfg.Tfin             = 10;     % durée simulée [s]


%% ========================================================================
%  2. PARAMÈTRES DU SYSTÈME
%  ========================================================================

% ---- 2.1 Turbine (données de l'encadrant) ------------------------------
P.rho   = 1.225;        % masse volumique de l'air            [kg/m³]
P.R     = 40;           % rayon du rotor                      [m]
P.Pn    = 2e6;          % puissance nominale                  [W]
P.wn    = 2.23;         % vitesse nominale de rotation        [rad/s]
P.Tn    = P.Pn/P.wn;    % couple nominal  (≈ 0,9 MN·m)        [N·m]
P.lopt  = 8.1;          % vitesse spécifique optimale λopt (Cp,max = 0,48)
P.beta  = 0;            % angle de calage (pas de contrôle du pitch ici) [deg]
P.J     = 2.8e6;        % inertie totale ramenée à l'arbre (H ≈ 3,5 s, hypothèse) [kg·m²]
P.B     = 1e3;          % frottement visqueux (hypothèse)     [N·m·s/rad]

% ---- 2.2 PMSG à pôles lisses (Ld = Lq), réf. [1] Table I ---------------
P.p     = 26;           % nombre de paires de pôles
P.Rs    = 0.78e-3;      % résistance statorique               [Ω]
P.Ls    = 1.57e-3;      % inductance synchrone                [H]
P.psi   = 9.18;         % flux des aimants                    [Wb]

% ---- 2.3 Bus continu, réf. [1] ------------------------------------------
P.C     = 20e-3;        % capacité du bus DC                  [F]
P.Vdc_ref = 1200;       % tension de référence                [V]

% ---- 2.4 Réseau et filtre L, réf. [1] -----------------------------------
P.Vg_ll = 690;                      % tension composée efficace     [V]
P.Vgm   = P.Vg_ll*sqrt(2/3);        % amplitude de la tension simple (= v_gd) [V]
P.wg    = 2*pi*50;                  % pulsation du réseau           [rad/s]
P.Lf    = 0.15e-3;                  % inductance du filtre          [H]
P.Rf    = 2e-3;                     % résistance du filtre (hypothèse) [Ω]
P.Qref  = 0;                        % puissance réactive de référence (cos φ = 1)

% ---- 2.5 Limites physiques ----------------------------------------------
P.Imax_s = 1.3*P.Tn/(1.5*P.p*P.psi);  % courant max côté machine (crête) [A]
P.Imax_g = 1.3*P.Pn/(1.5*P.Vgm);      % courant max côté réseau  (crête) [A]
P.Te_min = 0;                          % pas de fonctionnement moteur en MPPT
P.Te_max = 1.2*P.Tn;

% ---- 2.6 Simulation ------------------------------------------------------
P.Ts    = 1e-4;         % période d'échantillonnage de la commande = pas RK4 [s]
P.Tfin  = cfg.Tfin;

% Vérification rapide : force électromotrice à 9,75 Hz (fréquence nominale de [1])
% E = ψf·ωe = 9,18 × 2π × 9,75 ≈ 562 V  ≈  crête de la tension simple 690 V (563 V)


%% ========================================================================
%  3. RÉGLAGE DE LA COMMANDE
%  ========================================================================
%  Toutes les boucles sont réglées par placement de pôles. L'erreur obéit à
%     ė + k1·e + k2·∫e = 0      (pôles : ωn, amortissement ζ)
%  donc  k1 = 2ζωn  et  k2 = ωn².

% ---- 3.1 Boucle de vitesse — PLATITUDE (y1 = Ω) --------------------------
%  Modèle mécanique :  J·dΩ/dt = Tw − Te − B·Ω
%  Ω est une sortie plate : Te s'exprime directement avec Ω et sa dérivée
%     Te = Tw − B·Ω − J·dΩ/dt
%  Loi plate (on impose la dynamique désirée ν1 à la place de dΩ/dt) :
%     Te* = T̂w − B·Ω − J·ν1 + ΔTe(ANN)
%     ν1  = dΩ*/dt + k11·(Ω* − Ω) + k12·∫(Ω* − Ω)
%  T̂w est calculé avec le modèle Cp(λ) et le vent mesuré.
G.wn_w = 2;    G.zeta_w = 0.9;
G.k11 = 2*G.zeta_w*G.wn_w;   G.k12 = G.wn_w^2;

% ---- 3.2 Boucle du bus DC — PLATITUDE (y2 = énergie stockée) -------------
%  y2 = ½·C·Vdc² + ¾·Lf·(igd² + igq²)   (bus DC + inductances du filtre)
%  dy2/dt = P_msc − P_réseau − 1,5·Rf·|ig|²     avec  P_réseau = 1,5·v_gd·i_gd
%  Loi plate :
%     P_réseau* = P_msc − 1,5·Rf·|ig|² − ν2 + ΔPg(ANN)
%     ν2        = k21·(y2* − y2) + k22·∫(y2* − y2)
%     i_gd* = 2·P_réseau*/(3·v_gd),   i_gq* = −2·Q*/(3·v_gd)
G.wn_v = 60;   G.zeta_v = 1;
G.k21 = 2*G.zeta_v*G.wn_v;   G.k22 = G.wn_v^2;

% ---- 3.3 Boucles de courant — COMMANDE PASSIVE (PBC) ---------------------
%  Modèle de la PMSG (convention générateur, repère dq du rotor, J = [0 1; −1 0]) :
%     Ls·dis/dt = −Rs·is + ωe·Ls·J·is + ωe·ψf·e_q − vs
%  Le terme ωe·Ls·J·is est un couplage « sans travail » (isᵀ·J·is = 0) :
%  la PBC le CONSERVE au lieu de le compenser et injecte de l'amortissement :
%     vs* = −Ls·di*/dt − Rs·i* + ωe·Ls·J·i* + ωe·ψf·e_q + Ra·e + Ki·∫e,   e = is − is*
%  Dynamique de l'erreur :  Ls·ė = −(Rs + Ra)·e + ωe·Ls·J·e − Ki·∫e
%  Fonction de stockage H = ½·eᵀ·Ls·e + ½·Ki·zᵀz  ⇒  dH/dt = −(Rs + Ra)·|e|² ≤ 0
%  Même principe pour l'onduleur et le filtre L :
%     vi* = Lf·di*/dt + Rf·i* − ωg·Lf·J·i* + vg − Rb·e − Kig·∫e
G.tau_i = 2e-3;                              % constante de temps des courants [s]
G.Ra  = P.Ls/G.tau_i;  G.Kis = P.Ls/(4*G.tau_i^2);   % redresseur
G.Rb  = P.Lf/G.tau_i;  G.Kig = P.Lf/(4*G.tau_i^2);   % onduleur
G.tau_d = 2e-3;                              % filtre de dérivation des références [s]

% ---- 3.4 MPPT -------------------------------------------------------------
%  Ω* = λopt·v/R, avec un filtre sur le vent mesuré (anémomètre) et un filtre
%  de référence du 2e ordre (ωn = 1,5 rad/s) qui fournit aussi dΩ*/dt.
G.tau_v = 0.3;   G.wn_ref = 1.5;

% ---- 3.5 Réseau de neurones adaptatif (ANN 6-10-2), méthode de [2] -------
%  Entrées (6) : z = [eΩ, ey, eisq, ėΩ, ėy, ėisq], normalisées
%  Structure   : h = tanh(W1·z + b1),  y = W2·h + b2,  u_AI = K_AI·sat(y)
%  Sorties (2) : u_AI = [ΔTe ; ΔPg]  ajoutées aux deux lois plates
%  Signal d'apprentissage (direction de la commande) : r = Bᵀe = [eΩ ; ey]
%  Zone morte : pas d'apprentissage si |e| ≤ δ
%  Lois d'adaptation (σ-modification + rétropropagation) :
%     dW2/dt = −Γ·r·hᵀ − σ·W2          db2/dt = −Γ·r − σ·b2
%     δh     = (1 − h²) ⊙ (W2ᵀ·r)
%     dW1/dt = −Γ·δh·zᵀ − σ·W1         db1/dt = −Γ·δh − σ·b1
%  Stabilité : erreur uniformément ultimement bornée (Théorème 2 de [2]).
A.Gamma = 5;      % gain d'adaptation (Γ ≥ 20 déstabilise la boucle du bus DC)
A.sigma = 0.01;   % coefficient de régularisation (σ-modification)
A.delta = 0.1;    % seuil de la zone morte (erreur normalisée)
A.KAI   = 1;      % coefficient de l'ANN
A.ysat  = 3;      % saturation de la sortie
A.e_w = 0.01*P.wn;                    % normalisation : 1 % de la vitesse nominale
A.e_y = 300;                          %                 ≈ 1 % de Vdc (en énergie, J)
A.e_i = 0.01*P.Tn/(1.5*P.p*P.psi);    %                 1 % du courant nominal
A.tz  = [0.5; 0.02; 2e-3];            % échelles de temps des entrées dérivées [s]
A.tau_z = 5e-3;                       % filtre des dérivées [s]
A.echelle = [0.1*P.Tn; 0.1*P.Pn];     % ΔTe en 0,1·Tn, ΔPg en 0,1·Pn


%% ========================================================================
%  4. SIMULATION
%  ========================================================================
fprintf('Simulation (ROBUSTE = %d, ANN = %d, %g s) ...\n', cfg.ROBUSTE, cfg.ANN, P.Tfin);
tic;  res = simuler(P, G, A, cfg.ROBUSTE, cfg.ANN);  toc;

if cfg.COMPARER_SANS_ANN && cfg.ANN
  fprintf('Même simulation sans ANN (comparaison) ...\n');
  tic;  res0 = simuler(P, G, A, cfg.ROBUSTE, 0);  toc;
end


%% ========================================================================
%  5. INDICES DE PERFORMANCE
%  ========================================================================
ind = @(r) struct( ...
  'IAE_w',   sum(abs(r.w - r.wr))*r.dt, ...                     % erreur de vitesse [rad]
  'ISE_Vdc', sum((r.Vdc - P.Vdc_ref).^2)*r.dt, ...               % [V²·s]
  'dVmax',   max(abs(r.Vdc - P.Vdc_ref)), ...                    % écart max de Vdc [V]
  'Cp',      mean(r.Cp), ...                                      % Cp moyen
  'E',       sum(r.P)*r.dt/3.6e6);                                % énergie injectée [kWh]
I = ind(res);
fprintf('\n=========== RÉSULTATS ===========\n');
fprintf('                         avec ANN');
if exist('res0', 'var'), I0 = ind(res0); fprintf('    sans ANN   amélioration'); end
fprintf('\n');
noms = {'IAE vitesse [rad]', 'ISE Vdc [V².s]', 'écart max Vdc [V]', 'Cp moyen', 'énergie [kWh]'};
champs = {'IAE_w', 'ISE_Vdc', 'dVmax', 'Cp', 'E'};
for k = 1:numel(champs)
  fprintf('%-22s %10.4g', noms{k}, I.(champs{k}));
  if exist('res0', 'var')
    fprintf('  %10.4g   %+6.1f %%', I0.(champs{k}), 100*(I.(champs{k}) - I0.(champs{k}))/I0.(champs{k}));
  end
  fprintf('\n');
end


%% ========================================================================
%  6. FIGURES
%  ========================================================================
t = res.t;

% ---- Figure 1 : vue d'ensemble de la chaîne ------------------------------
figure('Name', 'Vue d''ensemble', 'Position', [60 60 1150 780]);
subplot(3,2,1); plot(t, res.v); grid on;
ylabel('v [m/s]'); title('Vitesse du vent (éq. (80) de [2])');
subplot(3,2,2); plot(t, res.w, t, res.wr, '--'); grid on;
ylabel('\Omega [rad/s]'); legend('\Omega', '\Omega^* (MPPT)', 'Location', 'best');
title('Vitesse de rotation');
subplot(3,2,3); plot(t, res.Cp); grid on; ylim([0.38 0.49]);
ylabel('C_p'); title('Coefficient de puissance (C_{p,max} = 0,48)');
subplot(3,2,4); plot(t, res.Vdc); grid on;
ylabel('V_{dc} [V]'); title('Tension du bus DC');
subplot(3,2,5); plot(t, res.P/1e6, t, res.Q/1e6); grid on;
ylabel('[MW, Mvar]'); xlabel('t [s]'); legend('P', 'Q', 'Location', 'best');
title('Puissances injectées au réseau');
subplot(3,2,6); plot(t, res.Te/1e6, t, res.Tw/1e6, '--'); grid on;
ylabel('[MN.m]'); xlabel('t [s]'); legend('T_e', 'T_w', 'Location', 'best');
title('Couples électromagnétique et éolien');

% ---- Figure 2 : courants (commande passive) --------------------------------
figure('Name', 'Courants', 'Position', [80 80 1150 520]);
subplot(2,2,1); plot(t, res.is(:,2), t, res.isr(:,2), '--'); grid on;
ylabel('i_{sq} [A]'); legend('mesure', 'référence', 'Location', 'best');
title('Courant i_{sq} du générateur (redresseur MLI)');
subplot(2,2,2); plot(t, res.is(:,1)); grid on;
ylabel('i_{sd} [A]'); title('Courant i_{sd} (référence 0)');
subplot(2,2,3); plot(t, res.ig(:,1), t, res.igr(:,1), '--'); grid on;
ylabel('i_{gd} [A]'); xlabel('t [s]'); legend('mesure', 'référence', 'Location', 'best');
title('Courant i_{gd} injecté au réseau (onduleur MLI)');
subplot(2,2,4); plot(t, res.ig(:,2)); grid on;
ylabel('i_{gq} [A]'); xlabel('t [s]'); title('Courant i_{gq} (référence 0, Q = 0)');

% ---- Figure 3 : ce que fait l'ANN -----------------------------------------
%  En robustesse, le modèle Cp de la commande est faux de 10 % : T̂w ≠ Tw.
%  L'ANN ne connaît pas cette erreur, mais sa sortie ΔTe la retrouve.
figure('Name', 'ANN', 'Position', [100 100 1150 520]);
subplot(2,1,1); plot(t, res.uAI(:,1)/1e6, t, (res.Tw - res.Twh)/1e6, '--'); grid on;
ylabel('[MN.m]'); legend('\Delta T_e (sortie ANN)', 'T_w - \hat{T}_w (erreur réelle du modèle)', ...
  'Location', 'best');
title('Compensation du couple par l''ANN');
subplot(2,1,2); plot(t, res.uAI(:,2)/1e6); grid on;
ylabel('\Delta P_g [MW]'); xlabel('t [s]'); title('Compensation de la puissance (bus DC)');

% ---- Figure 4 : avec / sans ANN --------------------------------------------
if exist('res0', 'var')
  figure('Name', 'Avec / sans ANN', 'Position', [120 120 1150 520]);
  subplot(2,1,1); plot(t, res0.w - res0.wr, t, res.w - res.wr); grid on;
  ylabel('\Omega - \Omega^* [rad/s]'); legend('sans ANN', 'avec ANN', 'Location', 'best');
  title(sprintf('Erreur de vitesse   (IAE : %.4f → %.4f rad)', I0.IAE_w, I.IAE_w));
  subplot(2,1,2); plot(t, res0.Vdc, t, res.Vdc); grid on;
  ylabel('V_{dc} [V]'); xlabel('t [s]'); legend('sans ANN', 'avec ANN', 'Location', 'best');
  title(sprintf('Tension du bus DC   (ISE : %.2f → %.2f V^2s)', I0.ISE_Vdc, I.ISE_Vdc));
end


%% ========================================================================
%  FONCTIONS LOCALES
%  ========================================================================

function r = simuler(P, G, A, robuste, avec_ann)
%SIMULER  Simulation en boucle fermée de la chaîne complète.
%  La commande est exécutée toutes les Ts ; entre deux échantillons, les
%  tensions des convertisseurs sont maintenues (bloqueur d'ordre 0) et le
%  modèle continu est intégré par Runge-Kutta 4.

% ---- Paramètres de la « vraie » installation -------------------------------
Pv = P;
kTw = 1;                                  % précision du modèle Cp de la commande
if robuste
  Pv.Rs = 1.5*P.Rs;  Pv.Ls = 1.2*P.Ls;  Pv.psi = 0.92*P.psi;
  Pv.Rf = 1.5*P.Rf;  Pv.Lf = 1.25*P.Lf;
  kTw = 0.9;                              % la commande sous-estime Tw de 10 %
end

% ---- État initial : régime permanent MPPT à v(0) ---------------------------
%  x = [isd, isq, Ω, Vdc, igd, igq]
v0  = profil_vent(0);
w0  = P.lopt*v0/P.R;
Tw0 = couple_eolien(w0, v0, Pv);
isq0 = (Tw0 - Pv.B*w0)/(1.5*Pv.p*Pv.psi);
we0 = Pv.p*w0;
vs0 = [we0*Pv.Ls*isq0; we0*Pv.psi - Pv.Rs*isq0];     % tension du redresseur
igd0 = 1.5*vs0(2)*isq0/(1.5*P.Vgm);                  % même puissance côté réseau
vi0 = [P.Vgm + Pv.Rf*igd0; Pv.wg*Pv.Lf*igd0];        % tension de l'onduleur
x = [0; isq0; w0; P.Vdc_ref; igd0; 0];
u = [vs0; vi0];

% ---- États internes de la commande -----------------------------------------
vf = v0;  wr = w0;  dwr = 0;        % MPPT : vent filtré, Ω* et dΩ*/dt
zw = 0;   zv = 0;                   % intégrales des boucles plates
isf = [0; isq0];  zs = [0; 0];      % PBC redresseur : référence filtrée, intégrale
igf = [igd0; 0];  zg = [0; 0];      % PBC onduleur
nn  = ann_init(6, 10, 2, A);  nn.on = (avec_ann ~= 0);
ef  = [0; 0; 0];  uAI = [0; 0];     % ANN : erreurs filtrées et sortie retardée
J2  = [0 1; -1 0];                  % matrice antisymétrique (couplage dq)
Ts  = P.Ts;

% ---- Enregistrement (une valeur sur 10) ------------------------------------
N = round(P.Tfin/Ts);  dec = 10;  M = floor(N/dec);
r.dt = dec*Ts;
r.t = zeros(M,1);  r.v = r.t;  r.w = r.t;  r.wr = r.t;  r.Vdc = r.t;  r.Cp = r.t;
r.P = r.t;  r.Q = r.t;  r.Te = r.t;  r.Tw = r.t;  r.Twh = r.t;
r.is = zeros(M,2);  r.isr = r.is;  r.ig = r.is;  r.igr = r.is;  r.uAI = r.is;
k = 0;

for n = 0:N-1
  t  = n*Ts;
  v  = profil_vent(t);                   % vent mesuré
  vg = tension_reseau(t, robuste, P);    % tension du réseau (PLL idéale)
  is = x(1:2);  w = x(3);  Vdc = x(4);  ig = x(5:6);
  we = P.p*w;

  % ===================== COMMANDE (toutes les Ts) ==========================
  % (a) MPPT : Ω* = λopt·v/R, filtré, avec sa dérivée
  vf   = vf + Ts/G.tau_v*(v - vf);
  wraw = saturer(P.lopt*vf/P.R, 0.4*P.wn, 1.05*P.wn);
  ddwr = G.wn_ref^2*(wraw - wr) - 2*G.wn_ref*dwr;
  wr   = wr + Ts*dwr;   dwr = dwr + Ts*ddwr;

  % (b) PLATITUDE — vitesse :  Te* = T̂w − BΩ − J·ν1 + ΔTe
  ew  = wr - w;
  Twh = kTw*couple_eolien(w, v, P);
  nu1 = dwr + G.k11*ew + G.k12*zw;
  Te  = Twh - P.B*w - P.J*nu1 + uAI(1);
  Tes = saturer(Te, P.Te_min, P.Te_max);
  sat_w = ~(Te == Tes || sign(-ew) ~= sign(Te - Tes));
  if ~sat_w, zw = zw + Ts*ew; end                      % anti-emballement
  isr = [0; saturer(Tes/(1.5*P.p*P.psi), -P.Imax_s, P.Imax_s)];   % isd* = 0

  % (c) PBC — courants du redresseur MLI
  disr = (isr - isf)/G.tau_d;   isf = isf + Ts*disr;   % dérivée filtrée de is*
  es   = is - isr;
  vs   = -P.Ls*disr - P.Rs*isr + we*P.Ls*J2*isr + [0; we*P.psi] + G.Ra*es + G.Kis*zs;
  vsl  = saturer_vecteur(vs, Vdc/sqrt(3));             % limite de la MLI vectorielle
  if norm(vs - vsl) < 1e-9, zs = zs + Ts*es; end

  % (d) PLATITUDE — bus DC :  P_réseau* = P_msc − pertes − ν2 + ΔPg
  Pmsc = 1.5*(u(1)*is(1) + u(2)*is(2));                % puissance du redresseur
  y2   = 0.5*P.C*Vdc^2 + 0.75*P.Lf*(ig'*ig);           % sortie plate
  y2r  = 0.5*P.C*P.Vdc_ref^2 + 0.75*P.Lf*(igf'*igf);
  ey   = y2r - y2;
  nu2  = G.k21*ey + G.k22*zv;
  Pgr  = Pmsc - 1.5*P.Rf*(ig'*ig) - nu2 + uAI(2);
  igd  = 2*Pgr/(3*vg(1));
  igdl = saturer(igd, -P.Imax_g, P.Imax_g);
  sat_v = (igd ~= igdl);
  if ~sat_v, zv = zv + Ts*ey; end
  igr  = [igdl; -2*P.Qref/(3*vg(1))];

  % (e) PBC — courants de l'onduleur MLI + filtre L
  digr = (igr - igf)/G.tau_d;   igf = igf + Ts*digr;
  eg   = ig - igr;
  vi   = P.Lf*digr + P.Rf*igr - P.wg*P.Lf*J2*igr + vg - G.Rb*eg - G.Kig*zg;
  vil  = saturer_vecteur(vi, Vdc/sqrt(3));
  if norm(vi - vil) < 1e-9, zg = zg + Ts*eg; end

  % (f) ANN adaptatif : apprend sur les erreurs, sortie utilisée à l'échantillon suivant
  e  = [ew/A.e_w; ey/A.e_y; es(2)/A.e_i];              % erreurs normalisées
  de = (e - ef)/A.tau_z;   ef = ef + Ts*de;            % dérivées filtrées
  zn = [e; de.*A.tz];                                  % 6 entrées
  [y, nn] = ann_pas(nn, zn, e(1:2), Ts, ~(sat_w || sat_v));
  uAI = y.*A.echelle;                                  % [ΔTe ; ΔPg]

  u = [vsl; vil];                                      % tensions appliquées

  % ===================== ENREGISTREMENT ====================================
  if mod(n, dec) == 0 && k < M
    k = k + 1;
    lam = w*P.R/v;
    r.t(k) = t;  r.v(k) = v;  r.w(k) = w;  r.wr(k) = wr;  r.Vdc(k) = Vdc;
    r.Cp(k) = coefficient_Cp(lam, P.beta);
    r.Tw(k) = couple_eolien(w, v, Pv);  r.Twh(k) = Twh;
    r.Te(k) = 1.5*Pv.p*Pv.psi*is(2);
    r.P(k) = 1.5*(vg(1)*ig(1) + vg(2)*ig(2));
    r.Q(k) = 1.5*(vg(2)*ig(1) - vg(1)*ig(2));
    r.is(k,:) = is';  r.isr(k,:) = isr';  r.ig(k,:) = ig';  r.igr(k,:) = igr';
    r.uAI(k,:) = uAI';
  end

  % ===================== INSTALLATION (RK4 sur Ts) =========================
  k1 = modele_chaine(x,           u, v, vg, Pv);
  k2 = modele_chaine(x + Ts/2*k1, u, v, vg, Pv);
  k3 = modele_chaine(x + Ts/2*k2, u, v, vg, Pv);
  k4 = modele_chaine(x + Ts*k3,   u, v, vg, Pv);
  x  = x + Ts/6*(k1 + 2*k2 + 2*k3 + k4);
end
end

function dx = modele_chaine(x, u, v, vg, P)
%MODELE_CHAINE  Modèle moyen de la chaîne complète.
%  x = [isd isq Ω Vdc igd igq],  u = [vsd vsq vid viq] (tensions des convertisseurs)
isd = x(1);  isq = x(2);  w = x(3);  Vdc = x(4);  igd = x(5);  igq = x(6);
we  = P.p*w;
% Turbine + arbre :  J dΩ/dt = Tw − Te − BΩ
Tw  = couple_eolien(w, v, P);
Te  = 1.5*P.p*P.psi*isq;
dw  = (Tw - Te - P.B*w)/P.J;
% PMSG (convention générateur, repère dq) :  Ls dis/dt = −Rs is + ωe Ls J is + ωe ψ e_q − vs
disd = (-P.Rs*isd + we*P.Ls*isq - u(1))/P.Ls;
disq = (-P.Rs*isq - we*P.Ls*isd + we*P.psi - u(2))/P.Ls;
% Bus DC (convertisseurs sans pertes) :  C Vdc dVdc/dt = P_msc − P_gsc
Pmsc = 1.5*(u(1)*isd + u(2)*isq);
Pgsc = 1.5*(u(3)*igd + u(4)*igq);
dVdc = (Pmsc - Pgsc)/(P.C*Vdc);
% Filtre L + réseau :  Lf dig/dt = −Rf ig + ωg Lf J ig + vi − vg
digd = (-P.Rf*igd + P.wg*P.Lf*igq + u(3) - vg(1))/P.Lf;
digq = (-P.Rf*igq - P.wg*P.Lf*igd + u(4) - vg(2))/P.Lf;
dx = [disd; disq; dw; dVdc; digd; digq];
end

function Tw = couple_eolien(w, v, P)
%COUPLE_EOLIEN  Tw = ½ ρ π R² Cp(λ, β) v³ / Ω,   λ = Ω R / v
lam = w*P.R/max(v, 0.1);
Tw  = 0.5*P.rho*pi*P.R^2*coefficient_Cp(lam, P.beta)*v^3/max(w, 0.05);
end

function Cp = coefficient_Cp(lam, beta)
%COEFFICIENT_CP  Modèle de Heier : Cp,max = 0,48 pour λ = 8,1 et β = 0.
li = 1/(1/(lam + 0.08*beta) - 0.035/(beta^3 + 1));
Cp = max(0.5176*(116/li - 0.4*beta - 5)*exp(-21/li) + 0.0068*lam, 0);
end

function v = profil_vent(t)
%PROFIL_VENT  Vent turbulent, même forme que l'équation (80) de [2] :
%     v(t) = Vmoy + Σ_k A_k·sin(2π·f_k·t) + v_turb(t),   Vmoy = 8 m/s
%  A_k et f_k sont identifiés sur la figure 3 de [2] (non donnés dans le texte) :
%     A = [1,5 0,2 0,3] m/s,  f = [0,03 0,16 0,17] Hz   (écart à la courbe : 0,02 m/s)
%  v_turb : bruit gaussien lissé (écart type 0,01 m/s, constante de temps 0,05 s),
%  reproductible (générateur fixe, identique d'une exécution à l'autre).
persistent vt dt
if isempty(vt)
  dt = 1e-3;  N = 20001;  tau = 0.05;  sig = 0.01;
  graine = 12345;  u = zeros(N, 2);
  for k = 1:2*N                                   % générateur de Park-Miller
    graine = mod(16807*graine, 2147483647);  u(k) = graine/2147483647;
  end
  w = sqrt(-2*log(u(:,1))).*cos(2*pi*u(:,2));    % Box-Muller → loi normale
  a = exp(-dt/tau);  vt = zeros(N, 1);
  for k = 2:N, vt(k) = a*vt(k-1) + (1 - a)*w(k); end   % lissage (1er ordre)
  vt = sig*vt/std(vt);
end
A = [1.5 0.2 0.3];  f = [0.03 0.16 0.17];
s = mod(t, (numel(vt) - 1)*dt)/dt;  k = floor(s);  a = s - k;   % interpolation
v = 8 + A*sin(2*pi*f'*t) + (1 - a)*vt(k + 1) + a*vt(k + 2);
end

function vg = tension_reseau(t, robuste, P)
%TENSION_RESEAU  Repère dq orienté sur la tension du réseau (vgd = Vm, vgq = 0).
%  En robustesse : creux de 20 % entre 8 s et 8,2 s.
k = 1;
if robuste && t >= 8 && t < 8.2, k = 0.8; end
vg = [k*P.Vgm; 0];
end

function nn = ann_init(nin, nh, nout, A)
%ANN_INIT  Réseau nin-nh-nout. W1, b1 : petite initialisation déterministe ;
%  W2 = 0, b2 = 0 pour que la compensation soit nulle au départ.
nn.W1 = 0.5*sin((1:nh)'*(1:nin)*0.7 + 0.3);
nn.b1 = 0.1*cos((1:nh)'*1.3);
nn.W2 = zeros(nout, nh);
nn.b2 = zeros(nout, 1);
nn.A  = A;
nn.on = true;
end

function [y, nn] = ann_pas(nn, zn, e, Ts, apprendre)
%ANN_PAS  Un pas de l'ANN adaptatif (équations (52)-(68) de [2]).
A = nn.A;
if ~nn.on, y = zeros(size(nn.b2)); return; end
h = tanh(nn.W1*zn + nn.b1);                          % couche cachée
y = A.KAI*min(max(nn.W2*h + nn.b2, -A.ysat), A.ysat); % sortie saturée
if ~apprendre, return; end                           % pas d'adaptation si saturation
r  = e*(norm(e) > A.delta);                          % signal d'apprentissage + zone morte
dh = (1 - h.^2).*(nn.W2'*r);                         % rétropropagation
nn.W2 = nn.W2 + Ts*(-A.Gamma*r*h'   - A.sigma*nn.W2);
nn.b2 = nn.b2 + Ts*(-A.Gamma*r      - A.sigma*nn.b2);
nn.W1 = nn.W1 + Ts*(-A.Gamma*dh*zn' - A.sigma*nn.W1);
nn.b1 = nn.b1 + Ts*(-A.Gamma*dh     - A.sigma*nn.b1);
end

function y = saturer(x, lo, hi)
y = min(max(x, lo), hi);
end

function v = saturer_vecteur(v, vmax)
%SATURER_VECTEUR  Limite l'amplitude d'un vecteur dq (zone linéaire de la MLI).
m = norm(v);
if m > vmax, v = v*(vmax/m); end
end
