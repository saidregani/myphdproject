#!/usr/bin/env bash
# Reproduces every number and figure of the revised paper (about 1 h on one CPU core).
# Requirements: python3 with numpy, scipy, matplotlib.
set -e
cd "$(dirname "$0")"
python3 lyapunov_spectrum.py                 # Lyapunov spectra quoted in Sec. III-B
python3 bifurcation.py                       # bif.json   (Fig. 1c-d)
python3 caseA.py                             # caseA.json (Table II, Fig. 4)
for c in mpc fl pi; do for s in nom m1 m2; do python3 runB.py $c $s & done; done; wait   # Table III
python3 fig1.py; python3 fig3.py; python3 fig4.py; python3 fig256.py
cd ../paper && pdflatex main.tex && pdflatex main.tex
