cd "$(dirname "$0")"
for cs in A B; do for c in mpc fl pi; do for m in nom M1 M2; do nohup python3 sims.py $cs $c $m > log_${cs}_${c}_${m}.txt 2>&1 & done; done; done
