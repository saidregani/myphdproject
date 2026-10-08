function P = pmsg_params()
%PMSG_PARAMS  Parameters of the 2 MW direct-drive PMSG wind energy conversion
%system: turbine -> PMSG -> rectifier (MSC) -> DC bus -> inverter (GSC)
%-> L filter -> grid ("back-to-back" converter).
%
%Turbine data follow the supervisor's figures (R = 40 m, w_n = 2.23 rad/s,
%T_n ~ 0.9 MN.m). PMSG (non-salient case), DC link, grid, filter and PWM
%frequency are taken from:
%  S. M. M. Hasan and A. H. M. Shatil, "Design and Comparison of Grid
%  Connected Permanent Magnet Synchronous Generator Non-salient Pole and
%  Salient Pole Rotor Wind Turbine", AIUB J. Sci. Eng. (AJSE), vol. 20,
%  no. 2, pp. 40-46, 2021 (Table I, Fig. 4a, Fig. 12).
%J, B and Rf are not given there (own assumptions).

%% Turbine (aerodynamics + drive train)
P.kTw    = 1;              % accuracy of the Cp model used by the controller
P.rho    = 1.225;          % air density                    [kg/m^3]
P.R      = 40;             % rotor radius                   [m]
P.lopt   = 8.1;            % optimal tip-speed ratio (beta = 0)
P.beta   = 0;              % pitch angle (fixed, below rated wind) [deg]
P.wn     = 2.23;           % rated mechanical speed         [rad/s]
P.Pn     = 2e6;            % rated power                    [W]
P.Tn     = P.Pn / P.wn;    % rated torque  (~0.9e6 N.m)     [N.m]
P.J      = 2.8e6;          % total inertia (H ~ 3.5 s, assumed) [kg.m^2]
P.B      = 1e3;            % viscous friction               [N.m.s/rad]

%% PMSG (surface mounted, Ld = Lq = Ls), generator convention
P.p      = 26;             % pole pairs                  [AJSE Table I]
P.Rs     = 0.78e-3;        % stator resistance    [ohm]  [AJSE Table I]
P.Ls     = 1.57e-3;        % armature inductance  [H]    [AJSE Table I]
P.psi    = 9.18;           % PM flux linkage      [Wb]   [AJSE Table I]

%% DC bus
P.C      = 20e-3;          % DC-link capacitance  [F]    [AJSE Table I]
P.Vdc_ref= 1200;           % DC-link voltage      [V]    [AJSE Fig. 12]

%% Grid + L filter (grid-voltage oriented frame, ideal PLL)
P.Vg_ll  = 690;                        % line-line rms [V] [AJSE Table I]
P.Vgm    = P.Vg_ll*sqrt(2/3);          % phase peak (= v_gd)  [V]
P.fg     = 50;
P.wg     = 2*pi*P.fg;
P.Rf     = 2e-3;           % filter resistance (assumed)    [ohm]
P.Lf     = 0.15e-3;        % grid-side filter     [H]    [AJSE Fig. 4a]
P.Qref   = 0;              % reactive power reference (unity PF)

%% Limits
P.Imax_s = 1.3 * P.Tn/(1.5*P.p*P.psi);   % MSC current limit (peak) [A]
P.Imax_g = 1.3 * P.Pn/(1.5*P.Vgm);       % GSC current limit (peak) [A]
P.Te_min = 0;                            % no motoring for MPPT
P.Te_max =  1.2*P.Tn;

%% ANN (RBF) online gain tuning
P.ann.ni = 0.05;  P.ann.nw = 0.02;  P.ann.nv = 0.01;   % error normalisation
P.ann.gmax  = 3;                                       % max gain multiplier
P.ann.eta_i = 100; P.ann.sig_i = 5;                    % current loops
P.ann.eta_w = 20;  P.ann.sig_w = 1;                    % speed loop
P.ann.eta_v = 50;  P.ann.sig_v = 3;                    % DC-bus loop
P.ann.eta_tw = 2;  P.ann.sig_tw = 0.01;                % Tw-model error network

%% Grid voltage dip (robust scenario)
P.tsag = 8;  P.dsag = 0.2;  P.ksag = 0.2;   % start [s], duration [s], depth [pu]

%% Simulation
P.Ts     = 1e-4;           % control sample time = integration step [s]
P.Tend   = 10;             % [s]
P.fsw    = 2160;           % PWM carrier frequency [Hz]  [AJSE Sec. IV]
P.hsw    = 1e-6;           % integration step of the switched model [s]
end
