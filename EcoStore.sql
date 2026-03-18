-- =========================================
-- CREAR BASE DE DATOS SI NO EXISTE
-- =========================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'EcoStore')
BEGIN
    CREATE DATABASE EcoStore
END
GO

USE EcoStore
GO

-- =========================================
-- TABLAS (solo si no existen)
-- =========================================

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Rol')
CREATE TABLE Rol (
    id_rol INT IDENTITY(1,1) PRIMARY KEY,
    nombre_rol VARCHAR(50) NOT NULL,
    descripcion VARCHAR(150) NOT NULL
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Usuario')
CREATE TABLE Usuario (
    id_usuario INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    correo VARCHAR(150) UNIQUE NOT NULL,
    contrasenia VARCHAR(255) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    direccion VARCHAR(200) NOT NULL,
    fecha_registro DATETIME NOT NULL,
    estado VARCHAR(20) NOT NULL,
    id_rol INT NOT NULL,
    FOREIGN KEY (id_rol) REFERENCES Rol(id_rol)
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Categoria')
CREATE TABLE Categoria (
    id_categoria INT IDENTITY(1,1) PRIMARY KEY,
    nombre_categoria VARCHAR(100) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    estado VARCHAR(20) NOT NULL
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Producto')
CREATE TABLE Producto (
    id_producto INT IDENTITY(1,1) PRIMARY KEY,
    nombre_producto VARCHAR(150) NOT NULL,
    descripcion VARCHAR(300) NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    imagen_url VARCHAR(255) NOT NULL,
    id_categoria INT NOT NULL,
    estado VARCHAR(20) NOT NULL,
    FOREIGN KEY (id_categoria) REFERENCES Categoria(id_categoria)
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Inventario')
CREATE TABLE Inventario (
    id_inventario INT IDENTITY(1,1) PRIMARY KEY,
    id_producto INT NOT NULL,
    stock_actual INT NOT NULL,
    fecha_actualizacion DATETIME NOT NULL,
    FOREIGN KEY (id_producto) REFERENCES Producto(id_producto)
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Carrito')
CREATE TABLE Carrito (
    id_carrito INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario INT NOT NULL,
    fecha_creacion DATETIME NOT NULL,
    estado INT NOT NULL, -- 1=Activo, 0=Comprado
    FOREIGN KEY (id_usuario) REFERENCES Usuario(id_usuario)
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DetalleCarrito')
CREATE TABLE DetalleCarrito (
    id_detalle_carrito INT IDENTITY(1,1) PRIMARY KEY,
    id_carrito INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (id_carrito) REFERENCES Carrito(id_carrito),
    FOREIGN KEY (id_producto) REFERENCES Producto(id_producto)
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Pedido')
CREATE TABLE Pedido (
    id_pedido INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario INT NOT NULL,
    fecha_pedido DATETIME NOT NULL,
    estado_pedido VARCHAR(20) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (id_usuario) REFERENCES Usuario(id_usuario)
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DetallePedido')
CREATE TABLE DetallePedido (
    id_detalle_pedido INT IDENTITY(1,1) PRIMARY KEY,
    id_pedido INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido),
    FOREIGN KEY (id_producto) REFERENCES Producto(id_producto)
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Factura')
CREATE TABLE Factura (
    id_factura INT IDENTITY(1,1) PRIMARY KEY,
    id_pedido INT NOT NULL,
    fecha_factura DATETIME NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    impuesto DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (id_pedido) REFERENCES Pedido(id_pedido)
);

GO

-- =========================================
-- SP: AGREGAR PRODUCTO AL CARRITO
-- =========================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_AgregarProductoAlCarrito')
    DROP PROCEDURE sp_AgregarProductoAlCarrito
GO

CREATE PROCEDURE sp_AgregarProductoAlCarrito
    @IdUsuario INT,
    @IdProducto INT,
    @Cantidad INT,
    @PrecioUnitario DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdCarrito INT;
    DECLARE @Subtotal DECIMAL(18,2) = @Cantidad * @PrecioUnitario;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @IdCarrito = id_carrito
        FROM Carrito
        WHERE id_usuario = @IdUsuario AND estado = 1;

        IF @IdCarrito IS NULL
        BEGIN
            INSERT INTO Carrito (id_usuario, fecha_creacion, estado)
            VALUES (@IdUsuario, GETDATE(), 1);

            SET @IdCarrito = SCOPE_IDENTITY();
        END

        IF EXISTS (
            SELECT 1 FROM DetalleCarrito 
            WHERE id_carrito = @IdCarrito AND id_producto = @IdProducto
        )
        BEGIN
            UPDATE DetalleCarrito
            SET cantidad = @Cantidad,
                subtotal = @Subtotal
            WHERE id_carrito = @IdCarrito AND id_producto = @IdProducto;
        END
        ELSE
        BEGIN
            INSERT INTO DetalleCarrito
            VALUES (@IdCarrito, @IdProducto, @Cantidad, @PrecioUnitario, @Subtotal);
        END

        COMMIT TRANSACTION;
        SELECT 'Éxito' AS Resultado;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS Error;
    END CATCH
END
GO

-- =========================================
-- SP: ELIMINAR PRODUCTO DEL CARRITO
-- =========================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_EliminarProductoDelCarrito')
    DROP PROCEDURE sp_EliminarProductoDelCarrito
GO

CREATE PROCEDURE sp_EliminarProductoDelCarrito
    @IdUsuario INT,
    @IdProducto INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdCarrito INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @IdCarrito = id_carrito
        FROM Carrito
        WHERE id_usuario = @IdUsuario AND estado = 1;

        IF @IdCarrito IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT 'No se encontró carrito activo' AS Error;
            RETURN;
        END

        DELETE FROM DetalleCarrito
        WHERE id_carrito = @IdCarrito AND id_producto = @IdProducto;

        COMMIT TRANSACTION;
        SELECT 'Éxito' AS Resultado;

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT ERROR_MESSAGE() AS Error;
    END CATCH
END
GO

-- =========================================
-- SP: CONFIRMAR COMPRA
-- =========================================
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_ConfirmarCompra')
    DROP PROCEDURE sp_ConfirmarCompra
GO

CREATE PROCEDURE sp_ConfirmarCompra
    @id_usuario INT,
    @id_carrito INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION
    BEGIN TRY

        DECLARE @id_pedido INT
        DECLARE @total DECIMAL(10,2)
        DECLARE @impuesto DECIMAL(10,2)
        DECLARE @total_final DECIMAL(10,2)

        IF NOT EXISTS (SELECT 1 FROM DetalleCarrito WHERE id_carrito = @id_carrito)
            RAISERROR('El carrito está vacío',16,1)

        INSERT INTO Pedido VALUES (@id_usuario, GETDATE(), 'Pendiente', 0)
        SET @id_pedido = SCOPE_IDENTITY()

        INSERT INTO DetallePedido
        SELECT @id_pedido, id_producto, cantidad, precio_unitario, subtotal
        FROM DetalleCarrito
        WHERE id_carrito = @id_carrito

        IF EXISTS (
            SELECT 1 FROM Inventario i
            JOIN DetalleCarrito dc ON i.id_producto = dc.id_producto
            WHERE dc.id_carrito = @id_carrito
            AND i.stock_actual < dc.cantidad
        )
            RAISERROR('Stock insuficiente',16,1)

        UPDATE i
        SET stock_actual = stock_actual - dc.cantidad
        FROM Inventario i
        JOIN DetalleCarrito dc ON i.id_producto = dc.id_producto
        WHERE dc.id_carrito = @id_carrito

        SELECT @total = SUM(subtotal)
        FROM DetallePedido
        WHERE id_pedido = @id_pedido

        UPDATE Pedido
        SET total = @total, estado_pedido = 'Confirmado'
        WHERE id_pedido = @id_pedido

        SET @impuesto = @total * 0.15
        SET @total_final = @total + @impuesto

        INSERT INTO Factura
        VALUES (@id_pedido, GETDATE(), @total, @impuesto, @total_final)

        DELETE FROM DetalleCarrito WHERE id_carrito = @id_carrito
        UPDATE Carrito SET estado = 0 WHERE id_carrito = @id_carrito

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        SELECT ERROR_MESSAGE() AS Error
    END CATCH
END
GO