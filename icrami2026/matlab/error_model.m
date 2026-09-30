function [A, B] = error_model(Ts)
%ERROR_MODEL Sampled error/integral model of one channel (Eq. 13).
A = [1 0; Ts 1];
B = [Ts; Ts^2/2];
end
