% RUN_ALL  Reproduces Table II, Table III and Figs. 1, 2, 4, 5, 6 of the revised paper.
%   Plain MATLAB (no toolbox needed); also runs in GNU Octave.
%   Approximate run time: chaos_analysis 10-30 min, caseB 10 min, caseA 1 min.
caseA_chaos_suppression   % Table II, fig4_matlab.png
caseB_mppt_tracking       % Table III, fig2/5/6_matlab.png
chaos_analysis            % Lyapunov spectrum, Kaplan-Yorke dimension, fig1_matlab.png
