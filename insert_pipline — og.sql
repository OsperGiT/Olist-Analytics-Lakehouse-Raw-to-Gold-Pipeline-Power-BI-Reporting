BEGIN;

-- Вставляем уникальный набор из штата, города и почтового индекса
INSERT INTO silver.geolocation (geolocation_state, geolocation_city, geolocation_zip_code_prefix)
WITH cleared_city AS (
	SELECT
		geolocation_state,
		UNACCENT(LOWER(TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g')))) clear_city,
		geolocation_zip_code_prefix
	FROM raw.geolocation
)
SELECT DISTINCT * FROM cleared_city
WHERE clear_city ~ $re$^[a-zA-Z .\-\']+$$re$; -- '

-- Вставляем уникальный набор из штата, города и почтового индекса которых не было изначально в таблице, но они существовали у покупателей
INSERT INTO silver.geolocation (geolocation_state, geolocation_city, geolocation_zip_code_prefix)
SELECT DISTINCT rc.customer_state, rc.customer_city, rc.customer_zip_code_prefix
FROM raw.customers rc
LEFT JOIN silver.geolocation sg ON sg.geolocation_state = rc.customer_state
	AND sg.geolocation_city = rc.customer_city
	AND sg.geolocation_zip_code_prefix = rc.customer_zip_code_prefix
WHERE sg.geolocation_zip_code_prefix IS NULL
	AND sg.geolocation_city IS NULL
	AND sg.geolocation_state IS NULL
	AND rc.customer_city ~ $re$^[a-zA-Z .\-\']+$$re$; -- '

-- Вставляем пользователей и их новые id геолокаций
INSERT INTO silver.customers (customer_id, customer_unique_id, geolocation_id)
SELECT customer_id, customer_unique_id, sg.geolocation_id
FROM raw.customers rc
JOIN silver.geolocation sg ON sg.geolocation_state = rc.customer_state
	AND sg.geolocation_city = rc.customer_city
	AND sg.geolocation_zip_code_prefix = rc.customer_zip_code_prefix;

-- Вставляем статусы заказов в таблицу статусов заказов
INSERT INTO silver.order_statuses (status_name)
SELECT DISTINCT order_status FROM raw.orders

-- Вставляем сами заказы и их новые ссылки на статусы
INSERT INTO silver.orders (
	order_id,
	customer_id,
	status_id,
	order_purchase_timestamp,
	order_approved_at,
	order_delivered_carrier_date,
	order_delivered_customer_date,
	order_estimated_delivery_date)
SELECT
	ro.order_id,
	ro.customer_id,
	sos.status_id,
	ro.order_purchase_timestamp,
	ro.order_approved_at,
	ro.order_delivered_carrier_date,
	ro.order_delivered_customer_date,
	ro.order_estimated_delivery_date
FROM raw.orders ro
JOIN silver.order_statuses sos ON sos.status_name = ro.order_status -- отсутствует пользователь в основной таблице, была сделана проверка, этот пользователь был отсеян ввиду неправильно указанного адреса с кривыми символами
WHERE ro.customer_id != '94ea98eea015faad90cd64998848d18d' -- выкидываем этого пользователя из выборки

END;