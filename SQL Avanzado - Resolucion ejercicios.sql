-- 1.	Agregar una columna llamada �Ranking� con el ranking de ventas en funci�n del monto (SalesOrderHeader.TotalDue)
SELECT 
	SalesOrderID,
	TotalDue,
    RANK() OVER (ORDER BY TotalDue DESC) AS Ranking
FROM Sales.SalesOrderHeader;

-- 2.	Agregar una columna llamada �Ranking� por territorio con el ranking de ventas en funci�n del monto por cada territorio. 
-- Mostrar el nombre del Territorio, SalesOrderID, OrderDate, TotalDue y Ranking
SELECT 
	territorio.Name,
    soh.SalesOrderID,
    soh.OrderDate,
    soh.TotalDue,
    RANK() OVER (
		PARTITION BY soh.TerritoryID
		ORDER BY soh.TotalDue DESC
	) AS Ranking
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesTerritory territorio 
ON soh.TerritoryID = territorio.TerritoryID;

-- 3.	Agregar una columna en la tabla SalesPerson que muestre la contribuci�n de esa persona a las ventas del a�o (SalesYTD / total de SalesYTD).
-- Llamar a esta columna ContribucionVentas (notar que la suma de todas las filas de esta columna deben dar 1)
SELECT 
	BusinessEntityID,
	SalesYTD,
    SalesYTD / SUM(SalesYTD) OVER () AS ContribucionVentas
FROM Sales.SalesPerson
ORDER BY SalesYTD DESC;

-- 4.	En la tabla CurrencyRate, buscar los registros que reflejen el tipo de cambio D�lar a Euro y calcular cual fue 
-- la m�xima fluctuaci�n de un d�a a otro (considerar el AverageRate).
WITH Tabla AS(
	SELECT 
		FromCurrencyCode,
		ToCurrencyCode,
		CurrencyRateDate,
		AverageRate,
		LAG (AverageRate) OVER (
			ORDER BY CurrencyRateDate
		) AS CotizacionAyer
	FROM Sales.CurrencyRate
	WHERE FromCurrencyCode = 'USD' AND ToCurrencyCode = 'EUR'
)
SELECT TOP 1
	*,
	ABS(CotizacionAyer - AverageRate) AS Fluctuaci�n
FROM Tabla
ORDER BY ABS(CotizacionAyer - AverageRate) DESC

-- 5. Buscar las dos ventas más altas (Total Due) de cada territorio (ver tabla
-- Sales.SalesOrderHeader).

WITH ranking_cte AS (
    SELECT
        TerritoryID,
        SalesOrderID,
        OrderDate,
        TotalDue,
        RANK() OVER (
            PARTITION BY TerritoryID
            ORDER BY TotalDue DESC
        ) AS ranking
    FROM Sales.SalesOrderHeader
)
SELECT
    TerritoryID,
    TotalDue
FROM ranking_cte
WHERE ranking <= 2

-- 6.	De los dos vendedores (SalesPersonID) que hayan tenido mayor cantidad de 
-- ventas (TotalDue) en toda la historia, mostrar sus 5 ventas m�s altas. La tabla 
-- debe tener Nombre y apellido del vendedor (tabla Person), JobTitle, OrderDate y TotalDue
WITH 
	Ranking AS (
		SELECT
			SalesPersonID,
			TotalDue,
			OrderDate,
			ROW_NUMBER() OVER(
				PARTITION BY SalesPersonID
				ORDER BY TotalDue DESC
			) AS NumeroFIla
		FROM Sales.SalesOrderHeader
		WHERE SalesPersonID IN (
			SELECT TOP 2 BusinessEntityID
			FROM Sales.SalesPerson
			ORDER BY SalesYTD DESC
		)
	)
SELECT 
	FirstName,
	LastName,
	JobTitle,
	OrderDate,
	TotalDue
FROM Ranking
LEFT JOIN Person.Person
ON Ranking.SalesPersonID = Person.BusinessEntityID
LEFT JOIN HumanResources.Employee
ON Person.BusinessEntityID = Employee.BusinessEntityID
WHERE NumeroFIla <= 5

-- 7.	Mostar una tabla que tenga en las filas los territorios y en las columnas las categor�as. 
-- La misma debe contener la cantidad de unidades vendidas por cada categor�a y territorio respectivamente.

SELECT 
	territorio.Name AS Territorio,
	c.Name AS Categoria,
	SUM(detalle.OrderQty) AS Cantidad
FROM Sales.SalesOrderHeader soh
LEFT JOIN Sales.SalesTerritory territorio 
ON soh.TerritoryID = territorio.TerritoryID
LEFT JOIN Sales.SalesOrderDetail detalle 
ON soh.SalesOrderID = detalle.SalesOrderID
LEFT JOIN Production.Product producto
ON detalle.ProductID = producto.ProductID
LEFT JOIN Production.ProductSubcategory ps 
ON producto.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory c 
ON ps.ProductCategoryID = c.ProductCategoryID
GROUP BY 
	territorio.Name,
	c.Name

----------------------------------------
-- MUY DIFICILES
----------------------------------------
-- 1.	Cuales fueron los 5 productos con m�s ventas en 2012. 
-- Mostrar los 3 compradores que compraron mayor cantidad (en dinero) por cada uno de estos durante este a�o.

-- SPOILER: son las mismas 3 personas con el mismo monto
WITH 
	Productos AS(		
		SELECT TOP 5 
			ProductID
		FROM Sales.SalesOrderDetail detalle
		LEFT JOIN Sales.SalesOrderHeader ventas
		ON detalle.SalesOrderID = ventas.SalesOrderID
		WHERE YEAR(OrderDate) = 2012
		GROUP BY ProductID
		ORDER BY SUM(LineTotal) DESC
	),
	Compradores AS (
		SELECT
			detalle.ProductID,
			ventas.CustomerID,
			SUM(ventas.TotalDue) AS TotalVentas
		FROM Sales.SalesOrderDetail detalle
		LEFT JOIN Sales.SalesOrderHeader ventas
		ON detalle.SalesOrderID = ventas.SalesOrderID
		WHERE
			YEAR(OrderDate) = 2012 AND
			detalle.ProductID IN (
				SELECT ProductID
				FROM Productos
			)
		GROUP BY
			detalle.ProductID,
			ventas.CustomerID			
	)

SELECT 
	Productos.ProductID,
	CustomerID,
	TotalVentas
FROM Productos
CROSS APPLY (
	SELECT TOP 3 *
	FROM Compradores
	WHERE Compradores.ProductID = Productos.ProductID
	ORDER BY TotalVentas DESC
) tabla_cross

-- 2.	Cual es el nombre de los 5 mejores vendedores de cada territorio?
WITH Top5VendedoresPorTerritorio AS (
    SELECT TerritoryID,
           BusinessEntityID,
           ROW_NUMBER() OVER (PARTITION BY TerritoryID ORDER BY SalesYTD DESC) AS Ranking
    FROM Sales.SalesPerson
)
SELECT st.Name AS Territory,
       p.FirstName,
       p.LastName
FROM Top5VendedoresPorTerritorio tv
JOIN Person.Person p ON tv.BusinessEntityID = p.BusinessEntityID
JOIN Sales.SalesTerritory st ON tv.TerritoryID = st.TerritoryID
WHERE Ranking <= 5;

-- 3.	Cuantos productos de la categor�a bicicletas se vendieron con alg�n tipo de descuento?

SELECT SUM(OrderQty) AS Cantidad
FROM Sales.SalesOrderDetail AS detalle
LEFT JOIN Production.Product producto
ON detalle.ProductID = producto.ProductID
LEFT JOIN Production.ProductSubcategory ps 
ON producto.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory c 
ON ps.ProductCategoryID = c.ProductCategoryID
WHERE c.Name = 'Bikes' AND detalle.SpecialOfferID != 1;

-- 4.	Buscar el top 5 de clietes que hayan comprado mayor cantidad de unidades de 
-- luces (sub categor�a Lights) por:
--     a.	Cada territorio
--     b.	Cada regi�n

WITH ventas_cascos AS(
	SELECT 
		territorio.TerritoryID,
		comprador.CustomerID,
		SUM(detalle.OrderQty) AS Cantidad
	FROM Sales.SalesOrderDetail AS detalle
	LEFT JOIN Production.Product producto
	ON detalle.ProductID = producto.ProductID
	LEFT JOIN Production.ProductSubcategory ps 
	ON producto.ProductSubcategoryID = ps.ProductSubcategoryID
	LEFT JOIN Sales.SalesOrderHeader ventas 
	ON ventas.SalesOrderID = detalle.SalesOrderID
	LEFT JOIN Sales.SalesTerritory territorio 
	ON ventas.TerritoryID = territorio.TerritoryID
	LEFT JOIN Sales.Customer comprador 
	ON ventas.CustomerID = comprador.CustomerID
	WHERE ps.Name = 'Helmets'
	GROUP BY 
		territorio.TerritoryID,
		comprador.CustomerID
)
SELECT territorio.TerritoryID, territorio.Name AS Territorio, CustomerID, Cantidad
FROM Sales.SalesTerritory AS territorio
CROSS APPLY(
	SELECT TOP 5
		CustomerId,
		TerritoryID,
		Cantidad
	FROM ventas_cascos
	WHERE ventas_cascos.TerritoryID = territorio.TerritoryID
	ORDER BY Cantidad DESC
) AS ventas_cross_join
ORDER BY territorio.TerritoryID

-- 5.	Se quiere entender si hay alguna relaci�n entre el nombre del local y la 
-- cantidad de ventas. Separar los locales (stores) en dos grupos: los que contenga 
-- la palabra Bike y los que no contengan. Buscar los dos locales con mayor cantidad 
-- de ventas de bicicletas (categor�a bikes) por cada regi�n. Que porcentaje de estos 
-- contienen la palabra bike?

WITH tabla AS( 
	SELECT 
		territorio.CountryRegionCode,
		store.Name,
		CASE
			WHEN store.Name LIKE '%bike%' THEN 'contiene bici'
			else 'no contiene bici'
		END AS contiene_bici,
		detalle.OrderQty
	FROM Sales.SalesOrderDetail AS detalle
	LEFT JOIN Production.Product producto
	ON detalle.ProductID = producto.ProductID
	LEFT JOIN Production.ProductSubcategory ps 
	ON producto.ProductSubcategoryID = ps.ProductSubcategoryID
	LEFT JOIN Production.ProductCategory c 
	ON ps.ProductCategoryID = c.ProductCategoryID
	LEFT JOIN Sales.SalesOrderHeader ventas 
	ON ventas.SalesOrderID = detalle.SalesOrderID
	LEFT JOIN Sales.SalesTerritory territorio 
	ON ventas.TerritoryID = territorio.TerritoryID
	LEFT JOIN Sales.Store store
	ON ventas.SalesPersonID = store.BusinessEntityID
	WHERE c.Name = 'Bikes' AND store.Name IS NOT NULL
)
SELECT
	CountryRegionCode,
	contiene_bici,
	SUM(OrderQty) AS Cantidad
FROM Tabla
GROUP BY 
	CountryRegionCode,
	contiene_bici


-- 6.	El Scrap es el residuo en los procesos de producci�n. Cuantos productos (en cantidad de unidades) fueron scrappeados por haberse fabricado de un color incorrecto? 


-- 7.	Cuantas horas fueron dedicadas en total para fabricar los productos scrappeados por haberse fabricado de un color incorrecto (ActualResourceHrs)?


-- 8.	Cual fue el producto con mayor cantidad de unidades vendidas de las transacciones realizadas en d�lares australianos
SELECT TOP 1 
	p.Name AS Producto,
	SUM(sod.OrderQty) AS TotalUnidadesVendidas
FROM Sales.SalesOrderDetail sod
LEFT JOIN Sales.SalesOrderHeader ventas
ON sod.SalesOrderID = ventas.SalesOrderID
LEFT JOIN Production.Product p 
ON sod.ProductID = p.ProductID
LEFT JOIN Sales.CurrencyRate cr 
ON ventas.CurrencyRateID = cr.CurrencyRateID
WHERE cr.ToCurrencyCode = 'AUD'
GROUP BY p.Name
ORDER BY TotalUnidadesVendidas DESC;

-- 9.	Buscar cuales el pa�s en el que viven menos empleados
SELECT TOP 1
	CountryRegionCode,
    COUNT(*) AS TotalEmpleados
FROM Person.Address direccion
LEFT JOIN Person.StateProvince
ON direccion.StateProvinceID = StateProvince.StateProvinceID
GROUP BY CountryRegionCode
ORDER BY TotalEmpleados;

-- 10.	Buscar el id de la tarjeta que estaba m�s cerca de su vencimiento y mostrar cuantos d�as faltaban para el vencimiento. 
-- Suponer que las tarjetas vencen el �ltimo d�a del mes (posiblemente necesites usar las funciones DATEFROMPARTS, EOMONTH y DATEDIFF).
SELECT
	MIN(dias_venc)
FROM(
	SELECT 
		a.SalesOrderID,
		EOMONTH(DATEFROMPARTS(ExpYear, ExpMonth, 1)) as fecha,
		OrderDate,
		DATEDIFF(year, EOMONTH(DATEFROMPARTS(ExpYear, ExpMonth, 1)), OrderDate) as dias_venc
	FROM [AdventureWorks2022].[Sales].[SalesOrderHeader] a
	LEFT JOIN [AdventureWorks2022].[Sales].[CreditCard] b
	on a.CreditCardID = b.CreditCardID
) as d;

