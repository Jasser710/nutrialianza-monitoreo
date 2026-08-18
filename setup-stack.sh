#!/bin/bash
# ============================================================
#  NutriAlianza S.A. — Generador del stack de monitoreo
#  Ejecutar desde ~/nutrialianza-monitoreo
# ============================================================
set -e
cd ~/nutrialianza-monitoreo

mkdir -p nginx/conf.d mysql/init mysql/conf prometheus filebeat \
         logstash/pipeline loki n8n grafana/provisioning/datasources \
         docs/evidencias hardening

# ------------------------------------------------------------
# 1. Variables de entorno
# ------------------------------------------------------------
cat > .env << 'EOF'
MYSQL_ROOT_PASSWORD=NutriRoot2026!
MYSQL_DATABASE=nutrialianza_db
MYSQL_USER=nutriapp
MYSQL_PASSWORD=NutriApp2026!
N8N_USER=admin
N8N_PASSWORD=NutriN8N2026!
GRAFANA_USER=admin
GRAFANA_PASSWORD=NutriGrafana2026!
TELEGRAM_BOT_TOKEN=PONER_TOKEN_AQUI
TELEGRAM_CHAT_ID=PONER_CHAT_ID_AQUI
GROQ_API_KEY=PONER_API_KEY_AQUI
EOF

sed -e 's/=.*/=CAMBIAR/' .env > .env.example
cat > .env.example << 'EOF'
# Plantilla de variables de entorno — NutriAlianza S.A.
# Copiar a .env y completar con valores reales

# --- Base de datos MySQL ---
MYSQL_ROOT_PASSWORD=          # Contraseña del usuario root de MySQL
MYSQL_DATABASE=nutrialianza_db
MYSQL_USER=nutriapp           # Usuario de aplicación
MYSQL_PASSWORD=               # Contraseña del usuario de aplicación

# --- N8N (automatización) ---
N8N_USER=admin                # Usuario de acceso a la interfaz web
N8N_PASSWORD=                 # Contraseña de acceso

# --- Grafana (visualización) ---
GRAFANA_USER=admin
GRAFANA_PASSWORD=

# --- Telegram (canal de alertas) ---
TELEGRAM_BOT_TOKEN=           # Token entregado por @BotFather
TELEGRAM_CHAT_ID=             # ID del canal o grupo destino

# --- Groq (motor de inferencia IA) ---
GROQ_API_KEY=                 # Clave de https://console.groq.com
EOF

printf '.env\ndata/\n*.log\ndocs/evidencias/*.png\n' > .gitignore

# ------------------------------------------------------------
# 2. Nginx — formato de log combinado (requisito del documento)
# ------------------------------------------------------------
cat > nginx/conf.d/default.conf << 'EOF'
log_format combined_ext '$remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        'rt=$request_time';

server {
    listen 80;
    server_name nutrialianza.local;

    access_log /var/log/nginx/access.log combined_ext;
    error_log  /var/log/nginx/error.log warn;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    # Endpoint de salud para el monitoreo HTTP
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # Endpoint que genera latencia, para pruebas de saturación
    location /slow {
        return 200 "slow endpoint\n";
        add_header Content-Type text/plain;
    }
}
EOF

cat > nginx/conf.d/index.html << 'EOF'
<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"><title>NutriAlianza S.A.</title></head>
<body style="font-family:sans-serif;max-width:640px;margin:60px auto">
<h1>NutriAlianza S.A.</h1>
<p>Portal corporativo — Sistema de nutrición animal</p>
<p>Servidor monitoreado por el stack de observabilidad inteligente.</p>
</body></html>
EOF

# ------------------------------------------------------------
# 3. MySQL — slow query log activo (requisito del documento)
# ------------------------------------------------------------
cat > mysql/conf/custom.cnf << 'EOF'
[mysqld]
slow_query_log       = 1
slow_query_log_file  = /var/log/mysql/slow.log
long_query_time      = 2
log_queries_not_using_indexes = 1
general_log          = 0
max_connections      = 150
innodb_buffer_pool_size = 256M
EOF

# ------------------------------------------------------------
# 4. Esquema y datos — 335,000 registros
# ------------------------------------------------------------
cat > mysql/init/01-schema.sql << 'EOF'
USE nutrialianza_db;

CREATE TABLE clientes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  cedula_juridica VARCHAR(20),
  provincia VARCHAR(40),
  tipo_cliente ENUM('finca','distribuidor','cooperativa','minorista'),
  fecha_registro DATE,
  activo TINYINT(1) DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(24) NOT NULL,
  descripcion VARCHAR(160),
  categoria ENUM('concentrado','suplemento','minerales','forraje','medicado'),
  presentacion_kg DECIMAL(6,2),
  precio_unitario DECIMAL(10,2),
  stock INT
) ENGINE=InnoDB;

CREATE TABLE pedidos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id INT,
  fecha_pedido DATETIME,
  estado ENUM('pendiente','procesado','despachado','entregado','anulado'),
  total DECIMAL(12,2),
  canal ENUM('web','telefono','vendedor','app'),
  INDEX idx_cliente (cliente_id),
  INDEX idx_fecha (fecha_pedido)
) ENGINE=InnoDB;

CREATE TABLE detalle_pedidos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT,
  producto_id INT,
  cantidad INT,
  precio_linea DECIMAL(10,2),
  descuento DECIMAL(5,2) DEFAULT 0,
  INDEX idx_pedido (pedido_id)
) ENGINE=InnoDB;

-- Tabla auxiliar de numeración para generación masiva
CREATE TABLE seq (n INT PRIMARY KEY);
INSERT INTO seq (n)
SELECT (a.d + b.d*10 + c.d*100 + d.d*1000 + e.d*10000 + f.d*100000) + 1 AS n
FROM (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
     (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b,
     (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c,
     (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) d,
     (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) e,
     (SELECT 0 d UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) f
LIMIT 400000;

-- 5,000 clientes
INSERT INTO clientes (nombre, cedula_juridica, provincia, tipo_cliente, fecha_registro, activo)
SELECT CONCAT('Cliente ', LPAD(n,5,'0')),
       CONCAT('3-101-', LPAD(n,6,'0')),
       ELT(1+(n%7),'San Jose','Alajuela','Cartago','Heredia','Guanacaste','Puntarenas','Limon'),
       ELT(1+(n%4),'finca','distribuidor','cooperativa','minorista'),
       DATE_SUB(CURDATE(), INTERVAL (n%2000) DAY),
       IF(n%13=0,0,1)
FROM seq WHERE n <= 5000;

-- 1,000 productos
INSERT INTO productos (codigo, descripcion, categoria, presentacion_kg, precio_unitario, stock)
SELECT CONCAT('NA-', LPAD(n,5,'0')),
       CONCAT('Producto nutricional linea ', 1+(n%12)),
       ELT(1+(n%5),'concentrado','suplemento','minerales','forraje','medicado'),
       ELT(1+(n%4), 25.00, 40.00, 50.00, 1000.00),
       ROUND(4000 + (n%9000) + RAND()*500, 2),
       (n*37)%5000
FROM seq WHERE n <= 1000;

-- 79,000 pedidos
INSERT INTO pedidos (cliente_id, fecha_pedido, estado, total, canal)
SELECT 1+(n%5000),
       DATE_SUB(NOW(), INTERVAL (n%730) DAY),
       ELT(1+(n%5),'pendiente','procesado','despachado','entregado','anulado'),
       ROUND(15000 + (n%800000)/10, 2),
       ELT(1+(n%4),'web','telefono','vendedor','app')
FROM seq WHERE n <= 79000;

-- 250,000 lineas de detalle
INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_linea, descuento)
SELECT 1+(n%79000), 1+(n%1000), 1+(n%40),
       ROUND(4000 + (n%9000), 2),
       ROUND((n%15), 2)
FROM seq WHERE n <= 250000;

DROP TABLE seq;

-- Usuario de solo lectura para monitoreo
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'NutriMonitor2026!';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitor'@'%';
FLUSH PRIVILEGES;

SELECT 'clientes' t, COUNT(*) c FROM clientes
UNION ALL SELECT 'productos', COUNT(*) FROM productos
UNION ALL SELECT 'pedidos', COUNT(*) FROM pedidos
UNION ALL SELECT 'detalle_pedidos', COUNT(*) FROM detalle_pedidos;
EOF

# ------------------------------------------------------------
# 5. Prometheus
# ------------------------------------------------------------
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    empresa: nutrialianza
    entorno: produccion

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']

  - job_name: node
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          servidor: nutrialianza-srv01

  - job_name: nginx
    metrics_path: /metrics
    static_configs:
      - targets: ['nginx-exporter:9113']
EOF

# ------------------------------------------------------------
# 6. Loki
# ------------------------------------------------------------
cat > loki/loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: false
  allow_structured_metadata: false
EOF

# ------------------------------------------------------------
# 7. Filebeat  (requisito literal del documento)
# ------------------------------------------------------------
cat > filebeat/filebeat.yml << 'EOF'
# Filebeat — Recolector de logs de NutriAlianza S.A.
# Salida hacia Logstash, que reenvia a Loki.
# Nota tecnica: Filebeat no dispone de salida nativa hacia Loki,
# por lo que se emplea Logstash con el plugin logstash-output-loki
# como puente, segun la ruta documentada por Grafana Labs.

filebeat.inputs:
  - type: filestream
    id: nginx-access
    enabled: true
    paths:
      - /var/log/nginx/access.log
    fields:
      log_type: nginx_access
      servicio: nginx
    fields_under_root: true

  - type: filestream
    id: nginx-error
    enabled: true
    paths:
      - /var/log/nginx/error.log
    fields:
      log_type: nginx_error
      servicio: nginx
    fields_under_root: true

  - type: filestream
    id: mysql-slow
    enabled: true
    paths:
      - /var/log/mysql/slow.log
    parsers:
      - multiline:
          type: pattern
          pattern: '^# Time:'
          negate: true
          match: after
    fields:
      log_type: mysql_slow
      servicio: mysql
    fields_under_root: true

  - type: filestream
    id: host-auth
    enabled: true
    paths:
      - /var/log/host/auth.log
    fields:
      log_type: auth
      servicio: ssh
    fields_under_root: true

filebeat.config.modules:
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false

output.logstash:
  hosts: ["logstash:5044"]

logging.level: info
EOF

# ------------------------------------------------------------
# 8. Logstash — puente hacia Loki
# ------------------------------------------------------------
cat > logstash/pipeline/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
}

filter {
  mutate {
    remove_field => ["@version", "agent", "ecs", "input", "host"]
  }
}

output {
  loki {
    url => "http://loki:3100/loki/api/v1/push"
    include_fields => ["log_type", "servicio"]
  }
}
EOF

# ------------------------------------------------------------
# 9. Grafana — fuentes de datos automaticas
# ------------------------------------------------------------
cat > grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
EOF

# ------------------------------------------------------------
# 10. docker-compose.yml
# ------------------------------------------------------------
cat > docker-compose.yml << 'EOF'
# ============================================================
#  NutriAlianza S.A. — Stack de monitoreo inteligente
#  Sintaxis compatible con Docker Compose v2 y superiores
# ============================================================

services:

  # ---------- Capa de servicios monitoreados ----------
  nginx:
    image: nginx:1.27-alpine
    container_name: na-nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/conf.d/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./nginx/conf.d/index.html:/usr/share/nginx/html/index.html:ro
      - nginx_logs:/var/log/nginx
    networks:
      - na-net

  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:1.3.0
    container_name: na-nginx-exporter
    restart: unless-stopped
    command:
      - --nginx.scrape-uri=http://nginx:80/health
    depends_on:
      - nginx
    networks:
      - na-net

  mysql:
    image: mysql:8.0
    container_name: na-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "127.0.0.1:3306:3306"
    volumes:
      - ./mysql/init:/docker-entrypoint-initdb.d:ro
      - ./mysql/conf/custom.cnf:/etc/mysql/conf.d/custom.cnf:ro
      - mysql_data:/var/lib/mysql
      - mysql_logs:/var/log/mysql
    networks:
      - na-net

  # ---------- Capa de metricas ----------
  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: na-node-exporter
    restart: unless-stopped
    pid: host
    command:
      - --path.rootfs=/host
      - --collector.systemd
    volumes:
      - /:/host:ro,rslave
    networks:
      - na-net

  prometheus:
    image: prom/prometheus:v2.54.1
    container_name: na-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - na-net

  # ---------- Capa de logs ----------
  loki:
    image: grafana/loki:2.9.8
    container_name: na-loki
    restart: unless-stopped
    command: -config.file=/etc/loki/loki-config.yml
    volumes:
      - ./loki/loki-config.yml:/etc/loki/loki-config.yml:ro
      - loki_data:/loki
    networks:
      - na-net

  logstash:
    image: grafana/logstash-output-loki:main
    container_name: na-logstash
    restart: unless-stopped
    environment:
      LS_JAVA_OPTS: "-Xms256m -Xmx256m"
      XPACK_MONITORING_ENABLED: "false"
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    depends_on:
      - loki
    networks:
      - na-net

  filebeat:
    image: docker.elastic.co/beats/filebeat:8.15.0
    container_name: na-filebeat
    restart: unless-stopped
    user: root
    command: filebeat -e --strict.perms=false
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - nginx_logs:/var/log/nginx:ro
      - mysql_logs:/var/log/mysql:ro
      - /var/log/auth.log:/var/log/host/auth.log:ro
      - filebeat_data:/usr/share/filebeat/data
    depends_on:
      - logstash
    networks:
      - na-net

  # ---------- Capa de automatizacion e IA ----------
  n8n:
    image: n8nio/n8n:latest
    container_name: na-n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_BASIC_AUTH_USER: ${N8N_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_PASSWORD}
      GENERIC_TIMEZONE: America/Costa_Rica
      TZ: America/Costa_Rica
      N8N_SECURE_COOKIE: "false"
      N8N_RUNNERS_ENABLED: "true"
    volumes:
      - n8n_data:/home/node/.n8n
      - ./n8n:/backup
    networks:
      - na-net

  # ---------- Capa de visualizacion (Nivel Avanzado) ----------
  grafana:
    image: grafana/grafana:11.2.0
    container_name: na-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: ${GRAFANA_USER}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
      - loki
    networks:
      - na-net

networks:
  na-net:
    driver: bridge

volumes:
  nginx_logs:
  mysql_data:
  mysql_logs:
  prometheus_data:
  loki_data:
  filebeat_data:
  n8n_data:
  grafana_data:
EOF

echo ""
echo "=========================================="
echo " Archivos generados correctamente."
echo "=========================================="
echo ""
echo " SIGUIENTE PASO:"
echo "   nano .env      -> completar TELEGRAM_BOT_TOKEN,"
echo "                     TELEGRAM_CHAT_ID y GROQ_API_KEY"
echo "   docker compose up -d"
echo ""
