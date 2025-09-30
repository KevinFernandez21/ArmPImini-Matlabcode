classdef ArmPiController < handle
    % Controlador TCP/IP para brazo robótico ArmPi mini
    
    properties
        tcpClient
        ipAddress
        port
        isConnected
    end
    
    properties (Constant)
        % Tipos de comandos
        CMD_MOVE_XYZ = 1
        CMD_MOVE_ANGLES = 2
        CMD_STOP = 3
        CMD_GET_POSITION = 4
        CMD_HOME = 5
    end
    
    methods
        %% CONSTRUCTOR
        function obj = ArmPiController(ip, port)
            % Constructor - Crear conexión con el brazo
            if nargin < 2
                port = 5000;
            end
            
            obj.ipAddress = ip;
            obj.port = port;
            obj.isConnected = false;
            obj.connect();
        end
        
        %% CONECTAR
        function connect(obj)
            % Establecer conexión TCP con la Raspberry Pi
            try
                obj.tcpClient = tcpclient(obj.ipAddress, obj.port, 'Timeout', 5);
                configureCallback(obj.tcpClient, "off");
                obj.isConnected = true;
                fprintf('✓ Conectado a ArmPi en %s:%d\n', obj.ipAddress, obj.port);
            catch e
                error('Error al conectar: %s', e.message);
            end
        end
        
        %% ENVIAR COMANDO (MÉTODO PRINCIPAL)
        function [success, message] = sendCommand(obj, cmdType, data)
            % Enviar comando al brazo y recibir respuesta
            % 
            % Entradas:
            %   cmdType: Tipo de comando (1-5)
            %   data: Array de datos a enviar
            %
            % Salidas:
            %   success: true si el comando fue exitoso
            %   message: Mensaje de respuesta o posición
            
            if ~obj.isConnected
                error('No conectado al brazo robótico');
            end
            
            % Convertir datos a bytes
            dataBytes = typecast(data, 'uint8');
            dataSize = int32(length(dataBytes));
            
            try
                % Enviar: [tipo_comando(1), tamaño(4), datos(N)]
                write(obj.tcpClient, uint8(cmdType), 'uint8');
                write(obj.tcpClient, dataSize, 'int32');
                
                if ~isempty(dataBytes)
                    write(obj.tcpClient, dataBytes, 'uint8');
                end
                
                % Recibir respuesta: [success(1), msg_length(4), message]
                success = read(obj.tcpClient, 1, 'uint8');
                msgLength = read(obj.tcpClient, 1, 'int32');
                
                if msgLength > 0
                    msgBytes = read(obj.tcpClient, double(msgLength), 'uint8');
                    
                    % Intentar convertir a array de doubles (posición)
                    if mod(msgLength, 8) == 0
                        message = typecast(msgBytes, 'double');
                    else
                        % Si no, es string
                        message = char(msgBytes');
                    end
                else
                    message = '';
                end
                
                success = logical(success);
                
            catch e
                success = false;
                message = sprintf('Error de comunicación: %s', e.message);
            end
        end
        
        %% MOVER A POSICIÓN XYZ
        function [success, msg] = moveXYZ(obj, x, y, z, duration)
            % Mover brazo a posición XYZ
            % 
            % Parámetros:
            %   x, y, z: posición en mm
            %   duration: tiempo de movimiento en ms (default: 1500)
            
            if nargin < 5
                duration = 1500;
            end
            
            % Validar límites (según documentación ArmPi)
            if x < -5 || x > 5
                warning('X fuera de rango recomendado [-5, 5]');
            end
            if y < 6 || y > 18
                warning('Y fuera de rango recomendado [6, 18]');
            end
            if z < 13 || z > 18
                warning('Z fuera de rango recomendado [13, 18]');
            end
            
            % ✅ CORRECCIÓN: Preparar datos correctamente
            % Método 1: Convertir todo a bytes y concatenar
            data_doubles = [double(x), double(y), double(z)];
            dataBytes_xyz = typecast(data_doubles, 'uint8');
            dataBytes_duration = typecast(int32(duration), 'uint8');
            
            % Concatenar todos los bytes
            allBytes = [dataBytes_xyz, dataBytes_duration];
            
            % Convertir de vuelta a doubles para sendCommand
            % Rellenar con ceros si es necesario para completar múltiplos de 8
            totalBytes = length(allBytes);
            if mod(totalBytes, 8) ~= 0
                padding = 8 - mod(totalBytes, 8);
                allBytes = [allBytes, zeros(1, padding, 'uint8')];
            end
            
            data = typecast(allBytes, 'double');
            
            fprintf('→ Moviendo a X=%.2f, Y=%.2f, Z=%.2f (%.0fms)\n', x, y, z, duration);
            [success, msg] = obj.sendCommand(obj.CMD_MOVE_XYZ, data);
            
            if success
                fprintf('✓ Movimiento completado\n');
            else
                fprintf('✗ Error: %s\n', msg);
            end
        end
        
        %% MOVER CON CONTROL DE ÁNGULOS
        function [success, msg] = moveWithAngles(obj, x, y, z, alpha, alpha1, alpha2, duration)
            % Mover brazo con control completo de ángulos
            
            if nargin < 8
                duration = 1500;
            end
            
            % Validar rangos
            if alpha < -180 || alpha > 180
                warning('Alpha fuera de rango [-180, 180]');
            end
            if alpha1 < -180 || alpha1 > 0
                warning('Alpha1 fuera de rango [-180, 0]');
            end
            if alpha2 < 0 || alpha2 > 180
                warning('Alpha2 fuera de rango [0, 180]');
            end
            
            % ✅ CORRECCIÓN: Preparar datos como bytes
            angles_data = [double(x), double(y), double(z), ...
                           double(alpha), double(alpha1), double(alpha2)];
            
            angles_bytes = typecast(angles_data, 'uint8');
            dur_bytes = typecast(int32(duration), 'uint8');
            
            data_bytes = [angles_bytes, dur_bytes];
            
            fprintf('→ Moviendo a X=%.2f, Y=%.2f, Z=%.2f\n', x, y, z);
            fprintf('  Ángulos: α=%.1f°, α1=%.1f°, α2=%.1f° (%.0fms)\n', ...
                    alpha, alpha1, alpha2, duration);
            
            % Enviar comando directamente
            if ~obj.isConnected
                error('No conectado al brazo robótico');
            end
            
            try
                write(obj.tcpClient, uint8(obj.CMD_MOVE_ANGLES), 'uint8');
                write(obj.tcpClient, int32(length(data_bytes)), 'int32');
                write(obj.tcpClient, data_bytes, 'uint8');
                
                success = read(obj.tcpClient, 1, 'uint8');
                msgLength = read(obj.tcpClient, 1, 'int32');
                
                if msgLength > 0
                    msgBytes = read(obj.tcpClient, double(msgLength), 'uint8');
                    msg = char(msgBytes');
                else
                    msg = 'OK';
                end
                
                success = logical(success);
                
                if success
                    fprintf('✓ Movimiento completado\n');
                else
                    fprintf('✗ Error: %s\n', msg);
                end
                
            catch e
                success = false;
                msg = sprintf('Error: %s', e.message);
            end
        end
        
        %% DETENER MOVIMIENTO
        function [success, msg] = stop(obj)
            % Detener movimiento inmediatamente
            fprintf('Deteniendo brazo...\n');
            [success, msg] = obj.sendCommand(obj.CMD_STOP, []);
        end
        
        %% OBTENER POSICIÓN ACTUAL
        function [success, position] = getPosition(obj)
            % Obtener posición actual del brazo
            [success, position] = obj.sendCommand(obj.CMD_GET_POSITION, []);
            
            if success && isnumeric(position)
                fprintf('Posición actual: X=%.2f, Y=%.2f, Z=%.2f\n', ...
                        position(1), position(2), position(3));
            end
        end
        
        %% VOLVER A HOME
        function [success, msg] = home(obj)
            % Volver a posición inicial
            fprintf('Volviendo a posición inicial...\n');
            [success, msg] = obj.sendCommand(obj.CMD_HOME, []);
        end
        
        %% EJECUTAR TRAYECTORIA
        function trajectory(obj, points, duration)
            % Ejecutar trayectoria de múltiples puntos
            % 
            % Parámetros:
            %   points: matriz Nx3 donde cada fila es [x, y, z]
            %   duration: tiempo entre puntos en ms (default: 1000)
            
            if nargin < 3
                duration = 1000;
            end
            
            fprintf('Ejecutando trayectoria de %d puntos...\n', size(points, 1));
            
            for i = 1:size(points, 1)
                x = points(i, 1);
                y = points(i, 2);
                z = points(i, 3);
                
                [success, ~] = obj.moveXYZ(x, y, z, duration);
                
                if ~success
                    fprintf('⚠ Error en punto %d, abortando trayectoria\n', i);
                    break;
                end
                
                pause(duration / 1000 + 0.1); % Esperar + margen
            end
            
            fprintf('✓ Trayectoria completada\n');
        end
        
        %% TRAYECTORIA CON ÁNGULOS
        function trajectoryWithAngles(obj, points, angles, duration)
            % Ejecutar trayectoria con control de ángulos
            % 
            % Parámetros:
            %   points: matriz Nx3 [x, y, z]
            %   angles: matriz Nx3 [alpha, alpha1, alpha2]
            %   duration: tiempo entre puntos en ms
            
            if nargin < 4
                duration = 1000;
            end
            
            if size(points, 1) ~= size(angles, 1)
                error('El número de puntos debe coincidir con el número de ángulos');
            end
            
            fprintf('Ejecutando trayectoria con ángulos: %d puntos...\n', size(points, 1));
            
            for i = 1:size(points, 1)
                x = points(i, 1);
                y = points(i, 2);
                z = points(i, 3);
                
                alpha = angles(i, 1);
                alpha1 = angles(i, 2);
                alpha2 = angles(i, 3);
                
                [success, ~] = obj.moveWithAngles(x, y, z, alpha, alpha1, alpha2, duration);
                
                if ~success
                    fprintf('⚠ Error en punto %d, abortando\n', i);
                    break;
                end
                
                pause(duration / 1000 + 0.1);
            end
            
            fprintf('✓ Trayectoria con ángulos completada\n');
        end
        
        %% VERIFICAR CONEXIÓN
        function connected = isValid(obj)
            % Verificar si la conexión sigue activa
            connected = obj.isConnected && isvalid(obj.tcpClient);
        end
        
        %% DESTRUCTOR
        function delete(obj)
            % Destructor - cerrar conexión
            if obj.isConnected
                try
                    obj.home(); % Intentar volver a home
                    pause(1.5);
                catch
                    % Si falla, continuar con el cierre
                end
                clear obj.tcpClient;
                fprintf('✓ Conexión cerrada\n');
            end
        end
    end
end