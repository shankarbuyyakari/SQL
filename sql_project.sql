create database project;
use project;

create table sales as( select * from factinternetsales union select * from fact_internet_sales_new);
-- product -- productsubcat --productsubcatkey
-- productsubcat -- productcat --prductcatkey
-- product p, productcat pc, productsubcat psc
alter table dimproductsubcategory rename column ï»¿ProductSubcategoryKey to ProductSubcatKey;
-- alter table dimproductcategory change column ï»¿ProductCategoryKey ProductCategoryKey int;
alter table dimproductcategory rename column ï»¿ProductCategoryKey to ProductCatKey;

describe dimproduct;
create table products as(
select p.*, psc.ProductSubcatKey, psc.EnglishProductSubcategoryName as Subcategory_Name, pc.ProductCatKey, pc.EnglishProductCategoryName as Cat_Name
from dimproduct as p 
left join dimproductsubcategory as psc on p.ProductSubcategoryKey = psc.ProductSubcatKey 
left join dimproductcategory as pc on psc.ProductCategoryKey=pc.ProductCatKey);

-- add Columns to date table dimdate
alter table dimdate change ï»¿DateKey OrderDate date;

alter table dimdate 
add column yearcol int, 
add column monthcol int, 
add column monthnamecol varchar(15), 
add column quartercol varchar(5), 
add column weekcol int, 
add column daynamecol varchar(10), 
add column YearMonth varchar(20);

set sql_safe_updates=0;
update dimdate set yearcol =year(orderdate), monthcol=month(orderdate), monthnamecol=monthname(orderdate), quartercol=quarter(orderdate), weekcol=week(orderdate), daynamecol=dayname(orderdate), YearMonth=date_format(orderdate,'%Y-%M');

-- add salesamount, Prod_cost, Profit column in sales table
alter table sales 
add column Sales_Amount int,
add column Prod_cost int,
add column Profit int;

update sales set Sales_Amount=UnitPrice*OrderQuantity, Prod_cost=ProductStandardCost*OrderQuantity, Profit=Sales_Amount-Prod_cost;

-- kpis -- total sales, total profit, totalprodcost, total orders, total customers, profit_margin
select concat(round(sum(Sales_Amount)/1000000,2), ' M') as TotalSales, 
concat(round(sum(Prod_cost)/1000000,2),' M') as TotalProductionCost, 
concat(round(sum(Profit)/1000000,2),' M') as TotalProfit, 
count(*) as Total_orders, 
sum(profit)/sum(sales_amount)*100 as ProfitMargin from sales;
select count(*) as Total_customers from dimcustomer;

-- salesTerritoryCountry wise sales, order sales in descending order
select SalesTerritoryCountry, sum(Sales_Amount) as Total_Sales from dimsalesterritory as T Join sales as S on T.ï»¿SalesTerritoryKey=S.SalesTerritoryKey 
group by 1 order by 2;

-- Retrieve the SalesOrderNumber, SalesAmount, and Profit for all sales
-- made in the year 2012 where the profit was greater than 1000
select SalesOrderNumber, sum(Sales_Amount) as Total_sales, sum(Profit) as total_profit from sales
where year(OrderDateKey)=2012 group by SalesOrderNumber having sum(Profit)>1000;
-- retrieve highest selling category name along with its sales
select Cat_Name, sum(Sales_Amount) as Total_sales from products as p join sales as s on p.ï»¿ProductKey=s.ï»¿ProductKey 
group by 1 
order by 2 Desc 
limit 1;
-- Top 10 cutomers customerFullName based on number of orders placed
select concat_ws(" ",FirstName,MiddleName,LastName), count(OrderQuantity) as full_name from dimcustomer as d join sales as s on d.ï»¿CustomerKey=s.CustomerKey 
group by 1 order by 2 desc limit 10;
-- monthName wise sales - order the date by month name
select monthname(OrderDateKey), sum(Sales_Amount) from sales group by 1 order by 1 desc;
-- create a stored procedure to retrieve Top N products in Every product category based on sales
with cte as (select Cat_Name, sum(Sales_Amount) from products as p join sales as s on p.ï»¿ProductKey=s.ï»¿ProductKey group by 1) select Cat_Name from cte;
-- create a view and store in it -- Year wise sales, along with it retrieve  last year sales and 
-- find the sales change from last year to this year
drop view if exists yearwise_sales_change;

CREATE VIEW yearwise_sales_change AS
SELECT 
    year,
    total_sales,
    LAG(total_sales, 1) OVER (ORDER BY year) AS last_year_sales,
    total_sales - LAG(total_sales, 1) OVER (ORDER BY year) AS sales_change
FROM (
    SELECT 
        YEAR(OrderDateKey) AS year,
        SUM(sales_amount) AS total_sales
    FROM sales
    GROUP BY YEAR(OrderDateKey)
) AS yearly_sales;

select * from yearwise_sales_change;
-- create and index for the sales_amouunt column to retrieve data faster
CREATE INDEX idx_sales_amount
ON sales(sales_amount);
select sum(Sales_Amount) from sales;