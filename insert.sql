-- Функция для генерации случайного текста
CREATE OR REPLACE FUNCTION generate_random_text(min_len INT, max_len INT)
    RETURNS TEXT AS $$
DECLARE
    len INT;
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ';
    result TEXT := '';
BEGIN
    len := floor(random() * (max_len - min_len + 1) + min_len);
    FOR i IN 1..len LOOP
            result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
        END LOOP;
    RETURN trim(result);
END;
$$ LANGUAGE plpgsql;

-- Функция для генерации случайного JSONB (для поставщиков)
CREATE OR REPLACE FUNCTION generate_random_jsonb_supplier()
    RETURNS JSONB AS $$
BEGIN
    RETURN jsonb_build_object(
            'phone', '+' || LPAD(floor(random()*10000000000)::text, 12, '0'),
            'email', 'contact_' || substr(md5(random()::text), 1, 8) || '@supplier.com',
            'website', 'http://supplier_' || substr(md5(random()::text), 1, 8) || '.com',
            'notes', generate_random_text(10, 50)
           );
END;
$$ LANGUAGE plpgsql;

-- Функции для получения случайных ID (для внешних ключей)
CREATE OR REPLACE FUNCTION get_random_employee_id() RETURNS INT AS $$
DECLARE emp_id INT; BEGIN SELECT EmployeeID INTO emp_id FROM Employees ORDER BY random() LIMIT 1; RETURN emp_id; END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_random_role_id() RETURNS INT AS $$
DECLARE role_id INT; BEGIN SELECT RoleID INTO role_id FROM UserRoles ORDER BY random() LIMIT 1; RETURN role_id; END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_random_product_id() RETURNS INT AS $$
DECLARE prod_id INT; BEGIN SELECT ProductID INTO prod_id FROM Products ORDER BY random() LIMIT 1; RETURN prod_id; END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_random_supplier_id() RETURNS INT AS $$
DECLARE sup_id INT; BEGIN SELECT SupplierID INTO sup_id FROM Suppliers ORDER BY random() LIMIT 1; RETURN sup_id; END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_random_zone_id() RETURNS INT AS $$
DECLARE zone_id INT; BEGIN SELECT ZoneID INTO zone_id FROM StorageZones ORDER BY random() LIMIT 1; RETURN zone_id; END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_random_warehouse_id() RETURNS INT AS $$
DECLARE wh_id INT; BEGIN SELECT WarehouseID INTO wh_id FROM Warehouses ORDER BY random() LIMIT 1; RETURN wh_id; END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION get_random_inventory_id() RETURNS INT AS $$
DECLARE inv_id INT; BEGIN SELECT InventoryID INTO inv_id FROM Inventory ORDER BY random() LIMIT 1; RETURN inv_id; END;
$$ LANGUAGE plpgsql;

-- Процедура для генерации UserRoles
CREATE OR REPLACE PROCEDURE generate_user_roles()
    LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO UserRoles (RoleName, Description)
    SELECT 'Администратор', 'Полный доступ' WHERE NOT EXISTS (SELECT 1 FROM UserRoles WHERE RoleName = 'Администратор');
    INSERT INTO UserRoles (RoleName, Description)
    SELECT 'Кладовщик', 'Управление запасами' WHERE NOT EXISTS (SELECT 1 FROM UserRoles WHERE RoleName = 'Кладовщик');
    INSERT INTO UserRoles (RoleName, Description)
    SELECT 'Менеджер', 'Управление заказами и отчеты' WHERE NOT EXISTS (SELECT 1 FROM UserRoles WHERE RoleName = 'Менеджер');
END;
$$;

-- Процедура для генерации Suppliers
CREATE OR REPLACE PROCEDURE generate_suppliers(num_records INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..num_records LOOP
            INSERT INTO Suppliers (Name, Address, ContactInfo)
            VALUES (
                       'Supplier ' || i,
                       'Address ' || i || ', City ' || floor(random() * 100 + 1)::int,
                       generate_random_jsonb_supplier()
                   );
        END LOOP;
    RAISE NOTICE '% Suppliers generated.', num_records;
END;
$$;

-- Процедура для генерации Products
CREATE OR REPLACE PROCEDURE generate_products(num_records INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
    category_arr product_category_enum[] := ARRAY['Электроника', 'Одежда', 'Продукты питания', 'Стройматериалы', 'Канцтовары'];
    unit_arr unit_of_measure_enum[] := ARRAY['шт.', 'кг', 'л', 'м', 'упак.'];
BEGIN
    FOR i IN 1..num_records LOOP
            INSERT INTO Products (Name, Description, Category, UnitOfMeasure, MarkupPercentage, ReorderLevel, MaxStockLevel, IsActive)
            VALUES (
                       'Product ' || i,
                       generate_random_text(20, 100),
                       category_arr[floor(random() * array_length(category_arr, 1) + 1)::int],
                       unit_arr[floor(random() * array_length(unit_arr, 1) + 1)::int],
                       round((random() * 50 + 5)::numeric, 2),
                       floor(random() * 20 + 5)::int,
                       floor(random() * 100 + 50)::int,
                       TRUE
                   );
        END LOOP;
    RAISE NOTICE '% Products generated.', num_records;
END;
$$;

-- Процедура для генерации Warehouses
CREATE OR REPLACE PROCEDURE generate_warehouses(num_records INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
BEGIN
    FOR i IN 1..num_records LOOP
            INSERT INTO Warehouses (Name, Location)
            VALUES ('Warehouse ' || i, 'Warehouse Address ' || i || ', City ' || floor(random() * 100 + 1)::int);
        END LOOP;
    RAISE NOTICE '% Warehouses generated.', num_records;
END;
$$;

-- Процедура для генерации StorageZones
CREATE OR REPLACE PROCEDURE generate_storage_zones(zones_per_warehouse INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Warehouses) THEN
        RAISE NOTICE 'Skipping StorageZones generation: Warehouses do not exist.';
        RETURN;
    END IF;
    FOR i IN 1..(SELECT COUNT(*) FROM Warehouses) * zones_per_warehouse LOOP
            INSERT INTO StorageZones (warehouseid, code, storagecapacity)
            VALUES (get_random_warehouse_id(), 'ZONE-' || i || '-' || floor(random()*1000)::int, round((random() * 500 + 100)::numeric, 2));
        END LOOP;
    RAISE NOTICE '% StorageZones generated (approx. % per warehouse).', (SELECT COUNT(*) FROM StorageZones), zones_per_warehouse;
END;
$$;

-- Процедура для генерации Employees
CREATE OR REPLACE PROCEDURE generate_employees(num_records INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
    role_id INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM UserRoles) THEN
        RAISE NOTICE 'Skipping Employees generation: UserRoles do not exist.';
        RETURN;
    END IF;
    FOR i IN 1..num_records LOOP
            role_id := get_random_role_id();
            INSERT INTO Employees (Username, PasswordHash, FirstName, LastName, RoleID, Position, Phone, Email)
            VALUES (
                       'emp_' || i,
                       md5('password' || i),
                       'FirstName' || i,
                       'LastName' || i,
                       role_id,
                       CASE role_id
                           WHEN (SELECT RoleID FROM UserRoles WHERE RoleName = 'Администратор') THEN 'Системный администратор'
                           WHEN (SELECT RoleID FROM UserRoles WHERE RoleName = 'Кладовщик') THEN 'Кладовщик'
                           WHEN (SELECT RoleID FROM UserRoles WHERE RoleName = 'Менеджер') THEN 'Менеджер по закупкам'
                           ELSE 'Сотрудник'
                           END,
                       '+' || LPAD(floor(random()*10000000000)::text, 12, '0'),
                       'emp' || i || '@company.com'
                   );
        END LOOP;
    RAISE NOTICE '% Employees generated.', num_records;
END;
$$;

-- Процедура для генерации Inventory
CREATE OR REPLACE PROCEDURE generate_inventory(num_records INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Products) OR NOT EXISTS (SELECT 1 FROM StorageZones) THEN
        RAISE NOTICE 'Skipping Inventory generation: Products or StorageZones do not exist.';
        RETURN;
    END IF;
    FOR i IN 1..num_records LOOP
            INSERT INTO Inventory (ProductID, ZoneID, Quantity, BatchNumber, ExpirationDate)
            VALUES (
                       get_random_product_id(),
                       get_random_zone_id(),
                       floor(random() * 500)::int,
                       'BATCH-' || substr(md5(random()::text), 1, 10) || '-' || TO_CHAR(NOW(), 'YYYYMMDD'),
                       CASE WHEN random() < 0.7 THEN (CURRENT_DATE + (floor(random() * 730) * INTERVAL '1 day'))::DATE ELSE NULL END
                   );
        END LOOP;
    RAISE NOTICE '% Inventory records generated.', num_records;
END;
$$;

-- Процедура для генерации PurchaseOrders
CREATE OR REPLACE PROCEDURE generate_purchase_orders(num_records INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    order_status_arr order_status_enum[] := ARRAY['Новый', 'В обработке', 'Отправлен', 'Получен', 'Отменен'];
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Products) OR NOT EXISTS (SELECT 1 FROM Suppliers) THEN
        RAISE NOTICE 'Skipping PurchaseOrders generation: Products or Suppliers do not exist.';
        RETURN;
    END IF;
    FOR i IN 1..num_records LOOP
            INSERT INTO PurchaseOrders (ProductID, SupplierID, OrderDate, ExpectedDeliveryDate, ActualDeliveryDate, Status, PurchasePrice, QuantityOrdered)
            VALUES (
                       get_random_product_id(),
                       get_random_supplier_id(),
                       (CURRENT_DATE - (floor(random() * 180) * INTERVAL '1 day'))::DATE,
                       CASE WHEN random() < 0.8 THEN (CURRENT_DATE + (floor(random() * 30) * INTERVAL '1 day'))::DATE END,
                       CASE WHEN random() < 0.6 THEN (CURRENT_DATE - (floor(random() * 90) * INTERVAL '1 day'))::DATE END,
                       order_status_arr[floor(random() * array_length(order_status_arr, 1) + 1)::int],
                       round((random() * 1000 + 50)::numeric, 2),
                       floor(random() * 50 + 1)::int
                   );
        END LOOP;
    RAISE NOTICE '% PurchaseOrders generated.', num_records;
END;
$$;

-- Процедура для генерации InventoryTransactions
CREATE OR REPLACE PROCEDURE generate_inventory_transactions(num_records INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
    current_inventory_id INT;
    current_employee_id INT;

    v_transaction_type transaction_type_enum;

BEGIN
    IF NOT EXISTS (SELECT 1 FROM Inventory) OR NOT EXISTS (SELECT 1 FROM Employees) THEN
        RETURN;
    END IF;
    FOR i IN 1..num_records LOOP
            current_inventory_id := get_random_inventory_id();
            current_employee_id := get_random_employee_id();
            v_transaction_type := (SELECT element FROM unnest(ARRAY['Приход', 'Расход', 'Перемещение', 'Списание', 'Инвентаризация']::transaction_type_enum[]) AS element ORDER BY random() LIMIT 1);

            INSERT INTO InventoryTransactions (ProductID, TransactionType, EmployeeID, SourceZoneID, DestinationZoneID, TransactionTimestamp, InventoryID)
            VALUES (
                       (SELECT ProductID FROM Inventory WHERE InventoryID = current_inventory_id),
                       v_transaction_type,
                       CASE WHEN random() < 0.8 THEN current_employee_id END,
                       CASE
                           WHEN v_transaction_type = 'Перемещение' THEN get_random_zone_id()
                           WHEN v_transaction_type IN ('Расход', 'Списание') THEN get_random_zone_id()
                           WHEN v_transaction_type = 'Приход' THEN NULL
                           WHEN v_transaction_type = 'Инвентаризация' THEN get_random_zone_id()
                           END,
                       CASE
                           WHEN v_transaction_type = 'Перемещение' THEN get_random_zone_id()
                           WHEN v_transaction_type = 'Приход' THEN get_random_zone_id()
                           WHEN v_transaction_type IN ('Расход', 'Списание') THEN NULL
                           WHEN v_transaction_type = 'Инвентаризация' THEN NULL
                           END,
                       NOW() - (floor(random() * 365) * INTERVAL '1 day'),
                       current_inventory_id
                   );
        END LOOP;
    RAISE NOTICE '% InventoryTransactions generated.', num_records;
END;
$$;

-- Процедура для генерации StockTakes
CREATE OR REPLACE PROCEDURE generate_stocktakes(num_records INT)
    LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
    current_zone_id INT;
    current_employee_id INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Employees) THEN
        RETURN;
    END IF;
    FOR i IN 1..num_records LOOP
            current_zone_id := CASE WHEN random() < 0.5 THEN get_random_zone_id() END;
            current_employee_id := get_random_employee_id();

            INSERT INTO StockTakes (StockTakeDate, Status, ZoneID, HasDiscrepancies, IsInitialStockTake, PerformedByEmployeeID)
            VALUES (
                       (CURRENT_DATE - (floor(random() * 365) * INTERVAL '1 day'))::DATE,
                       (SELECT element FROM unnest(ARRAY['Планируется', 'В процессе', 'Завершена', 'Отменена']::stocktake_status_enum[]) AS element ORDER BY random() LIMIT 1),
                       current_zone_id,
                       (random() < 0.3)::BOOLEAN,
                       (random() < 0.1)::BOOLEAN,
                       CASE WHEN random() < 0.8 THEN current_employee_id END
                   );
        END LOOP;
    RAISE NOTICE '% StockTakes generated.', num_records;
END;
$$;

CALL generate_user_roles();
CALL generate_suppliers(50);
CALL generate_products(500);
CALL generate_warehouses(5);
CALL generate_storage_zones(20);
CALL generate_employees(100);
CALL generate_inventory(50000);
CALL generate_purchase_orders(25000);
CALL generate_inventory_transactions(200000);
CALL generate_stocktakes(50000);
