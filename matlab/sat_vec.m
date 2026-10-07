function v = sat_vec(v, vmax)
%SAT_VEC  Limit the magnitude of a dq vector (SVPWM linear range).
m = norm(v);
if m > vmax, v = v*(vmax/m); end
end
