-- Это представление выводит список партий товаров, срок годности которых истекает в ближайшее время (30 дней).
CREATE VIEW vw_ExpiringInventory AS
SELECT
    i.InventoryID,
    p.ProductID,
    p.Name AS ProductName,
    i.BatchNumber,
    i.Quantity,
    i.ExpirationDate,
    w.Name AS WarehouseName,
    sz.Code AS ZoneCode,
    (i.ExpirationDate - CURRENT_DATE) AS DaysUntilExpiration
FROM
    Inventory i
        JOIN
    Products p ON i.ProductID = p.ProductID
        JOIN
    StorageZones sz ON i.ZoneID = sz.ZoneID
        JOIN
    Warehouses w ON sz.WarehouseID = w.WarehouseID
WHERE
    i.ExpirationDate IS NOT NULL
  AND i.ExpirationDate >= CURRENT_DATE
  AND (i.ExpirationDate - CURRENT_DATE) <= 30
ORDER BY
    DaysUntilExpiration;

-- Показать товары, срок годности которых истекает в течение следующих 7 дней
SELECT
    ProductName,
    BatchNumber,
    Quantity,
    ExpirationDate,
    DaysUntilExpiration,
    WarehouseName,
    ZoneCode
FROM
    vw_ExpiringInventory
WHERE
    DaysUntilExpiration <= 7;

-- Это представление покажет, какие сотрудники выявили нарушения при проведении вторичных инвентаризаций.
CREATE VIEW vw_EmployeesWithCompletedSecondaryDiscrepancyStockTakes AS
SELECT
    e.EmployeeID,
    e.Username,
    e.FirstName,
    e.LastName,
    st.StockTakeID,
    st.StockTakeDate,
    st.ZoneID,
    st.HasDiscrepancies
FROM
    Employees e
        JOIN
    StockTakes st ON e.EmployeeID = st.PerformedByEmployeeID
WHERE
    st.Status = 'Завершена'
  AND st.HasDiscrepancies = TRUE
  AND st.IsInitialStockTake = FALSE;

-- Получить список сотрудников, выявивших нарушения при вторичных инвентаризациях
SELECT
    EmployeeID,
    Username,
    FirstName,
    LastName,
    StockTakeID,
    StockTakeDate,
    ZoneID
FROM
    vw_EmployeesWithCompletedSecondaryDiscrepancyStockTakes
ORDER BY
    StockTakeDate DESC, LastName;

-- Посчитать, сколько вторичных инвентаризаций с нарушениями провел каждый сотрудник
SELECT
    Username,
    FirstName,
    LastName,
    COUNT(StockTakeID) AS NumberOfSecondaryDiscrepancyStockTakes
FROM
    vw_EmployeesWithCompletedSecondaryDiscrepancyStockTakes
GROUP BY
    Username, FirstName, LastName
ORDER BY
    NumberOfSecondaryDiscrepancyStockTakes DESC;

-- Это представление покажет сводку по всем активным товарам, которые достигли или ниже своего минимального
-- уровня запасов (ReorderLevel) и нуждаются в пополнении. Оно также учитывает товары, которые уже находятся в
-- процессе заказа (статус в PurchaseOrders - 'Новый', 'В обработке', 'Отправлен').
CREATE OR REPLACE VIEW v_ProductsToReorder AS
WITH ProductStock AS (
    -- Вычисляем общий остаток товара на складе
    SELECT
        ProductID,
        COALESCE(SUM(Quantity), 0) AS CurrentStock
    FROM
        Inventory
    GROUP BY
        ProductID
),
 ProductOnOrder AS (
     -- Вычисляем общее количество товара, которое уже заказано и в пути
     SELECT
         ProductID,
         COALESCE(SUM(QuantityOrdered), 0) AS QuantityOnOrder
     FROM
         PurchaseOrders
     WHERE
         Status IN ('Новый', 'В обработке', 'Отправлен')
     GROUP BY
         ProductID
 )
SELECT
    p.ProductID,
    p.Name AS ProductName,
    p.ReorderLevel,
    p.MaxStockLevel,
    COALESCE(ps.CurrentStock, 0) AS CurrentStock,
    COALESCE(po.QuantityOnOrder, 0) AS QuantityOnOrder,
    CASE
        WHEN COALESCE(ps.CurrentStock, 0) <= p.ReorderLevel
            AND COALESCE(po.QuantityOnOrder, 0) = 0
            AND p.IsActive IS TRUE
            THEN TRUE
        ELSE FALSE
        END AS NeedsReorder
FROM
    Products p
        LEFT JOIN
    ProductStock ps ON p.ProductID = ps.ProductID
        LEFT JOIN
    ProductOnOrder po ON p.ProductID = po.ProductID
WHERE
    p.IsActive IS TRUE; -- Фильтруем только активные товары

SELECT * FROM v_ProductsToReorder;