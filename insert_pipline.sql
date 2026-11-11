BEGIN;

-- Вставляем уникальный набор из штата, города и почтового индекса
INSERT INTO silver.geolocation (geolocation_state, geolocation_city, geolocation_zip_code_prefix)
WITH combined_geo AS (
	SELECT
		geolocation_state,
		geolocation_city,
		geolocation_zip_code_prefix
	FROM raw.geolocation -- берем наборы адресов из сырой таблицы геолокаций

	UNION ALL

	SELECT
		customer_state,
		customer_city,
		customer_zip_code_prefix
	FROM raw.customers -- берем наборы адресов из сырой таблицы пользователей

	UNION ALL

	SELECT
		seller_state,
		seller_city,
		seller_zip_code_prefix
	FROM raw.sellers -- берем наборы адресов из сырой таблицы пользователей

	UNION ALL

	SELECT
		'UN',
		'UNKNOWN',
		'00000' -- Проблема решена: для заказов у которых некорректный адрес. Будут ссылаться на айди для битых адресов
),
prepared_geo AS (
	SELECT DISTINCT
		geolocation_state,
		UNACCENT(LOWER(TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g')))) geolocation_city,
		geolocation_zip_code_prefix
	FROM combined_geo -- Оставляем уникальные значения и чистим названия городов
)
SELECT pg.* FROM prepared_geo pg
WHERE NOT EXISTS (
		SELECT 1
		FROM silver.geolocation sg
		WHERE pg.geolocation_state = sg.geolocation_state
			AND pg.geolocation_city = sg.geolocation_city
			AND pg.geolocation_zip_code_prefix = sg.geolocation_zip_code_prefix
	) -- Делаем проверку, что такие строки не существуют в таблице silver.geolocation
	AND pg.geolocation_city ~ $re$^[a-zA-Z .\-\'\´]+$$re$ -- '
ORDER BY pg.geolocation_zip_code_prefix;

-- Вставляем пользователей и их новые id геолокаций
INSERT INTO silver.customers (customer_id, customer_unique_id, geolocation_id)
SELECT rc.customer_id, rc.customer_unique_id, COALESCE(sg.geolocation_id, 1) geolocation_id -- Коалис чтобы выдать заглушку - значение для пользователей, которые не прошли фильтрацию ранее 
FROM raw.customers rc
LEFT JOIN silver.geolocation sg
	ON sg.geolocation_state = rc.customer_state
	AND sg.geolocation_city = rc.customer_city
	AND sg.geolocation_zip_code_prefix = rc.customer_zip_code_prefix
WHERE NOT EXISTS ( -- Делаем проверку, что такие строки не существуют в таблице silver.customers
	SELECT 1
	FROM silver.customers sc
	WHERE sc.customer_id = rc.customer_id
); 

-- Вставляем статусы заказов в таблицу статусов заказов
INSERT INTO silver.order_statuses (status_name)
SELECT DISTINCT order_status FROM raw.orders ro
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.order_statuses sos
	WHERE ro.order_status = sos.status_name
);

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
JOIN silver.order_statuses sos ON sos.status_name = ro.order_status
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.orders so
	WHERE ro.order_id = so.order_id
);

-- Наполянем таблицу типов платежей
INSERT INTO silver.payment_types (payment_type)
SELECT DISTINCT payment_type FROM raw.order_payments op
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.payment_types pt
	WHERE pt.payment_type = op.payment_type
);

-- Наполняем таблицу платежей по заказам
INSERT INTO silver.order_payments (
	order_id,
	payment_sequential,
	payment_id,
	payment_installments,
	payment_value
)
SELECT
	op.order_id,
	op.payment_sequential,
	pt.payment_id,
	op.payment_installments,
	op.payment_value
FROM raw.order_payments op
JOIN silver.payment_types pt ON pt.payment_type = op.payment_type
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.order_payments sop
	WHERE op.order_id = sop.order_id
	AND op.payment_sequential = sop.payment_sequential
);

-- Наполняем таблицу продавцов
INSERT INTO silver.sellers (seller_id, geolocation_id)
WITH sellers_cleared_city AS (
	SELECT
		s.seller_id,
		seller_zip_code_prefix,
		UNACCENT(LOWER(TRIM(REGEXP_REPLACE(seller_city, '\s+', ' ', 'g')))) seller_city,
		seller_state
	FROM raw.sellers s
)
SELECT
	scc.seller_id,
	COALESCE(g.geolocation_id, 1) geolocation_id
FROM sellers_cleared_city scc 
LEFT JOIN silver.geolocation g
	ON g.geolocation_state = scc.seller_state
	AND g.geolocation_city = scc.seller_city
	AND g.geolocation_zip_code_prefix = scc.seller_zip_code_prefix
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.sellers ss
	WHERE ss.seller_id = scc.seller_id
);

-- Наполняем таблицу product_category_name
INSERT INTO silver.product_category_names (
	product_category_name,
	product_category_name_english
)
WITH prepared_categories AS (
	SELECT DISTINCT
		COALESCE(LOWER(p.product_category_name), 'not_selected_category') product_category_name,
		COALESCE(LOWER(rpcnt.product_category_name_english), 'not_translated_category') product_category_name_english
	FROM raw.products p
	LEFT JOIN raw.product_category_name_translation rpcnt
	ON rpcnt.product_category_name = p.product_category_name
)
SELECT 
	product_category_name,
	product_category_name_english
FROM prepared_categories pc
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.product_category_names spcn
	WHERE pc.product_category_name = spcn.product_category_name
		AND pc.product_category_name_english = spcn.product_category_name_english
);

-- Наполняем таблицу products
INSERT INTO silver.products (
	product_id,
	product_category_id,
	product_name_length,
	product_description_length,
	product_photos_qty,
	product_weight_g,
	product_length_cm,
	product_height_cm,
	product_width_cm
)
SELECT
	rp.product_id,
	spcn.product_category_id,
	rp.product_name_lenght,
	rp.product_description_lenght,
	rp.product_photos_qty,
	rp.product_weight_g,
	rp.product_length_cm,
	rp.product_height_cm,
	rp.product_width_cm
FROM raw.products rp
JOIN silver.product_category_names spcn
	ON spcn.product_category_name = COALESCE(LOWER(rp.product_category_name), 'not_selected_category')
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.products sp
	WHERE rp.product_id = sp.product_id
);

-- Наполняем таблицу продуктов заказов
INSERT INTO silver.order_items(
	order_id,
	order_item_id,
	product_id,
	seller_id,
	shipping_limit_date,
	price,
	freight_value
)
SELECT
	order_id,
	order_item_id,
	product_id,
	seller_id,
	shipping_limit_date,
	price,
	freight_value
FROM raw.order_items roi
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.order_items soi
	WHERE roi.order_id = soi.order_id 
		AND roi.order_item_id = soi.order_item_id
);

-- Наполняем таблицу отзывов к заказам
INSERT INTO silver.order_reviews (
	review_id,
	order_id,
	review_score,
	review_comment_title,
	review_comment_message,
	review_creation_date,
	review_answer_timestamp
)
SELECT
	review_id,
	order_id,
	review_score,
	review_comment_title,
	review_comment_message,
	review_creation_date,
	review_answer_timestamp
FROM raw.order_reviews ror
WHERE NOT EXISTS (
	SELECT 1
	FROM silver.order_reviews sor
	WHERE ror.review_id = sor.review_id
		AND ror.order_id = sor.order_id
);

END;