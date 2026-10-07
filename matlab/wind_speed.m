function v = wind_speed(t)
%WIND_SPEED  Test wind profile (below rated): smoothed steps + turbulence.
s = @(t0, tr) 0.5*(1 + tanh((t - t0)/tr));   % smooth step
v = 8 + 2*s(1, 0.15) + 1*s(4, 0.15) - 2*s(7, 0.15) ...
    + 0.15*sin(2*pi*0.7*t) + 0.08*sin(2*pi*2.3*t);
end
