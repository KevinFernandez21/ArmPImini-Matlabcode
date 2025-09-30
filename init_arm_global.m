function init_arm_global()
% Inicializar brazo robótico como variable global para Simulink

global ARM_CONTROLLER;

% Configuración
RASPBERRY_IP = '192.168.149.1';  % ⚠️ CAMBIAR
PORT = 5000;

try
    % Crear el objeto ArmPiController (usa tu clase existente)
    ARM_CONTROLLER = ArmPiController(RASPBERRY_IP, PORT);
    
    fprintf('✓ Brazo inicializado para Simulink\n');
    
catch e
    error('Error al inicializar: %s', e.message);
end

end