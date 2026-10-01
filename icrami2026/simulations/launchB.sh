cd "$(dirname "$0")"
for c in mpc fl pi; do for s in nom m1 m2; do nohup python3 runB.py $c $s > B_${c}_${s}.log 2>&1 & done; done
