-- ============================================================
-- DBA - Simple SQL Database (Adventure Works Style)
-- Creates the database, schemas, tables, and sample data
-- used by the permission scripting demo.
-- ============================================================

USE master;
GO

-- Drop and recreate database
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'DBA')
BEGIN
    ALTER DATABASE DBA SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DBA;
END
GO

CREATE DATABASE DBA;
GO

USE DBA;
GO

-- ============================================================
-- SCHEMAS
-- ============================================================
CREATE SCHEMA Sales;
GO
CREATE SCHEMA Production;
GO
CREATE SCHEMA HumanResources;
GO


-- ============================================================
-- TABLES
-- ============================================================

-- Production.Products
CREATE TABLE Production.Products (
    ProductID         INT             IDENTITY(1,1) PRIMARY KEY,
    ProductNumber     NVARCHAR(25)    NOT NULL UNIQUE,
    ProductName       NVARCHAR(100)   NOT NULL,
    Category          NVARCHAR(50)    NOT NULL,
    SubCategory       NVARCHAR(50)    NULL,
    ListPrice         DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    StockQuantity     INT             NOT NULL DEFAULT 0,
    Color             NVARCHAR(15)    NULL,
    Weight            DECIMAL(8,2)    NULL,
    SellStartDate     DATE            NOT NULL DEFAULT GETDATE(),
    Discontinued      BIT             NOT NULL DEFAULT 0,
    ModifiedDate      DATETIME        NOT NULL DEFAULT GETDATE()
);

-- Sales.Customers
CREATE TABLE Sales.Customers (
    CustomerID        INT             IDENTITY(1,1) PRIMARY KEY,
    AccountNumber     NVARCHAR(20)    NOT NULL UNIQUE,
    FirstName         NVARCHAR(50)    NOT NULL,
    LastName          NVARCHAR(50)    NOT NULL,
    Email             NVARCHAR(100)   NOT NULL UNIQUE,
    Phone             NVARCHAR(25)    NULL,
    City              NVARCHAR(50)    NULL,
    Country           NVARCHAR(50)    NULL DEFAULT 'USA',
    CustomerType      CHAR(1)         NOT NULL DEFAULT 'I'
                          CHECK (CustomerType IN ('I','C')),
    CreatedDate       DATETIME        NOT NULL DEFAULT GETDATE(),
    ModifiedDate      DATETIME        NOT NULL DEFAULT GETDATE()
);

-- Sales.Orders
CREATE TABLE Sales.Orders (
    OrderID           INT             IDENTITY(1000,1) PRIMARY KEY,
    CustomerID        INT             NOT NULL REFERENCES Sales.Customers(CustomerID),
    OrderDate         DATETIME        NOT NULL DEFAULT GETDATE(),
    ShipDate          DATETIME        NULL,
    Status            NVARCHAR(20)    NOT NULL DEFAULT 'Pending'
                          CHECK (Status IN ('Pending','Processing','Shipped','Delivered','Cancelled')),
    ShipToAddress     NVARCHAR(200)   NULL,
    SubTotal          DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    TaxAmount         DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    Freight           DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    TotalDue          AS (SubTotal + TaxAmount + Freight) PERSISTED,
    Comment           NVARCHAR(500)   NULL,
    ModifiedDate      DATETIME        NOT NULL DEFAULT GETDATE()
);

-- Sales.OrderItems
CREATE TABLE Sales.OrderItems (
    OrderItemID       INT             IDENTITY(1,1) PRIMARY KEY,
    OrderID           INT             NOT NULL REFERENCES Sales.Orders(OrderID),
    ProductID         INT             NOT NULL REFERENCES Production.Products(ProductID),
    Quantity          SMALLINT        NOT NULL DEFAULT 1 CHECK (Quantity > 0),
    UnitPrice         DECIMAL(10,2)   NOT NULL,
    UnitPriceDiscount DECIMAL(4,2)    NOT NULL DEFAULT 0.00,
    LineTotal         AS (Quantity * UnitPrice * (1 - UnitPriceDiscount)) PERSISTED
);

-- HumanResources.Employees
CREATE TABLE HumanResources.Employees (
    EmployeeID        INT             IDENTITY(1,1) PRIMARY KEY,
    LoginName         NVARCHAR(50)    NOT NULL UNIQUE,
    FirstName         NVARCHAR(50)    NOT NULL,
    LastName          NVARCHAR(50)    NOT NULL,
    JobTitle          NVARCHAR(100)   NOT NULL,
    Department        NVARCHAR(100)   NULL,
    HireDate          DATE            NOT NULL,
    Salary            DECIMAL(10,2)   NULL,
    ManagerID         INT             NULL REFERENCES HumanResources.Employees(EmployeeID),
    IsActive          BIT             NOT NULL DEFAULT 1,
    ModifiedDate      DATETIME        NOT NULL DEFAULT GETDATE()
);


-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IX_Orders_CustomerID    ON Sales.Orders(CustomerID);
CREATE INDEX IX_Orders_OrderDate     ON Sales.Orders(OrderDate);
CREATE INDEX IX_OrderItems_OrderID   ON Sales.OrderItems(OrderID);
CREATE INDEX IX_OrderItems_ProductID ON Sales.OrderItems(ProductID);
CREATE INDEX IX_Products_Category    ON Production.Products(Category);
CREATE INDEX IX_Customers_LastName   ON Sales.Customers(LastName);


-- ============================================================
-- SAMPLE DATA
-- ============================================================

-- Products
INSERT INTO Production.Products (ProductNumber, ProductName, Category, SubCategory, ListPrice, StockQuantity, Color)
VALUES
    ('BK-R93R-62', 'Road-150 Red, 62',        'Bikes',       'Road Bikes',     3578.27,  12, 'Red'),
    ('BK-R93R-44', 'Road-150 Red, 44',        'Bikes',       'Road Bikes',     3578.27,   8, 'Red'),
    ('BK-M68S-38', 'Mountain-200 Silver, 38', 'Bikes',       'Mountain Bikes', 2319.99,  15, 'Silver'),
    ('BK-M68S-42', 'Mountain-200 Silver, 42', 'Bikes',       'Mountain Bikes', 2319.99,  10, 'Silver'),
    ('HL-U509',    'Sport-100 Helmet, Black',  'Accessories', 'Helmets',          34.99, 200, 'Black'),
    ('HL-U509-R',  'Sport-100 Helmet, Red',    'Accessories', 'Helmets',          34.99, 175, 'Red'),
    ('SO-B909-M',  'Mountain Bike Socks, M',   'Clothing',    'Socks',             9.50, 500, 'White'),
    ('SO-B909-L',  'Mountain Bike Socks, L',   'Clothing',    'Socks',             9.50, 450, 'White'),
    ('TI-T723',    'Touring Tire',             'Components',  'Tires',            28.99, 300,  NULL),
    ('CA-7457',    'AWC Logo Cap',             'Clothing',    'Caps',              8.99, 600, 'Multi');

-- Customers
INSERT INTO Sales.Customers (AccountNumber, FirstName, LastName, Email, Phone, City, Country)
VALUES
    ('AW00011000', 'Jon',      'Yang',     'jon.yang@adventure-demo.com',     '398-555-0132', 'Bothell',   'USA'),
    ('AW00011001', 'Eugene',   'Huang',    'eugene.huang@adventure-demo.com', '747-555-0171', 'Bothell',   'USA'),
    ('AW00011002', 'Ruben',    'Torres',   'ruben.torres@adventure-demo.com', '342-555-0153', 'Bothell',   'USA'),
    ('AW00011003', 'Christy',  'Zhu',      'christy.zhu@adventure-demo.com',  '115-555-0191', 'Newton',    'USA'),
    ('AW00011004', 'Elizabeth','Johnson',  'e.johnson@adventure-demo.com',    '170-555-0127', 'Duluth',    'USA'),
    ('AW00011005', 'Julio',    'Ruiz',     'julio.ruiz@adventure-demo.com',   '805-555-0144', 'Burbank',   'USA'),
    ('AW00011006', 'Janet',    'Alvarez',  'janet.alvarez@adventure-demo.com','171-555-0130', 'Kenmore',   'USA'),
    ('AW00011007', 'Marco',    'Mzansi',   'marco.mzansi@adventure-demo.com', '913-555-0119', 'Cape Town', 'ZAF'),
    ('AW00011008', 'Rob',      'Verhoff',  'rob.verhoff@adventure-demo.com',  '150-555-0189', 'Amsterdam', 'NLD'),
    ('AW00011009', 'Shannon',  'Elliott',  's.elliott@adventure-demo.com',    '244-555-0112', 'Redmond',   'USA');

-- Employees
INSERT INTO HumanResources.Employees (LoginName, FirstName, LastName, JobTitle, Department, HireDate, Salary)
VALUES
    ('demo\kjohnson',  'Ken',     'Johnson',  'Chief Executive Officer',    'Executive',              '2010-01-15', 125000.00),
    ('demo\twhitford', 'Terri',   'Whitford', 'Vice President of Sales',    'Sales',                  '2011-03-20',  98000.00),
    ('demo\rhill',     'Roberto', 'Hill',     'Sales Manager',              'Sales',                  '2013-06-01',  72000.00),
    ('demo\sgaines',   'Sue',     'Gaines',   'Sales Representative',       'Sales',                  '2015-11-14',  52000.00),
    ('demo\jwilliams', 'James',   'Williams', 'Sales Representative',       'Sales',                  '2017-04-22',  52000.00),
    ('demo\lkim',      'Laura',   'Kim',      'Database Administrator',     'Information Technology', '2012-09-05',  89000.00);

-- Manager references
UPDATE HumanResources.Employees SET ManagerID = 1 WHERE LoginName IN ('demo\twhitford','demo\lkim');
UPDATE HumanResources.Employees SET ManagerID = 2 WHERE LoginName = 'demo\rhill';
UPDATE HumanResources.Employees SET ManagerID = 3 WHERE LoginName IN ('demo\sgaines','demo\jwilliams');

-- Orders
INSERT INTO Sales.Orders (CustomerID, OrderDate, ShipDate, Status, SubTotal, TaxAmount, Freight)
VALUES
    (1, '2026-01-05', '2026-01-08', 'Delivered',  3578.27, 286.26, 89.46),
    (2, '2026-01-12', '2026-01-15', 'Delivered',  2319.99, 185.60, 57.99),
    (3, '2026-02-03', '2026-02-06', 'Delivered',    44.49,   3.56,  5.00),
    (4, '2026-02-20', '2026-02-24', 'Delivered',  3578.27, 286.26, 89.46),
    (5, '2026-03-01',        NULL,  'Processing', 2328.98, 186.32, 58.22),
    (6, '2026-03-15',        NULL,  'Shipped',    3587.26, 286.98, 89.68),
    (7, '2026-04-01',        NULL,  'Pending',      18.49,   1.48,  5.00),
    (1, '2026-04-10',        NULL,  'Processing', 2354.97, 188.40, 58.87);

-- Order Items
INSERT INTO Sales.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
VALUES
    (1000, 1,  1, 3578.27),
    (1001, 3,  1, 2319.99),
    (1002, 5,  1,   34.99),
    (1002, 7,  1,    9.50),
    (1003, 2,  1, 3578.27),
    (1004, 4,  1, 2319.99),
    (1004, 6,  1,    9.50),
    (1005, 1,  1, 3578.27),
    (1005, 9,  1,   28.99),
    (1006, 8,  2,    9.50),
    (1007, 3,  1, 2319.99),
    (1007, 10, 1,    8.99),
    (1007, 9,  1,   28.99);

PRINT 'DBA database created successfully.';
GO
