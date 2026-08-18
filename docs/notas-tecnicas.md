
## Incidente: la sonda de disponibilidad fallaba ante la caída del servicio

El nodo de verificación HTTP interrumpía la ejecución completa del flujo cuando
Nginx dejaba de responder, precisamente en el escenario que debía detectar.
La opción de tolerancia a errores del cliente HTTP cubre códigos de respuesta
anómalos, pero no fallos de conexión a nivel de transporte.

Se configuró el nodo para continuar ante error, delegando la interpretación del
fallo a la lógica de evaluación de umbrales. El caso ilustra que los componentes
de observabilidad deben degradar de forma controlada: la indisponibilidad de una
fuente no puede propagarse como fallo del sistema de monitoreo.

## Incidente: credenciales embebidas en el flujo exportado

Al publicar el repositorio, el mecanismo de protección de GitHub bloqueó el envío
al detectar una clave de API dentro del flujo de N8N exportado. Las credenciales
configuradas mediante nodos quedan serializadas en el JSON, a diferencia de las
gestionadas por variables de entorno.

Se sanitizó el archivo reemplazando los valores por marcadores y se rotaron las
credenciales expuestas. La exportación de flujos de automatización requiere
revisión previa a su versionado.

## Decisión: supresión de alertas repetidas

Con un intervalo de evaluación de un minuto, un incidente sostenido generaría
una notificación por ciclo. Se implementó una ventana de supresión de diez
minutos entre alertas equivalentes, usando almacenamiento estático del flujo.
Sin esta medida, un incidente de treinta minutos produciría treinta
notificaciones idénticas, induciendo fatiga de alertas en el equipo de operación.
