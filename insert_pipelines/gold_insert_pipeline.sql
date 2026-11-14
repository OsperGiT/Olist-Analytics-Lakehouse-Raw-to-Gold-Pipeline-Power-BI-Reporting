BEGIN;

-- Наполняем измерение - таблицу продуктов
INSERT INTO gold.dim_products (
	product_id,
	product_category_original_name,
	product_category_english_name,
	product_name_length,
	product_description_length,
	product_photos_qty,
	product_weight_g,
	product_length_cm,
	product_height_cm,
	product_width_cm
)
SELECT
	p.product_id,
	pcn.product_category_name,
	pcn.product_category_name_english,
	p.product_name_length,
	p.product_description_length,
	p.product_photos_qty,
	p.product_weight_g, 
	p.product_length_cm,
	p.product_height_cm,
	p.product_width_cm
FROM silver.products p
JOIN silver.product_category_names pcn
	ON p.product_category_id = pcn.product_category_id
WHERE NOT EXISTS (
	SELECT 1 FROM gold.dim_products p2
	WHERE p2.product_id = p.product_id
);

-- Наполняем измерение - таблицу продавцов
INSERT INTO gold.dim_sellers (
	seller_id,
	seller_state,
	seller_city,
	seller_zip_code_prefix
)
SELECT
	s.seller_id,
	g.geolocation_state,
	g.geolocation_city,
	g.geolocation_zip_code_prefix
FROM silver.sellers s
JOIN silver.geolocation g ON g.geolocation_id = s.geolocation_id
WHERE NOT EXISTS (
	SELECT 1 FROM gold.dim_sellers s2
	WHERE s2.seller_id = s.seller_id
);

-- Наполняем измерение - таблицу заказов
INSERT INTO gold.dim_orders (
	order_id,
	status_type,
	order_purchase_timestamp,
	order_approved_at,
	order_delivered_carrier_date,
	order_delivered_customer_date,
	order_estimated_delivery_date
)
SELECT
	o.order_id,
	os.status_name,
	o.order_purchase_timestamp,
	o.order_approved_at,
	o.order_delivered_carrier_date,
	o.order_delivered_customer_date,
	o.order_estimated_delivery_date
FROM silver.orders o
JOIN silver.order_statuses os
	ON os.status_id = o.status_id
WHERE NOT EXISTS (
	SELECT 1 FROM gold.dim_orders o2
	WHERE o2.order_id = o.order_id
);

-- Наполняем таблицу - измерение пользователей 
INSERT INTO gold.dim_customers (
	customer_id,
	customer_unique_id,
	customer_state,
	customer_city,
	customer_zip_code_prefix
)
SELECT
	c.customer_id,
	c.customer_unique_id,
	g.geolocation_state,
	g.geolocation_city,
	g.geolocation_zip_code_prefix
FROM silver.customers c
JOIN silver.geolocation g ON g.geolocation_id = c.geolocation_id
WHERE NOT EXISTS (
	SELECT 1 FROM gold.dim_customers c2
	WHERE c.customer_id = c2.customer_id
);

-- Наполняем фактическую таблицу отзывов на заказы (Бизнес-процесс обратной связи)
INSERT INTO gold.fact_order_reviews (
	review_id,
	order_id,
	customer_id,
	review_score,
	review_comment_title,
	review_comment_message,
	review_creation_date,
	review_answer_timestamp
)
SELECT
	sor.review_id,
	sor.order_id,
	o.customer_id,
	sor.review_score,
	sor.review_comment_title,
	sor.review_comment_message,
	sor.review_creation_date,
	sor.review_answer_timestamp
FROM silver.order_reviews sor
JOIN silver.orders o ON o.order_id = sor.order_id
WHERE NOT EXISTS (
	SELECT 1 FROM gold.fact_order_reviews gfor
	WHERE sor.review_id = gfor.review_id
		AND sor.order_id = gfor.order_id
);

-- Наполняем фактическую таблицу оплата заказов (Транзакционный бизнес-процесс)
INSERT INTO gold.fact_order_payments (
	order_id,
	payment_sequential,
	customer_id,
	payment_type,
	payment_installments,
	payment_value
)
SELECT
	op.order_id,
	op.payment_sequential,
	o.customer_id,
	pt.payment_type,
	op.payment_installments,
	op.payment_value
FROM silver.order_payments op
JOIN silver.payment_types pt ON pt.payment_id = op.payment_id
JOIN silver.orders o ON o.order_id = op.order_id
WHERE NOT EXISTS (
	SELECT 1 FROM gold.fact_order_payments fop
	WHERE fop.order_id = op.order_id
		AND fop.payment_sequential = op.payment_sequential
);

-- Наполняем фактическую таблицу заказов и содержащихся в них предметов
INSERT INTO gold.fact_order_items (
	order_id,
	order_item_id,
	product_id,
	customer_id,
	seller_id,
	shipping_limit_date,
	price,
	freight_value
)
SELECT
	oi.order_id,
	oi.order_item_id,
	oi.product_id,
	o.customer_id,
	oi.seller_id,
	oi.shipping_limit_date,
	oi.price,
	oi.freight_value
FROM silver.order_items oi
JOIN silver.orders o ON o.order_id = oi.order_id
WHERE NOT EXISTS (
	SELECT 1 FROM gold.fact_order_items foi
	WHERE oi.order_id = foi.order_id
		AND oi.order_item_id = foi.order_item_id
);

END;