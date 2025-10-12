-- 1. Создаем ENUM типы, если они не существуют
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'unit_of_measure_enum') THEN
            CREATE TYPE unit_of_measure_enum AS ENUM ('шт.', 'кг', 'л', 'м', 'упак.');
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_type_enum') THEN
            CREATE TYPE transaction_type_enum AS ENUM ('Приход', 'Расход', 'Перемещение', 'Списание', 'Инвентаризация');
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status_enum') THEN
            CREATE TYPE order_status_enum AS ENUM ('Новый', 'В обработке', 'Отправлен', 'Получен', 'Отменен');
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'product_category_enum') THEN
            CREATE TYPE product_category_enum AS ENUM ('Электроника', 'Одежда', 'Продукты питания', 'Стройматериалы', 'Канцтовары');
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'stocktake_status_enum') THEN
            CREATE TYPE stocktake_status_enum AS ENUM ('Планируется', 'В процессе', 'Завершена', 'Отменена');
        END IF;
    END $$;

-- Удаляем существующие объекты (таблицы, индексы, ограничения), если они есть.
-- Это гарантирует полное пересоздание.
-- DROP INDEX IF EXISTS IX_Products_Category;
-- DROP INDEX IF EXISTS IX_Products_UnitOfMeasure;
-- DROP INDEX IF EXISTS IX_ProductSuppliers_ProductID;
-- DROP INDEX IF EXISTS IX_ProductSuppliers_SupplierID;
-- DROP INDEX IF EXISTS IX_Inventory_ProductID;
-- DROP INDEX IF EXISTS IX_Inventory_ZoneID;
-- DROP INDEX IF EXISTS IX_InventoryTransactions_ProductID;
-- DROP INDEX IF EXISTS IX_InventoryTransactions_TransactionType;
-- DROP INDEX IF EXISTS IX_InventoryTransactions_TransactionTimestamp;
-- DROP INDEX IF EXISTS IX_InventoryTransactions_UserID;
-- DROP INDEX IF EXISTS IX_PurchaseOrders_SupplierID;
-- DROP INDEX IF EXISTS IX_PurchaseOrders_OrderStatus;
-- DROP INDEX IF EXISTS IX_PurchaseOrders_UserID;
-- DROP INDEX IF EXISTS IX_PurchaseOrderLines_PurchaseOrderID;
-- DROP INDEX IF EXISTS IX_PurchaseOrderLines_ProductID;
-- DROP INDEX IF EXISTS IX_StockTakeResults_StockTakeID;
-- DROP INDEX IF EXISTS IX_StockTakeResults_ProductID;
-- DROP INDEX IF EXISTS IX_Users_RoleID;

DROP TABLE IF EXISTS StockTakeResults;
DROP TABLE IF EXISTS StockTakes;
DROP TABLE IF EXISTS PurchaseOrderLines;
DROP TABLE IF EXISTS PurchaseOrders;
DROP TABLE IF EXISTS InventoryTransactions;
DROP TABLE IF EXISTS Inventory;
DROP TABLE IF EXISTS ProductSuppliers;
DROP TABLE IF EXISTS StorageZones;
DROP TABLE IF EXISTS Warehouses;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Suppliers;
DROP TABLE IF EXISTS UserRoles;

-- Создаем таблицы

-- Таблица для ролей сотрудников (для ограничения доступа)
CREATE TABLE UserRoles (
                           RoleID SERIAL PRIMARY KEY,
                           RoleName VARCHAR(50) NOT NULL UNIQUE,
                           Description VARCHAR(255) NULL
);

-- Таблица Поставщики
CREATE TABLE Suppliers (
                           SupplierID SERIAL PRIMARY KEY,
                           Name VARCHAR(150) NOT NULL,
                           Address VARCHAR(255) NULL,
                           ContactInfo JSONB NULL -- Контактная информация в виде JSON
);

-- Таблица Товары
CREATE TABLE Products (
                          ProductID SERIAL PRIMARY KEY,
                          Name VARCHAR(150) NOT NULL,
                          Description TEXT NULL, -- Добавлено описание товара
                          Category product_category_enum NOT NULL,
                          UnitOfMeasure unit_of_measure_enum NOT NULL,
                          MarkupPercentage NUMERIC(5, 2) NULL, -- Процент на надбавочную стоимость
                          ReorderLevel INT NOT NULL DEFAULT 0, -- Уровень с которого начинается автозаполнение склада
                          MaxStockLevel INT NOT NULL DEFAULT 0, -- Максимальный запас
                          IsActive BOOLEAN NOT NULL DEFAULT TRUE -- Флаг активности товара
);

-- Таблица Закупки (Заказы поставщикам)
CREATE TABLE PurchaseOrders (
                                PurchaseOrderID SERIAL PRIMARY KEY,
                                ProductID INT NOT NULL, -- Ключ товара
                                SupplierID INT NOT NULL, -- Ключ поставщика
                                OrderDate DATE NOT NULL DEFAULT CURRENT_DATE, -- Дата заказа
                                ExpectedDeliveryDate DATE NULL, -- Ожидаемая дата доставки
                                ActualDeliveryDate DATE NULL, -- Фактическая дата доставки
                                Status order_status_enum NOT NULL, -- Статус закупки - ENUM
                                PurchasePrice NUMERIC(18, 2) NOT NULL, -- Закупочная цена за единицу
                                QuantityOrdered INT NOT NULL, -- Количество партий (в данном контексте "партия" = количество заказываемых единиц)

                                FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
                                FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID),
    CONSTRAINT CK_QuantityOrdered CHECK (QuantityOrdered > 0) -- Констрейнт на количество
);

-- Таблица Склады
CREATE TABLE Warehouses (
                            WarehouseID SERIAL PRIMARY KEY,
                            Name VARCHAR(100) NOT NULL, -- Номер склада
                            Location VARCHAR(255) NULL -- Адрес склада
);

-- Таблица Зоны склада
CREATE TABLE StorageZones (
                              ZoneID SERIAL PRIMARY KEY,
                              WarehouseID INT NOT NULL, -- Ключ склада
                              Code VARCHAR(50) NOT NULL UNIQUE, -- Код зоны
                              StorageCapacity NUMERIC(18, 2) NOT NULL, -- Вместимость в кубических метрах

                              FOREIGN KEY (WarehouseID) REFERENCES Warehouses(WarehouseID) ON DELETE CASCADE
);

-- Таблица Партия
CREATE TABLE Inventory (
                           InventoryID SERIAL PRIMARY KEY,
                           ProductID INT NOT NULL, -- Ключ товара
                           ZoneID INT NOT NULL, -- Ключ зоны, где расположена партия
                           Quantity INT NOT NULL DEFAULT 0, -- Количество товаров в данной партии
                           BatchNumber VARCHAR(100) NULL, -- Номер партии
                           ExpirationDate DATE NULL, -- Дата окончания срока годности

                           FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
                           FOREIGN KEY (ZoneID) REFERENCES StorageZones(ZoneID),
    CONSTRAINT CK_InventoryQuantity CHECK (Quantity >= 0)
);

-- Таблица Сотрудники
CREATE TABLE Employees (
                           EmployeeID SERIAL PRIMARY KEY,
                           Username VARCHAR(50) NOT NULL UNIQUE,
                           PasswordHash VARCHAR(255) NOT NULL,
                           FirstName VARCHAR(50) NULL,
                           LastName VARCHAR(50) NULL,
                           RoleID INT NOT NULL,
                           HireDate DATE DEFAULT CURRENT_DATE, -- Дата найма
                           Phone VARCHAR(20) NULL,
                           Email VARCHAR(100) NULL,
                           Position VARCHAR(100) NULL,

                           FOREIGN KEY (RoleID) REFERENCES UserRoles(RoleID)
);

-- Таблица Транзакция (Движение товаров)
CREATE TABLE InventoryTransactions (
                                       TransactionID BIGSERIAL PRIMARY KEY,
                                       TransactionTimestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), -- Дата и время транзакции
                                       EmployeeID INT NULL, -- Ключ сотрудника, совершившего транзакцию
                                       ProductID INT NOT NULL, -- Ключ товара
                                       SourceZoneID INT NULL, -- Ключ зоны, с которой забрали партию (может быть null для прихода)
                                       DestinationZoneID INT NULL, -- Ключ зоны, в которую доставили партию (может быть null для списания/расхода)
                                       TransactionType transaction_type_enum NOT NULL, -- Тип транзакции
                                       InventoryID INT NULL, -- Ключ партии/инвентарной записи, с которой связана транзакция (для аудита)

                                       FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID),
                                       FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    FOREIGN KEY (SourceZoneID) REFERENCES StorageZones(ZoneID),
    FOREIGN KEY (DestinationZoneID) REFERENCES StorageZones(ZoneID),
    FOREIGN KEY (InventoryID) REFERENCES Inventory(InventoryID)
);

-- Таблица Инвентаризация
CREATE TABLE StockTakes (
                            StockTakeID SERIAL PRIMARY KEY,
                            StockTakeDate DATE NOT NULL DEFAULT CURRENT_DATE, -- Дата инвентаризации
                            Status stocktake_status_enum NOT NULL, -- Статус инвентаризации - ENUM
                            ZoneID INT NULL, -- Ключ зоны, инвентаризация проводится по зонам
                            HasDiscrepancies BOOLEAN NOT NULL DEFAULT FALSE, -- Есть ли нарушения (разница между ожидаемым и фактическим)
                            IsInitialStockTake BOOLEAN NOT NULL DEFAULT FALSE, -- Флаг первичной инвентаризации
                            PerformedByEmployeeID INT NULL, -- Ключ сотрудника, проводившего инвентаризацию

                            FOREIGN KEY (ZoneID) REFERENCES StorageZones(ZoneID),
    FOREIGN KEY (PerformedByEmployeeID) REFERENCES Employees(EmployeeID)
);

-- Создание индексов
-- CREATE INDEX IF NOT EXISTS IX_Products_Category ON Products(Category);
-- CREATE INDEX IF NOT EXISTS IX_Products_UnitOfMeasure ON Products(UnitOfMeasure);
-- CREATE INDEX IF NOT EXISTS IX_ProductSuppliers_ProductID ON ProductSuppliers(ProductID);
-- CREATE INDEX IF NOT EXISTS IX_ProductSuppliers_SupplierID ON ProductSuppliers(SupplierID);
-- CREATE INDEX IF NOT EXISTS IX_PurchaseOrders_ProductID ON PurchaseOrders(ProductID); -- Индекс на FK к Product
-- CREATE INDEX IF NOT EXISTS IX_PurchaseOrders_SupplierID ON PurchaseOrders(SupplierID);
-- CREATE INDEX IF NOT EXISTS IX_PurchaseOrders_Status ON PurchaseOrders(Status);
-- CREATE INDEX IF NOT EXISTS IX_Warehouses_Name ON Warehouses(Name);
-- CREATE INDEX IF NOT EXISTS IX_StorageZones_WarehouseID ON StorageZones(WarehouseID);
-- CREATE INDEX IF NOT EXISTS IX_StorageZones_Code ON StorageZones(Code);
-- CREATE INDEX IF NOT EXISTS IX_Inventory_ProductID ON Inventory(ProductID);
-- CREATE INDEX IF NOT EXISTS IX_Inventory_ZoneID ON Inventory(ZoneID);
-- CREATE INDEX IF NOT EXISTS IX_Inventory_BatchNumber ON Inventory(BatchNumber); -- Для поиска по номеру партии
-- CREATE INDEX IF NOT EXISTS IX_Inventory_ExpirationDate ON Inventory(ExpirationDate); -- Для поиска просроченных
-- CREATE INDEX IF NOT EXISTS IX_Employees_Username ON Employees(Username);
-- CREATE INDEX IF NOT EXISTS IX_Employees_RoleID ON Employees(RoleID);
-- CREATE INDEX IF NOT EXISTS IX_InventoryTransactions_ProductID ON InventoryTransactions(ProductID);
-- CREATE INDEX IF NOT EXISTS IX_InventoryTransactions_TransactionTimestamp ON InventoryTransactions(TransactionTimestamp);
-- CREATE INDEX IF NOT EXISTS IX_InventoryTransactions_EmployeeID ON InventoryTransactions(EmployeeID);
-- CREATE INDEX IF NOT EXISTS IX_InventoryTransactions_TransactionType ON InventoryTransactions(TransactionType);
-- CREATE INDEX IF NOT EXISTS IX_InventoryTransactions_SourceZoneID ON InventoryTransactions(SourceZoneID);
-- CREATE INDEX IF NOT EXISTS IX_InventoryTransactions_DestinationZoneID ON InventoryTransactions(DestinationZoneID);
-- CREATE INDEX IF NOT EXISTS IX_InventoryTransactions_InventoryID ON InventoryTransactions(InventoryID); -- Индекс на FK к Inventory
-- CREATE INDEX IF NOT EXISTS IX_StockTakes_WarehouseID ON StockTakes(WarehouseID);
-- CREATE INDEX IF NOT EXISTS IX_StockTakes_Status ON StockTakes(Status);
-- CREATE INDEX IF NOT EXISTS IX_StockTakes_ZoneID ON StockTakes(ZoneID);
-- CREATE INDEX IF NOT EXISTS IX_StockTakes_PerformedByEmployeeID ON StockTakes(PerformedByEmployeeID);

-- Индексация для JSONB полей
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_specifications ON Products USING GIN (Specifications);
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_inventory_lotspecificinfo ON Inventory USING GIN (LotSpecificInfo);
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_suppliers_contactinfo ON Suppliers USING GIN (ContactInfo);

-- Начальные данные

-- Добавляем роли сотрудников, если их нет
-- INSERT INTO UserRoles (RoleName, Description)
-- SELECT 'Администратор', 'Полный доступ' WHERE NOT EXISTS (SELECT 1 FROM UserRoles WHERE RoleName = 'Администратор');
-- INSERT INTO UserRoles (RoleName, Description)
-- SELECT 'Кладовщик', 'Управление запасами' WHERE NOT EXISTS (SELECT 1 FROM UserRoles WHERE RoleName = 'Кладовщик');
-- INSERT INTO UserRoles (RoleName, Description)
-- SELECT 'Менеджер', 'Управление заказами и отчеты' WHERE NOT EXISTS (SELECT 1 FROM UserRoles WHERE RoleName = 'Менеджер');

-- Пример создания пользователя
-- INSERT INTO Employees (Username, PasswordHash, FirstName, LastName, RoleID, Position, Phone, Email)
-- SELECT 'admin', 'hashed_password_here', 'Super', 'Admin', (SELECT RoleID FROM UserRoles WHERE RoleName = 'Администратор'), 'Системный администратор', '+1234567890', 'admin@example.com'
-- WHERE NOT EXISTS (SELECT 1 FROM Employees WHERE Username = 'admin');