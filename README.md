# ActualizarSistema

## Descripción del Proyecto

**ActualizarSistema** es un script de PowerShell para Windows 11 que permite realizar cambios, modificaciones y actualizaciones del sistema operativo y aplicaciones. Su principal objetivo es facilitar la configuración de las políticas de Windows Update, realizar respaldos de configuraciones clave del sistema y actualizar aplicaciones mediante **Winget**, todo ello de manera automatizada y segura. El script está diseñado para optimizar el rendimiento del sistema y ofrecer una gestión más eficiente de las actualizaciones y configuraciones críticas.

### Beneficios

- Facilita la configuración de políticas de actualización para evitar interrupciones inesperadas.
- Asegura la realización de copias de seguridad del sistema antes de aplicar cambios.
- Automatiza la actualización de aplicaciones con **Winget** para garantizar la seguridad y eficiencia del software instalado.

## Características Principales

1. **Verificación de Privilegios**: Detecta si el script se ejecuta con permisos administrativos y solicita elevación de permisos si es necesario.
2. **Creación de Puntos de Restauración**: Antes de realizar cambios importantes, se crea un punto de restauración del sistema para asegurar la posibilidad de revertir modificaciones.
3. **Ajuste de Políticas de Windows Update**: Configura las políticas de actualización para evitar que se instalen cambios no deseados.
4. **Actualización de Aplicaciones con Winget**: Utiliza **Winget** para actualizar las aplicaciones instaladas.
5. **Registro de Eventos**: Genera registros en el Visor de Eventos de Windows para monitorear el progreso y posibles errores.
6. **Interfaz Interactiva y Modo Desatendido**: Permite ejecutar el script de manera interactiva o de forma desatendida.

## Requisitos del Sistema

- **Sistema Operativo**: Windows 11
- **Permisos**: Ejecución con privilegios de administrador.
- **PowerShell**: Version 5.0 o superior.
- **Herramientas Adicionales**: **Winget** debe estar instalado y actualizado para la gestión de aplicaciones.

## Instrucciones de Instalación y Uso

1. **Descarga**: Descarga el script `ActualizarSistema.ps1` y gárdalo en una ubicación de tu preferencia.
2. **Preparación del Sistema**: Asegúrate de tener permisos administrativos para ejecutar el script.
3. **Ejecución del Script**:
   - Abre PowerShell como administrador.
   - Navega al directorio donde se encuentra el script.
   - Ejecuta el script con el siguiente comando:

     ```
     .\ActualizarSistema.ps1
     ```

   - Si deseas utilizar el modo desatendido, puedes añadir el parámetro `-Desatendido`:

     ```
     .\ActualizarSistema.ps1 -Desatendido
     ```

4. **Opciones del Menú**: El script te ofrecerá opciones para configurar Windows Update, actualizar aplicaciones o ejecutar todas las tareas recomendadas de manera secuencial.

## Cómo Contribuir

Contribuciones al proyecto son bienvenidas. Si deseas colaborar, por favor sigue los siguientes pasos:

1. **Fork** del repositorio.
2. Crea una nueva rama para tus cambios:

   ```
   git checkout -b nombre-rama
   ```

3. Realiza tus modificaciones y realiza un **commit** con mensajes claros.
4. Envía un **pull request** para revisión.

## Licencia

Este proyecto está licenciado bajo la **Licencia Apache 2.0**. Para más detalles, revisa el archivo de licencia incluído en el repositorio.

## Contacto

Para preguntas, soporte o sugerencias, puedes contactarnos en el siguiente correo electrónico:

- **Correo**: <japarradog@gmail.com>
