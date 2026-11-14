-- Проектировать буду архитектуру типа звезда. Сначала выбрем бизнес-процесс для анализа, а именно продажи
-- В качестве наиболее подходящей таблицы под этот бизнес процесс, в качестве фактической таблицы будет выбрана order_items
-- Одна запись содержит информацию по продаже товара в заказе, с его ценой и ценой доставки.

BEGIN;

CREATE SCHEMA IF NOT EXISTS gold;

-- 1. Таблица - измерение - заказы
CREATE TABLE IF NOT EXISTS gold.dim_orders(
order_id VARCHAR(32) NOT NULL PRIMARY KEY,
-- Удаляем поле покупателей
status_type VARCHAR(32) NOT NULL, -- Денормализуем таблицу order_statuses, добавляя этот атрибут в основную таблицу - измерение
order_purchase_timestamp TIMESTAMP NOT NULL,
order_approved_at TIMESTAMP,
order_delivered_carrier_date TIMESTAMP,
order_delivered_customer_date TIMESTAMP,
order_estimated_delivery_date TIMESTAMP NOT NULL
);

-- 2. Таблица - измерение - покупатели
CREATE TABLE IF NOT EXISTS gold.dim_customers (
customer_id VARCHAR(32) PRIMARY KEY,
customer_unique_id VARCHAR(32) NOT NULL,
customer_state CHAR(2) NOT NULL, -- Денормализуем таблицу geolocation, разъединив ее между customers и sellers
customer_city VARCHAR(64) NOT NULL,
customer_zip_code_prefix VARCHAR(9) NOT NULL
);

-- 3. Таблица - измерение - продавцы
CREATE TABLE IF NOT EXISTS gold.dim_sellers (
seller_id VARCHAR(32) PRIMARY KEY,
seller_state CHAR(2) NOT NULL, -- Денормализуем таблицу geolocation, разъединив ее между customers и sellers
seller_city VARCHAR(64) NOT NULL,
seller_zip_code_prefix VARCHAR(9) NOT NULL
);

-- 4. Таблица - измерение - продукты
CREATE TABLE IF NOT EXISTS gold.dim_products(
product_id VARCHAR(32) PRIMARY KEY,
product_category_original_name VARCHAR(128) NOT NULL, -- Денормализуем таблицу product_category_name
product_category_english_name VARCHAR(128) NOT NULL, -- Денормализуем таблицу product_category_name
product_name_length SMALLINT,
product_description_length INT,
product_photos_qty SMALLINT,
product_weight_g DECIMAL(10,2), -- до 99 тон вес допустимый, с головой хватит
product_length_cm DECIMAL(10,2),
product_height_cm DECIMAL(10,2),
product_width_cm DECIMAL(10,2)
);

-- 5. Фактическая таблица - продукты в заказах
CREATE TABLE IF NOT EXISTS gold.fact_order_items (
order_id VARCHAR(32) NOT NULL,
order_item_id SMALLINT NOT NULL,
product_id VARCHAR(32) NOT NULL,
customer_id VARCHAR(32) NOT NULL, -- Добавляем ссылку на покупателя
seller_id VARCHAR(32) NOT NULL,
shipping_limit_date TIMESTAMP NOT NULL,
price DECIMAL(10,2) NOT NULL,
freight_value DECIMAL(10,2) NOT NULL,

PRIMARY KEY (order_id, order_item_id),

CONSTRAINT fk_order_id FOREIGN KEY (order_id)
	REFERENCES gold.dim_orders (order_id),
CONSTRAINT fk_product_id FOREIGN KEY (product_id)
	REFERENCES gold.dim_products (product_id),
CONSTRAINT fk_customer_id FOREIGN KEY (customer_id)
	REFERENCES gold.dim_customers (customer_id),
CONSTRAINT fk_seller_id FOREIGN KEY (seller_id)
	REFERENCES gold.dim_sellers (seller_id)
);

-- 6. Фактическая таблица - оплаты заказов, отвечает за бизнес-процесс - транзакция
CREATE TABLE IF NOT EXISTS gold.fact_order_payments(
order_id VARCHAR(32) NOT NULL,
payment_sequential SMALLINT NOT NULL,
customer_id VARCHAR(32) NOT NULL, -- добавляем ссылку на покупателя
payment_type VARCHAR(64) NOT NULL, -- Денормализуем таблицу payment_types
payment_installments SMALLINT NOT NULL,
payment_value DECIMAL(10,2) NOT NULL,

PRIMARY KEY (order_id, payment_sequential),

CONSTRAINT fk_order_id FOREIGN KEY (order_id)
	REFERENCES gold.dim_orders (order_id),
CONSTRAINT fk_customer_id FOREIGN KEY (customer_id)
	REFERENCES gold.dim_customers (customer_id)
);

-- 7. Фактическая таблица - отзывы к заказам, отвечает за бизнес-процесс "Обратная связь"
CREATE TABLE IF NOT EXISTS gold.fact_order_reviews(
review_id VARCHAR(32) NOT NULL,
order_id VARCHAR(32) NOT NULL,
customer_id VARCHAR(32) NOT NULL, -- добавляем ссылку на покупателя
review_score SMALLINT CHECK (review_score > 0 AND review_score <= 5) NOT NULL,
review_comment_title VARCHAR(64),
review_comment_message TEXT,
review_creation_date TIMESTAMP,
review_answer_timestamp TIMESTAMP NOT NULL,

PRIMARY KEY (review_id, order_id),

CONSTRAINT fk_order_id FOREIGN KEY (order_id)
	REFERENCES gold.dim_orders (order_id),
CONSTRAINT fk_customer_id FOREIGN KEY (customer_id)
	REFERENCES gold.dim_customers (customer_id)
);

END;

