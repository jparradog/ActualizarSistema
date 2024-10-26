# Copyright 2024 John Parrado
# japarradog@gmail.com
#
# Licenciado bajo la Licencia Apache, Versión 2.0 (la "Licencia");
# no puedes usar este archivo excepto en cumplimiento con la Licencia.
# Puedes obtener una copia de la Licencia en:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# A menos que lo exija la ley aplicable o se acuerde por escrito, el software
# distribuido bajo la Licencia se distribuye "TAL CUAL",
# SIN GARANTÍAS NI CONDICIONES DE NINGÚN TIPO, ya sean expresas o implícitas.
# Consulta la Licencia para el idioma específico que rige los permisos y
# limitaciones bajo la Licencia.



# ActualizarSistema.ps1
# Script para gestionar actualizaciones de Windows y aplicaciones en Windows 11
# Guarda y restaura las políticas necesarias para ejecutar el script
# Configura Windows Update según tus requerimientos

# Parámetros del script
param(
    [Parameter(Mandatory = $false)]
    [string]$BackupDir = "C:\ActualizarSistemaBackup",
    [Parameter(Mandatory = $false)]
    [switch]$Desatendido
)

# Ajustar la codificación para evitar caracteres extraños
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

chcp 65001




# Verificar si el script se está ejecutando como administrador
function Verificar-Privilegios {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Output "Este script requiere privilegios administrativos. Solicitando permisos elevados..."
        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# Crear un punto de restauración del sistema
function Crear-PuntoRestauracion {
    Write-Output "Creando punto de restauración del sistema... Esto puede tomar varios minutos."
    try {
        # Verificar si la protección del sistema está habilitada
        $restorationEnabled = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
        if (-not $restorationEnabled) {
            throw "No se pueden crear puntos de restauración porque la protección del sistema no está habilitada en la unidad del sistema."
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Checkpoint-Computer -Description "Antes de ejecutar ActualizarSistema.ps1 - $timestamp" -RestorePointType "MODIFY_SETTINGS"
        Write-Output "Punto de restauración creado exitosamente."
        Registrar-Evento -Mensaje "Punto de restauración creado exitosamente." -Tipo "Information"
    }
    catch {
        Write-Error "[Crear-PuntoRestauracion] Error al crear el punto de restauración: $_"
        Registrar-Evento -Mensaje "[Crear-PuntoRestauracion] Error al crear el punto de restauración: $_" -Tipo "Error"
        Write-Output "Error al crear el punto de restauración. Asegúrese de tener permisos adecuados y suficiente espacio en el disco."
    }
}


# Guardar y ajustar las políticas necesarias para ejecutar el script
function Guardar-ConfiguracionOriginal {
    param([ref]$originalExecutionPolicy)

    Write-Output "Guardando la configuración de la política de ejecución actual..."
    try {
        # Obtener la política de ejecución actual
        $originalPolicy = Get-ExecutionPolicy -Scope CurrentUser
        $originalExecutionPolicy.Value = $originalPolicy

        # Ajustar la política de ejecución si es necesario
        if ($originalPolicy -ne 'RemoteSigned' -and $originalPolicy -ne 'Unrestricted' -and $originalPolicy -ne 'Bypass') {
            Write-Output "La política de ejecución actual es '$originalPolicy'. Se establecerá en 'RemoteSigned' temporalmente."
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
            $policyChanged = $true
        }
        else {
            $policyChanged = $false
            Write-Output "La política de ejecución actual permite la ejecución del script."
        }
    }
    catch {
        Write-Error "[Guardar-ConfiguracionOriginal] Error al obtener o establecer la política de ejecución: $_"
        Registrar-Evento -Mensaje "[Guardar-ConfiguracionOriginal] Error al obtener o establecer la política de ejecución: $_" -Tipo "Error"
        Write-Output "Error al ajustar la política de ejecución. Por favor, revise los permisos de usuario."
    }
    return $policyChanged
}

# Restaurar la política de ejecución original
function Restaurar-ConfiguracionOriginal {
    param($originalExecutionPolicy, $policyChanged)

    if ($policyChanged) {
        Write-Output "Restaurando la política de ejecución original..."
        try {
            Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope CurrentUser -Force
            Write-Output "Política de ejecución restaurada a '$originalExecutionPolicy'."
        }
        catch {
            Write-Error "[Restaurar-ConfiguracionOriginal] Error al restaurar la política de ejecución: $_"
            Registrar-Evento -Mensaje "[Restaurar-ConfiguracionOriginal] Error al restaurar la política de ejecución: $_" -Tipo "Error"
            Write-Output "Error al restaurar la política de ejecución. Intente hacerlo manualmente usando Set-ExecutionPolicy."
        }
    }
    else {
        Write-Output "No es necesario restaurar la política de ejecución."
    }
}

# Respaldar el registro completo y claves específicas antes de modificar Windows Update
function Respaldar-ClavesRegistro {
    param(
        [string]$BackupDir = "C:\ActualizarSistemaBackup"
    )

    Write-Output "Respaldando el registro completo y claves de registro relevantes... Esto puede tomar algunos minutos."
    try {
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir | Out-Null
        }
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

        # Respaldar todo el registro
        $fullBackupPath = "$BackupDir\FullRegistryBackup_$timestamp.reg"
        Write-Output "Respaldando todo el registro en $fullBackupPath..."
        reg export "HKLM" $fullBackupPath /y
        Write-Output "Copia de seguridad completa del registro creada en $fullBackupPath"
        Registrar-Evento -Mensaje "Copia de seguridad completa del registro creada en $fullBackupPath" -Tipo "Information"

        # Respaldar claves de Windows Update
        $specificBackupPath = "$BackupDir\WindowsUpdate_$timestamp.reg"
        Write-Output "Respaldando claves de Windows Update en $specificBackupPath..."
        reg export "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" $specificBackupPath /y
        Write-Output "Copia de seguridad de las claves de registro de Windows Update creada en $specificBackupPath"
        Registrar-Evento -Mensaje "Copia de seguridad de las claves de registro de Windows Update creada en $specificBackupPath" -Tipo "Information"
    }
    catch {
        Write-Error "[Respaldar-ClavesRegistro] Error al respaldar claves de registro: $_"
        Registrar-Evento -Mensaje "[Respaldar-ClavesRegistro] Error al respaldar claves de registro: $_" -Tipo "Error"
        Write-Output "Error al respaldar claves de registro. Revise los permisos de acceso al directorio especificado."
    }
}

# Configurar las políticas de Windows Update según los requisitos
function Configurar-WindowsUpdate {
    Write-Output "Configurando políticas de Windows Update... Esto puede tomar algunos minutos."

    try {
        Respaldar-ClavesRegistro

        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        $auPolicyPath = "$policyPath\AU"
        $driverSearchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"

        # Crear claves de registro necesarias si no existen
        Write-Output "Creando claves de registro si no existen..."
        if (-not (Test-Path -Path $policyPath)) {
            New-Item -Path $policyPath -Force | Out-Null
        }
        if (-not (Test-Path -Path $auPolicyPath)) {
            New-Item -Path $auPolicyPath -Force | Out-Null
        }
        if (-not (Test-Path -Path $driverSearchPolicyPath)) {
            New-Item -Path $driverSearchPolicyPath -Force | Out-Null
        }

        # Configurar opciones de actualización automática
        Write-Output "Configurando opciones de actualización automática..."
        Set-ItemProperty -Path $auPolicyPath -Name "AUOptions" -Value 3 -Type DWord -Force

        # Configurar políticas para posponer actualizaciones de características y calidad
        Write-Output "Configurando políticas para posponer actualizaciones..."
        Set-ItemProperty -Path $policyPath -Name "DeferFeatureUpdates" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $policyPath -Name "DeferFeatureUpdatesPeriodInDays" -Value 90 -Type DWord -Force
        Set-ItemProperty -Path $policyPath -Name "DeferQualityUpdates" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $policyPath -Name "DeferQualityUpdatesPeriodInDays" -Value 90 -Type DWord -Force

        # Configurar la búsqueda automática de controladores
        Write-Output "Configurando búsqueda automática de controladores..."
        Set-ItemProperty -Path $driverSearchPolicyPath -Name "SearchOrderConfig" -Value 5 -Type DWord -Force
        Write-Output "Política de búsqueda automática de controladores configurada para estar siempre activa y buscar en Windows Update."
        Registrar-Evento -Mensaje "Política de búsqueda automática de controladores configurada correctamente." -Tipo "Information"

        Write-Output "Políticas de Windows Update configuradas correctamente."
        Registrar-Evento -Mensaje "Políticas de Windows Update configuradas correctamente." -Tipo "Information"
    }
    catch {
        Write-Error "[Configurar-WindowsUpdate] Error al configurar Windows Update: $_"
        Registrar-Evento -Mensaje "[Configurar-WindowsUpdate] Error al configurar Windows Update: $_" -Tipo "Error"
        Write-Output "Error al configurar las políticas de Windows Update. Asegúrese de tener los permisos necesarios para modificar el registro."
        throw $_
    }
}

# Actualizar aplicaciones usando Winget
function Actualizar-Aplicaciones {
    Write-Output "Actualizando aplicaciones con Winget... Esto puede tomar un tiempo considerable dependiendo del número de aplicaciones a actualizar."

    try {
        # Verificar si Winget está instalado
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            Write-Warning "Winget no está instalado. Por favor, instálelo antes de continuar."
            Registrar-Evento -Mensaje "Winget no está instalado." -Tipo "Warning"
            return
        }

        # Verificar si Winget está actualizado
        $wingetVersion = (winget --info | Select-String 'Windows Package Manager v' | ForEach-Object { ($_ -split 'v')[1] }).Trim()
        if ([version]$wingetVersion -lt [version]"1.0.0") {
            Write-Output "Winget está desactualizado. Actualizando Winget..."
            winget upgrade --id Microsoft.Winget.Source --silent
            if ($LASTEXITCODE -ne 0) {
                Write-Error "[Actualizar-Aplicaciones] Error al actualizar Winget."
                Registrar-Evento -Mensaje "[Actualizar-Aplicaciones] Error al actualizar Winget." -Tipo "Error"
                return
            }
        }

        # Verificar actualizaciones disponibles
        Write-Output "Verificando actualizaciones disponibles para aplicaciones..."
        $updatesAvailable = winget upgrade
        if ($updatesAvailable) {
            Write-Output "Actualizando todas las aplicaciones disponibles... Esto puede tomar un tiempo considerable."
            winget upgrade --all --silent
            if ($LASTEXITCODE -eq 0) {
                Write-Output "Actualización de aplicaciones completada."
                Registrar-Evento -Mensaje "Actualización de aplicaciones completada." -Tipo "Information"
            }
            else {
                Write-Error "[Actualizar-Aplicaciones] Error al actualizar aplicaciones con Winget."
                Registrar-Evento -Mensaje "[Actualizar-Aplicaciones] Error al actualizar aplicaciones con Winget." -Tipo "Error"
            }
        }
        else {
            Write-Output "No hay actualizaciones disponibles para las aplicaciones."
        }
    }
    catch {
        Write-Error "[Actualizar-Aplicaciones] Error al actualizar aplicaciones: $_"
        Registrar-Evento -Mensaje "[Actualizar-Aplicaciones] Error al actualizar aplicaciones: $_" -Tipo "Error"
        Write-Output "Error al actualizar aplicaciones. Revise la conexión a Internet y los permisos de ejecución."
    }
}

# Verificar si hay reinicios pendientes
function Verificar-ReinicioPendiente {
    Write-Output "Verificando si hay un reinicio pendiente en el sistema... Esto puede tomar unos momentos."
    $rebootRequired = $false

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
    )

    foreach ($path in $paths) {
        try {
            if (Test-Path $path) {
                $rebootRequired = $true
                break
            }
        }
        catch {
            Write-Warning "[Verificar-ReinicioPendiente] Ruta de reinicio pendiente no encontrada: $path"
        }
    }

    if ($rebootRequired) {
        Write-Warning "Hay un reinicio pendiente en el sistema. Algunas actualizaciones no se aplicarán hasta que se reinicie."
        Registrar-Evento -Mensaje "Reinicio pendiente detectado." -Tipo "Warning"

        do {
            $respuesta = Read-Host "¿Desea reiniciar el sistema ahora? (S/N)"
            if ($respuesta -match '^[SsNn]$') {
                if ($respuesta -match '^[Ss]$') {
                    Write-Output "Reiniciando el sistema..."
                    Restart-Computer -Force
                    exit
                }
                else {
                    Write-Output "Continuando sin reiniciar. Es posible que ocurran problemas hasta que se complete el reinicio."
                    break
                }
            }
            else {
                Write-Warning "Opción no válida. Por favor, ingrese 'S' para sí o 'N' para no."
            }
        } while ($true)
    }
    else {
        Write-Output "No hay reinicios pendientes. Puede continuar con las operaciones."
    }
}

# Registrar eventos en el Visor de eventos
function Registrar-Evento {
    param(
        [string]$Mensaje,
        [ValidateSet("Information", "Warning", "Error")]
        [string]$Tipo = "Information"
    )

    try {
        $source = "ActualizarSistemaScript"

        # Crear la fuente del evento si no existe
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            [System.Diagnostics.EventLog]::CreateEventSource($source, "Application")
        }

        # Determinar el tipo de entrada del evento
        $entryType = [System.Diagnostics.EventLogEntryType]::$Tipo

        # Escribir el evento en el Visor de eventos
        Write-EventLog -LogName "Application" -Source $source -EventID 1000 -EntryType $entryType -Message $Mensaje
    }
    catch {
        Write-Error "[Registrar-Evento] Error al registrar el evento: $_"
        Write-Output "Error al registrar el evento. Asegúrese de tener permisos para escribir en el Visor de Eventos."
    }
}

# Iniciar transcripción para el log
function Iniciar-Log {
    param([ref]$logIniciado)

    try {
        $logDir = "C:\ActualizarSistemaBackup\Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir | Out-Null
        }

        $logPath = "$logDir\Actualizacion_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        # Iniciar la transcripción y marcar que se ha iniciado correctamente
        Start-Transcript -Path $logPath -Append
        $logIniciado.Value = $true
        Write-Output "Transcripción iniciada. Log guardado en $logPath"
    }
    catch {
        $logIniciado.Value = $false
        Write-Error "[Iniciar-Log] Error al iniciar el log: $_"
        Write-Output "Error al iniciar la transcripción del log. Asegúrese de tener permisos de escritura en el directorio especificado."
    }
}

# Detener transcripción
function Detener-Log {
    param($logIniciado)

    try {
        # Detener la transcripción solo si se inició correctamente
        if ($logIniciado) {
            Stop-Transcript
            Write-Output "Transcripción detenida."
        }
    }
    catch {
        Write-Error "[Detener-Log] Error al detener el log: $_"
        Write-Output "Error al detener la transcripción del log. Puede que la transcripción no se haya iniciado correctamente."
    }
}

# Mostrar menú interactivo
function Mostrar-Menu {
    Write-Host ""
    Write-Host "============================================"
    Write-Host "          Actualización del Sistema         "
    Write-Host "============================================"
    Write-Host "Seleccione una opción:"
    Write-Host "1. Configurar Windows Update"
    Write-Host "   Configura las políticas de Windows Update para posponer actualizaciones no críticas."
    Write-Host "2. Actualizar aplicaciones con Winget"
    Write-Host "   Actualiza todas las aplicaciones instaladas usando Winget."
    Write-Host "3. Ejecutar todas las tareas (recomendado)"
    Write-Host "   Ejecuta las opciones 1 y 2 en orden."
    Write-Host "4. Salir"
    $opcion = Read-Host "Ingrese el número de la opción"
    return $opcion
}

# Manejo de errores y restauración de políticas
function Ejecutar-Con-Restauracion {
    param(
        [scriptblock]$Accion,
        $originalExecutionPolicy,
        $policyChanged
    )

    try {
        & $Accion
    }
    catch {
        Write-Error "[Ejecutar-Con-Restauracion] Ocurrió un error durante la ejecución: $_"
        Registrar-Evento -Mensaje "[Ejecutar-Con-Restauracion] Error durante la ejecución: $_" -Tipo "Error"
        Write-Output "Error al ejecutar la tarea. Revise los logs para obtener más detalles."
    }
    finally {
        try {
            # Restaurar políticas originales al finalizar
            Restaurar-ConfiguracionOriginal -originalExecutionPolicy $originalExecutionPolicy -policyChanged $policyChanged
        }
        catch {
            Write-Error "[Ejecutar-Con-Restauracion] Error al restaurar configuraciones: $_"
            Registrar-Evento -Mensaje "[Ejecutar-Con-Restauracion] Error al restaurar configuraciones: $_" -Tipo "Error"
            Write-Output "Error al restaurar la configuración original. Se recomienda restaurar manualmente."
        }
    }
}

# Ejecutar script principal
function Ejecutar-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BackupDir,
        [Parameter(Mandatory = $false)]
        [switch]$Desatendido
    )
    Verificar-Privilegios

    $logIniciado = $false
    Iniciar-Log -logIniciado ([ref]$logIniciado)

    # Crear-PuntoRestauracion

    Verificar-ReinicioPendiente

    $originalExecutionPolicy = $null
    $policyChanged = $false
    $policyChanged = Guardar-ConfiguracionOriginal -originalExecutionPolicy ([ref]$originalExecutionPolicy)

    if ($Desatendido.IsPresent) {
        Write-Output "Modo desatendido activado."
        Ejecutar-Con-Restauracion -Accion {
            Configurar-WindowsUpdate
            Actualizar-Aplicaciones
        } -originalExecutionPolicy $originalExecutionPolicy -policyChanged $policyChanged
    }
    else {
        do {
            $opcion = Mostrar-Menu
            Write-Output ""

            # Validación de entrada del usuario
            if ($opcion -match '^[1-4]$') {
                switch ($opcion) {
                    1 {
                        Ejecutar-Con-Restauracion -Accion {
                            Configurar-WindowsUpdate
                        } -originalExecutionPolicy $originalExecutionPolicy -policyChanged $policyChanged
                    }
                    2 {
                        Ejecutar-Con-Restauracion -Accion {
                            Actualizar-Aplicaciones
                        } -originalExecutionPolicy $originalExecutionPolicy -policyChanged $policyChanged
                    }
                    3 {
                        Ejecutar-Con-Restauracion -Accion {
                            Configurar-WindowsUpdate
                            Actualizar-Aplicaciones
                        } -originalExecutionPolicy $originalExecutionPolicy -policyChanged $policyChanged
                    }
                    4 {
                        Write-Output "Saliendo..."
                    }
                }
            }
            else {
                Write-Warning "Opción no válida. Por favor, ingrese un número entre 1 y 4."
            }
        } while ($opcion -ne '4')
    }

    Detener-Log -logIniciado $logIniciado
}

# Iniciar ejecución
Ejecutar-Script -BackupDir $BackupDir
