# Sistema de Monitoreo Inteligente — NutriAlianza S.A.

Stack de observabilidad con análisis automatizado mediante inteligencia artificial y notificación por Telegram.

**Curso:** BCD 7212 — Redes de Computadoras
**Universidad:** LEAD University
**Autor:** Jasser (desarrollo individual autorizado)
**Repositorio:** https://github.com/Jasser710/nutrialianza-monitoreo

---

## 1. Descripción

NutriAlianza S.A. es una empresa costarricense de nutrición animal cuya infraestructura digital requiere supervisión continua. Este proyecto implementa un sistema que recolecta métricas y registros del servidor, evalúa umbrales operativos de forma automática, delega el diagnóstico a un modelo de lenguaje y entrega la alerta contextualizada al equipo de operaciones por Telegram.

El flujo completo opera sin intervención humana:

```
Servidor Linux
   ├── Node Exporter ──► Prometheus ──┐
   └── Nginx / MySQL / auth.log       │
          └── Filebeat ──► Logstash ──► Loki ──┐
                                               │
                                    N8N (cada 1 min)
                                               │
                              ¿Umbral superado?
                                               │
                                    Groq (IA) ──► Telegram
```

---

## 2. Arquitectura

### Componentes

| Servicio | Imagen | Función |
|---|---|---|
| nginx | `nginx:1.27-alpine` | Servidor web monitoreado, log en formato combinado |
| nginx-exporter | `nginx/nginx-prometheus-exporter:1.3.0` | Exposición de métricas de Nginx |
| mysql | `mysql:8.0` | Base de datos corporativa con `slow_query_log` activo |
| node-exporter | `prom/node-exporter:v1.8.2` | Métricas del sistema anfitrión |
| prometheus | `prom/prometheus:v2.54.1` | Almacenamiento de series temporales |
| loki | `grafana/loki:2.9.8` | Almacenamiento de registros |
| logstash | `grafana/logstash-output-loki:main` | Puente de Filebeat hacia Loki |
| filebeat | `docker.elastic.co/beats/filebeat:8.15.0` | Recolección de registros |
| n8n | `n8nio/n8n:latest` | Orquestación y lógica de alertado |
| grafana | `grafana/grafana:11.2.0` | Visualización |

### Topología de red

| Interfaz | Subred | Función |
|---|---|---|
| `enp0s3` | 10.0.2.0/24 | NAT — salida a internet |
| `enp0s8` | 192.168.56.0/24 | Host-only — administración y acceso a servicios |
| `na-net` | 172.x.0.0/16 | Red interna entre contenedores |

### Puertos publicados

| Puerto | Servicio |
|---|---|
| 80 | Nginx |
| 3000 | Grafana |
| 5678 | N8N |
| 9090 | Prometheus |
| 127.0.0.1:3306 | MySQL (solo loopback) |

**Puertos deliberadamente no expuestos:** Loki (3100), Node Exporter (9100) y Logstash (5044) son consumidos únicamente desde la red interna de Docker. Su exposición al exterior ampliaría la superficie de ataque sin aportar función alguna.

---

## 3. Requisitos previos

- Ubuntu 22.04 o superior (desarrollado sobre 24.04.4 LTS)
- Docker Engine 24+ y Docker Compose v2+
- 8 GB de RAM asignados (mínimo 6 GB)
- 15 GB de espacio libre en disco
- Cuenta de Telegram y clave de API de Groq (ambas gratuitas)

---

## 4. Instalación

### 4.1 Clonar el repositorio

```bash
git clone https://github.com/Jasser710/nutrialianza-monitoreo.git
cd nutrialianza-monitoreo
```

### 4.2 Configurar variables de entorno

```bash
cp .env.example .env
nano .env
```

Completar todos los campos. Las credenciales de Telegram y Groq se obtienen así:

**Bot de Telegram**
1. Contactar a `@BotFather` en Telegram y enviar `/newbot`
2. Guardar el token entregado
3. Crear un canal, agregar el bot como administrador con permiso de publicación
4. Obtener el identificador del canal desde `https://api.telegram.org/bot<TOKEN>/getUpdates`

**Clave de Groq**
1. Registrarse en https://console.groq.com
2. Sección *API Keys* → *Create API Key*

### 4.3 Levantar el stack

```bash
docker compose up -d
```

El primer arranque descarga aproximadamente 2 GB de imágenes. MySQL requiere entre dos y tres minutos adicionales para generar los 335,000 registros de prueba.

### 4.4 Verificar el despliegue

```bash
# Estado de los contenedores
docker compose ps

# Conteo de registros (debe totalizar 335,000)
docker exec na-mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD nutrialianza_db -e "
SELECT 'clientes' tabla, COUNT(*) registros FROM clientes
UNION ALL SELECT 'productos', COUNT(*) FROM productos
UNION ALL SELECT 'pedidos', COUNT(*) FROM pedidos
UNION ALL SELECT 'detalle_pedidos', COUNT(*) FROM detalle_pedidos;"

# Objetivos de Prometheus
curl -s 'localhost:9090/api/v1/query?query=up' | grep -o '"job":"[^"]*"'

# Etiquetas presentes en Loki
docker exec na-n8n wget -qO- 'http://loki:3100/loki/api/v1/label/log_type/values'
```

### 4.5 Importar el flujo de automatización

1. Acceder a `http://<IP-DEL-SERVIDOR>:5678`
2. Menú superior derecho (⋯) → *Import from File*
3. Seleccionar `n8n/flujo-nutrialianza-v2.json`
4. Abrir el nodo **Configuracion** y completar las tres credenciales
5. Guardar y activar el interruptor **Active**

---

## 5. Accesos

| Servicio | URL | Credenciales |
|---|---|---|
| Portal web | `http://<IP>` | — |
| Prometheus | `http://<IP>:9090` | — |
| N8N | `http://<IP>:5678` | Definidas en `.env` |
| Grafana | `http://<IP>:3000` | Definidas en `.env` |

Las fuentes de datos de Grafana (Prometheus y Loki) se aprovisionan automáticamente al arranque.

---

## 6. Puntos de monitoreo

| # | Condición | Umbral | Estado |
|---|---|---|---|
| 1 | Uso de CPU | > 85 % | Alerta activa |
| 2 | Uso de memoria | > 90 % | Alerta activa |
| 3 | Uso de disco | > 85 % | Alerta activa |
| 4 | Consultas lentas de MySQL | > 10 en 5 min | Alerta activa |
| 5 | Disponibilidad del servicio web | HTTP != 200 o sin respuesta | Alerta activa |
| 6 | Errores HTTP 5xx | > 50 en 5 min | Alerta activa |
| 7 | Intentos SSH fallidos | > 20 en 10 min | Alerta activa + bloqueo por fail2ban |
| 8 | Consumo de ancho de banda | > 80 Mbps | Alerta activa |
| 9 | Latencia de red (ICMP) y resolución DNS | > 200 ms / sin respuesta | No implementado |

**Cobertura: 8 de 9 puntos con alerta activa.**

El punto 9 requiere sondas ICMP y DNS mediante un exportador adicional (blackbox-exporter), no incluido en esta entrega. Los datos de red se recolectan a nivel de interfaz mediante Node Exporter, lo que cubre el consumo de ancho de banda pero no la latencia de extremo a extremo.

### Mecanismos de resiliencia

- **Supresión de alertas repetidas:** ventana de 10 minutos entre notificaciones equivalentes, para evitar fatiga de alertas ante incidentes prolongados.
- **Degradación controlada:** cada nodo de recolección continúa ante error. La indisponibilidad de una fuente de datos no interrumpe la evaluación del resto de los puntos.
- **Sonda directa de disponibilidad:** la verificación HTTP consulta el servicio monitoreado, no su exportador de métricas.

---

## 7. Hardening del servidor

Las medidas aplicadas al sistema anfitrión se documentan en `hardening/`. No se aplican automáticamente al clonar el repositorio: corresponden a la configuración del servidor, no del stack de contenedores.

| Medida | Implementación |
|---|---|
| Usuario sin privilegios | Operación bajo usuario no-root con escalada mediante `sudo` |
| Firewall | UFW con política `deny incoming` y apertura selectiva |
| Bloqueo de fuerza bruta | fail2ban con lectura del journal de systemd |
| Autenticación SSH | Exclusivamente por clave Ed25519; contraseñas deshabilitadas |
| Acceso root remoto | Deshabilitado (`PermitRootLogin no`) |
| Actualizaciones | `unattended-upgrades` activo |

Archivos de referencia:
- `hardening/jail.local` — configuración de fail2ban
- `hardening/sshd_config` — configuración del servicio SSH
- `hardening/ufw-reglas.txt` — reglas de firewall aplicadas

---

## 8. Emulación de escenarios de saturación

Instalación de herramientas:

```bash
sudo apt install -y apache2-utils stress-ng mysql-client
```

| Escenario | Comando |
|---|---|
| Saturación de CPU y memoria | `stress-ng --cpu 6 --vm 2 --vm-bytes 1500M --timeout 300s` |
| Saturación HTTP | `ab -t 180 -c 800 http://<IP>/` |
| Saturación de conexiones MySQL | `mysqlslap --host=127.0.0.1 --user=root --password=<clave> --concurrency=200 --iterations=20 --auto-generate-sql` |
| Interrupción del servicio web | `docker compose stop nginx` |
| Fuerza bruta SSH | Intentos repetidos de autenticación con usuario inexistente |

Las evidencias de cada ejecución se encuentran en `docs/evidencias/`.

---

## 9. Estructura del repositorio

```
nutrialianza-monitoreo/
├── docker-compose.yml
├── .env.example
├── README.md
├── nginx/conf.d/           Configuración del servidor web
├── mysql/
│   ├── conf/               Parámetros de MySQL
│   ├── init/               Esquema y generación de datos
│   └── nutrialianza_db.sql Volcado completo de la base
├── prometheus/             Configuración de recolección
├── filebeat/               Configuración del recolector de logs
├── logstash/pipeline/      Puente hacia Loki
├── loki/                   Configuración de Loki
├── grafana/provisioning/   Fuentes de datos
├── n8n/                    Flujo exportado en JSON
├── hardening/              Configuración de seguridad del anfitrión
└── docs/
    ├── evidencias/         Capturas de las pruebas
    └── notas-tecnicas.md   Registro de incidentes y decisiones
```

---

## 10. Notas técnicas relevantes

**Filebeat y Loki.** Filebeat no dispone de salida nativa hacia Loki. Se emplea Logstash con el plugin `logstash-output-loki` como puente, según la ruta documentada por Grafana Labs.

**Registros de Nginx.** La imagen oficial redirige sus registros a `stdout` mediante enlaces simbólicos, lo que impide su recolección por archivo. Se redefinieron las rutas hacia archivos reales dentro de un volumen compartido.

**Formato de marcas temporales.** Ubuntu 24.04 emplea RFC3339 en `/var/log/auth.log`, incompatible con los patrones de análisis diseñados para el formato tradicional. fail2ban se configuró con `backend = systemd` para leer directamente del journal.

**Disponibilidad del servicio web.** La métrica inicial evaluaba el exporter de Nginx en lugar del servicio. Al detener el servidor web, el exporter continuaba respondiendo y reportaba disponibilidad normal. Se agregó una sonda directa contra el endpoint de salud.

**Escape de contenido generado por IA.** Las respuestas del modelo pueden contener caracteres interpretables como marcado HTML por la API de Telegram. Se aplica escape de entidades antes del envío.

---

## 11. Detención

```bash
docker compose stop      # Detener conservando los datos
docker compose down      # Eliminar contenedores conservando volúmenes
docker compose down -v   # Eliminar todo, incluidos los datos
```
