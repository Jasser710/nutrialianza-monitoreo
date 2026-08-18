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
