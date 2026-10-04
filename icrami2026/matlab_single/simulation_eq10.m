% Simulation de l'equation (10) : modele DFIG en boucle ouverte
% avec les parametres du fichier Word (comportement chaotique)
clc; clear; close all;

%% ======================= PARAMETRES =======================
Rs  = 5.0536e-5;     % resistance statorique (Ohm)
Rr  = 1.8781e-4;     % resistance rotorique (Ohm)
Ls  = 0.0833;        % inductance statorique (H)
Lr  = 0.0844;        % inductance rotorique (H)
Lm  = 0.0811;        % inductance mutuelle (H)
ws  = 100*pi;        % pulsation statorique (rad/s)
psi = 1.7933;        % flux statorique (Wb)  (690 V, 50 Hz)
np  = 2;             % paires de poles
J   = 31.18;         % inertie (kg.m^2)
D   = 71.85;         % frottement visqueux (N.m.s/rad)
TL  = -11337;        % couple de charge (N.m)
udr = 2.539;         % tension rotorique d (polarisation) (V)
uqr = -2.936;        % tension rotorique q (polarisation) (V)
uds = -ws*psi;       % tension statorique d (flux oriente sur l'axe q)
uqs = 0;             % tension statorique q

x0   = [0.3; 0.6; 3.6];   % condition initiale
dt   = 1e-3;              % pas RK4 (s)
Tsim = 300;               % duree de simulation (s)
Tlyap = 200;              % duree de moyenne pour les exposants de Lyapunov (s)

%% ======================= COEFFICIENTS (4) =======================
sig = 1 - Lm^2/(Ls*Lr);
a1 = -Rs*Lm^2/(sig*Ls^2*Lr) - Rr/(sig*Lr);
a2 = -Lm*psi/(sig*Lr*Ls);
a3 = -Lm/(sig*Ls*Lr);
a4 = 1/(sig*Lr);
a5 = Rs*Lm*psi/(sig*Ls^2*Lr);
a6 = 3*np^2*Lm*psi/(2*J*Ls);
a7 = D/J;
a8 = np*TL/J;
c1 = a3*uds + a4*udr;
c2 = a5 + a3*uqs + a4*uqr;

fprintf('sigma = %.4f\n', sig);
fprintf('a1 = %.5g  a2 = %.5g  a3 = %.5g  a4 = %.5g\n', a1, a2, a3, a4);
fprintf('a5 = %.5g  a6 = %.5g  a7 = %.5g  a8 = %.5g\n', a5, a6, a7, a8);
fprintf('c1 = %.5g  c2 = %.5g\n\n', c1, c2);

%% ======================= SYSTEME (10) =======================
f = @(x) [ a1*x(1) + (ws - x(3))*x(2) + a2*x(3) + c1;
          -(ws - x(3))*x(1) + a1*x(2) + c2;
           a6*x(1) - a7*x(3) - a8 ];
Jac = @(x) [ a1, ws - x(3), a2 - x(2);
            -(ws - x(3)), a1, x(1);
             a6, 0, -a7 ];

%% ======================= SIMULATION (RK4) =======================
N = round(Tsim/dt);
X = zeros(3, N+1); X(:,1) = x0;
for k = 1:N
    X(:,k+1) = rk4(f, X(:,k), dt);
end
t = (0:N)*dt;

%% ======================= POINTS D'EQUILIBRE =======================
% Pour x3 fixe, les deux premieres equations sont lineaires en (x1, x2) :
%   [a1 w; -w a1][x1; x2] = -[a2*x3 + c1; c2],   w = ws - x3
% En imposant x1 = (a7*x3 + a8)/a6 (3e equation), on obtient un polynome de degre 3 en x3 :
%   a6*( -a1*(a2*x3 + c1) + (ws - x3)*c2 ) - (a7*x3 + a8)*( a1^2 + (ws - x3)^2 ) = 0
P1 = a6*conv([-a1*a2, -a1*c1], 1) + a6*c2*[-1, ws];                % partie lineaire
P2 = conv([a7, a8], [1, -2*ws, ws^2 + a1^2]);                     % partie cubique
x3e = roots([0, 0, P1] - P2);
x3e = real(x3e(abs(imag(x3e)) < 1e-6));
fprintf('Points d''equilibre :\n');
for i = 1:length(x3e)
    w = ws - x3e(i);
    x12 = [a1 w; -w a1] \ (-[a2*x3e(i) + c1; c2]);
    xe = [x12; x3e(i)];
    fprintf('  idr = %9.3f A, iqr = %10.3f A, wr = %8.3f rad/s  | valeurs propres : ', xe);
    fprintf('%s  ', num2str(eig(Jac(xe)).', 4)); fprintf('\n');
end

%% ======================= EXPOSANTS DE LYAPUNOV =======================
fz = @(y) [f(y(1:3)); reshape(Jac(y(1:3))*reshape(y(4:12),3,3), 9, 1)];
y = [X(:,end); reshape(eye(3), 9, 1)]; S = zeros(3,1);
for k = 1:round(Tlyap/dt)
    y = rk4(fz, y, dt);
    if mod(k, 50) == 0
        [Q, R] = qr(reshape(y(4:12),3,3));
        S = S + log(abs(diag(R)));
        y(4:12) = reshape(Q*diag(sign(diag(R))), 9, 1);
    end
end
LE = sort(S/Tlyap, 'descend');
fprintf('\nExposants de Lyapunov : %.4f  %.4f  %.4f\n', LE);
fprintf('Somme = %.4f   trace(J) = 2*a1 - a7 = %.4f\n', sum(LE), 2*a1 - a7);
fprintf('Dimension de Kaplan-Yorke = %.3f\n', 2 + LE(1)/abs(LE(3)));

%% ======================= FIGURES =======================
m = t > 100;                        % on retire le transitoire
figure;
subplot(2,2,1); plot(X(1,m), X(2,m), 'b', 'linewidth', 0.2); grid on
xlabel('x_1 = i_{dr} (A)'); ylabel('x_2 = i_{qr} (A)'); title('(a)')
subplot(2,2,2); plot(X(1,m), X(3,m), 'b', 'linewidth', 0.2); grid on
xlabel('x_1 = i_{dr} (A)'); ylabel('x_3 = \omega_r (rad/s)'); title('(b)')
subplot(2,2,3); plot(X(2,m), X(3,m), 'b', 'linewidth', 0.2); grid on
xlabel('x_2 = i_{qr} (A)'); ylabel('x_3 = \omega_r (rad/s)'); title('(c)')
subplot(2,2,4); plot3(X(1,m), X(2,m), X(3,m), 'b', 'linewidth', 0.2); grid on
xlabel('x_1'); ylabel('x_2'); zlabel('x_3'); title('(d)'); view(-35, 25)

figure;
lab = {'i_{dr} (A)', 'i_{qr} (A)', '\omega_r (rad/s)'};
for i = 1:3
    subplot(3,1,i); plot(t, X(i,:), 'b'); ylabel(lab{i}); grid on
end
hold on; plot([0 Tsim], [ws ws], 'r--'); legend('\omega_r', '\omega_s')
xlabel('time (s)')

%% ======================= FONCTION =======================
function x = rk4(f, x, h)
k1 = f(x); k2 = f(x + h/2*k1); k3 = f(x + h/2*k2); k4 = f(x + h*k3);
x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
end
