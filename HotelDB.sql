//Paso 1. Crear la base
CREATE DATABASE HotelDB;
GO
USE HotelDB;
GO

  //Paso 2. Tablas sin dependencias, luego las que dependen de ellas
CREATE TABLE Rol (id_rol INT IDENTITY PRIMARY KEY, nombre NVARCHAR(30) NOT NULL UNIQUE);
CREATE TABLE Usuario (id_usuario INT IDENTITY PRIMARY KEY, usuario NVARCHAR(30) NOT NULL UNIQUE,
  clave_hash NVARCHAR(200) NOT NULL, id_rol INT NOT NULL REFERENCES Rol(id_rol), activo BIT DEFAULT 1);
CREATE TABLE Cliente (id_cliente INT IDENTITY PRIMARY KEY, nombre NVARCHAR(60) NOT NULL, apellido NVARCHAR(60) NOT NULL,
  tipo_documento CHAR(3) NOT NULL, numero_documento NVARCHAR(25) NOT NULL UNIQUE,
  telefono NVARCHAR(20) NOT NULL, email NVARCHAR(100), pais NVARCHAR(40) DEFAULT 'Guatemala');
CREATE TABLE TipoHabitacion (id_tipo INT IDENTITY PRIMARY KEY, nombre NVARCHAR(30) NOT NULL,
  capacidad TINYINT NOT NULL CHECK (capacidad >= 1), tarifa DECIMAL(10,2) NOT NULL CHECK (tarifa > 0));
CREATE TABLE Habitacion (id_habitacion INT IDENTITY PRIMARY KEY, numero NVARCHAR(5) NOT NULL UNIQUE,
  piso TINYINT CHECK (piso BETWEEN 1 AND 4), id_tipo INT NOT NULL REFERENCES TipoHabitacion(id_tipo),
  estado VARCHAR(15) NOT NULL DEFAULT 'DISPONIBLE'
    CHECK (estado IN ('DISPONIBLE','OCUPADA','LIMPIEZA','MANTENIMIENTO')));
CREATE TABLE Reserva (id_reserva INT IDENTITY PRIMARY KEY, id_cliente INT NOT NULL REFERENCES Cliente(id_cliente),
  id_usuario INT NOT NULL REFERENCES Usuario(id_usuario), fecha_entrada DATE NOT NULL, fecha_salida DATE NOT NULL,
  estado VARCHAR(15) NOT NULL DEFAULT 'CONFIRMADA'
    CHECK (estado IN ('CONFIRMADA','EN_CURSO','FINALIZADA','CANCELADA','NO_SHOW')),
  total DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  CONSTRAINT CK_fechas CHECK (fecha_salida > fecha_entrada));
CREATE TABLE DetalleReserva (id_detalle INT IDENTITY PRIMARY KEY,
  id_reserva INT NOT NULL REFERENCES Reserva(id_reserva) ON DELETE CASCADE,
  id_habitacion INT NOT NULL REFERENCES Habitacion(id_habitacion), tarifa_aplicada DECIMAL(10,2) NOT NULL);
CREATE TABLE Estancia (id_estancia INT IDENTITY PRIMARY KEY, id_reserva INT NOT NULL UNIQUE REFERENCES Reserva(id_reserva),
  fecha_checkin DATETIME NOT NULL, fecha_checkout DATETIME,
  CONSTRAINT CK_stay CHECK (fecha_checkout IS NULL OR fecha_checkout >= fecha_checkin));
CREATE TABLE Factura (id_factura INT IDENTITY PRIMARY KEY, id_estancia INT NOT NULL UNIQUE REFERENCES Estancia(id_estancia),
  subtotal DECIMAL(10,2) NOT NULL, iva DECIMAL(10,2) NOT NULL, inguat DECIMAL(10,2) NOT NULL, total DECIMAL(10,2) NOT NULL);
CREATE TABLE Pago (id_pago INT IDENTITY PRIMARY KEY, id_factura INT NOT NULL REFERENCES Factura(id_factura),
  monto DECIMAL(10,2) NOT NULL CHECK (monto > 0),
  metodo VARCHAR(15) NOT NULL CHECK (metodo IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
  referencia NVARCHAR(40), fecha DATETIME DEFAULT GETDATE());
CREATE TABLE Bitacora (id_bitacora INT IDENTITY PRIMARY KEY, accion NVARCHAR(40) NOT NULL, id_referencia INT,
  id_usuario INT REFERENCES Usuario(id_usuario), fecha DATETIME DEFAULT GETDATE());

//Paso 3. Datos de prueba
INSERT Rol(nombre) VALUES ('Recepcionista'),('Administrador'),('Gerente'),('Caja');
INSERT Usuario(usuario,clave_hash,id_rol) VALUES ('recep1','hash_demo',1),('admin','hash_demo',2);
INSERT TipoHabitacion(nombre,capacidad,tarifa) VALUES ('Sencilla',1,350),('Doble',2,500),('Familiar',4,750),('Suite',2,1100);

-- 48 habitaciones: 20 sencillas, 18 dobles, 2 familiares, 8 suites
DECLARE @i INT = 1;
WHILE @i <= 20 BEGIN INSERT Habitacion(numero,piso,id_tipo) VALUES (CAST(100+@i AS NVARCHAR),1,1); SET @i+=1; END;
SET @i = 1;
WHILE @i <= 18 BEGIN INSERT Habitacion(numero,piso,id_tipo) VALUES (CAST(200+@i AS NVARCHAR),2,2); SET @i+=1; END;
INSERT Habitacion(numero,piso,id_tipo) VALUES ('301',3,3),('302',3,3);
SET @i = 1;
WHILE @i <= 8 BEGIN INSERT Habitacion(numero,piso,id_tipo) VALUES (CAST(400+@i AS NVARCHAR),4,4); SET @i+=1; END;

INSERT Cliente(nombre,apellido,tipo_documento,numero_documento,telefono,email) VALUES
('Ana','López','DPI','2500123450101','55551111','ana@mail.com'),
('Carlos','Pérez','DPI','2500123450202','55552222','carlos@mail.com'),
('María','Gómez','PAS','P1234567','55553333','maria@mail.com');

//Paso 4. Crear reservas de prueba
INSERT Reserva(id_cliente,id_usuario,fecha_entrada,fecha_salida,total) VALUES (1,1,'2026-10-10','2026-10-13',1500);
INSERT DetalleReserva(id_reserva,id_habitacion,tarifa_aplicada) VALUES (1,21,500); -- habitación 201

//Paso 5. Consulta de disponibilidad (RF-03), la misma del SDD. Pruébala con fechas que se traslapen y con fechas libres:
DECLARE @entrada DATE='2026-10-11', @salida DATE='2026-10-14', @tipo INT=2, @personas INT=2;
SELECT h.numero, t.nombre, t.tarifa
FROM Habitacion h JOIN TipoHabitacion t ON t.id_tipo=h.id_tipo
WHERE h.id_tipo=@tipo AND t.capacidad>=@personas AND h.estado<>'MANTENIMIENTO'
  AND NOT EXISTS (SELECT 1 FROM DetalleReserva d JOIN Reserva r ON r.id_reserva=d.id_reserva
    WHERE d.id_habitacion=h.id_habitacion AND r.estado IN ('CONFIRMADA','EN_CURSO')
      AND r.fecha_entrada<@salida AND r.fecha_salida>@entrada);

//Paso 6. Probar las reglas (aquí sacas tus capturas)
-- Debe FALLAR por CK_fechas (RN-01):
INSERT Reserva(id_cliente,id_usuario,fecha_entrada,fecha_salida) VALUES (1,1,'2026-10-15','2026-10-12');
-- Debe FALLAR por documento duplicado:
INSERT Cliente(nombre,apellido,tipo_documento,numero_documento,telefono) VALUES ('X','Y','DPI','2500123450101','1');
-- Debe FALLAR por estado inválido:
UPDATE Habitacion SET estado='ROTA' WHERE id_habitacion=1;

//Paso 7. Check-in, check-out y factura (RF-08)
INSERT Estancia(id_reserva,fecha_checkin,fecha_checkout) VALUES (1,'2026-10-10 14:00','2026-10-13 11:00');
DECLARE @sub DECIMAL(10,2) = 500*3;
INSERT Factura(id_estancia,subtotal,iva,inguat,total)
VALUES (1,@sub,ROUND(@sub*0.12,2),ROUND(@sub*0.10,2),@sub+ROUND(@sub*0.12,2)+ROUND(@sub*0.10,2));
SELECT * FROM Factura;  -- total debe ser 1830.00

//Paso 8. Pago y reporte simple
INSERT Pago(id_factura,monto,metodo) VALUES (1,1830,'EFECTIVO');
SELECT t.nombre AS tipo, COUNT(*) AS reservas, SUM(d.tarifa_aplicada) AS ingresos
FROM DetalleReserva d JOIN Habitacion h ON h.id_habitacion=d.id_habitacion
JOIN TipoHabitacion t ON t.id_tipo=h.id_tipo GROUP BY t.nombre;
