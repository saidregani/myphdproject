function P = pmsg_params()
%PMSG_PARAMS  Parameters of the 2 MW direct-drive PMSG wind energy conversion
%system: turbine -> PMSG -> rectifier (MSC) -> DC bus -> inverter (GSC)
%-> L filter -> grid ("back-to-back" converter).
%
%Turbine data follow the supervisor's figures (R = 40 m, w_n = 2.23 rad/s,
%T_n ~ 0.9 MN.m). Generator/converter data are a consistent per-unit design
%(Sb = 2 MVA, 690 V) and should be cross-checked against the reference
%paper that will be cited.

%% Turbine (aerodynamics + drive train)
P.rho    = 1.225;          % air density                    [kg/m^3]
P.R      = 40;             % rotor radius                   [m]
P.lopt   = 8.1;            % optimal tip-speed ratio (beta = 0)
P.beta   = 0;              % pitch angle (fixed, below rated wind) [deg]
P.wn     = 2.23;           % rated mechanical speed         [rad/s]
P.Pn     = 2e6;            % rated power                    [W]
P.Tn     = P.Pn / P.wn;    % rated torque  (~0.9e6 N.m)     [N.m]
P.J      = 2.8e6;          % total inertia (H ~ 3.5 s)      [kg.m^2]
P.B      = 1e3;            % viscous friction               [N.m.s/rad]

%% PMSG (surface mounted, Ld = Lq = Ls), generator convention
P.p      = 30;             % pole pairs
P.Rs     = 0.8e-3;         % stator resistance              [ohm]
P.Ls     = 1.07e-3;        % synchronous inductance (0.3 pu)[H]
P.psi    = 7.57;           % PM flux linkage                [Wb]

%% DC bus
P.C      = 20e-3;          % DC-link capacitance            [F]
P.Vdc_ref= 1200;           % DC-link voltage reference      [V]

%% Grid + L filter (grid-voltage oriented frame, ideal PLL)
P.Vg_ll  = 690;                        % line-line rms        [V]
P.Vgm    = P.Vg_ll*sqrt(2/3);          % phase peak (= v_gd)  [V]
P.fg     = 50;
P.wg     = 2*pi*P.fg;
P.Rf     = 2e-3;           % filter resistance              [ohm]
P.Lf     = 0.2e-3;         % filter inductance              [H]
P.Qref   = 0;              % reactive power reference (unity PF)

%% Limits
P.Imax_s = 1.3 * P.Tn/(1.5*P.p*P.psi);   % MSC current limit (peak) [A]
P.Imax_g = 1.3 * P.Pn/(1.5*P.Vgm);       % GSC current limit (peak) [A]
P.Te_min = 0;                            % no motoring for MPPT
P.Te_max =  1.2*P.Tn;

%% Simulation
P.Ts     = 1e-4;           % control sample time = integration step [s]
P.Tend   = 10;             % [s]
end
