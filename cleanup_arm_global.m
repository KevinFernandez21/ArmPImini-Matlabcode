function cleanup_arm_global()
% Limpiar conexión

global ARM_CONTROLLER;

if ~isempty(ARM_CONTROLLER)
    delete(ARM_CONTROLLER);
    clear global ARM_CONTROLLER;
    fprintf('✓ Limpiado\n');
end

end