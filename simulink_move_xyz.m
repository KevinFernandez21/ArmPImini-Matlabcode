function success = simulink_move_xyz(x, y, z, duration)
% Wrapper para usar moveXYZ desde Simulink

global ARM_CONTROLLER;

if isempty(ARM_CONTROLLER)
    warning('Ejecuta primero: init_arm_global()');
    success = 0;
    return;
end

if ~ARM_CONTROLLER.isValid()
    warning('Conexión perdida');
    success = 0;
    return;
end

try
    [success_result, ~] = ARM_CONTROLLER.moveXYZ(x, y, z, duration);
    success = double(success_result);
catch e
    warning('Error: %s', e.message);
    success = 0;
end

end