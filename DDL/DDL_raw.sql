BEGIN;

CREATE TABLE raw.customers (
customer_id TEXT,
customer_unique_id TEXT,
customer_zip_code_prefix TEXT, -- may contain values that start with 0, if use INT then this 0 will be lost
customer_city TEXT,
customer_state TEXT
);

CREATE TABLE raw.geolocation(
geolocation_zip_code_prefix TEXT,
geolocation_lat DECIMAL(11,8), -- its a coordinate column, it as a defult contains more imformation after coma
geolocation_lng DECIMAL(11,8),
geolocation_city TEXT,
geolocation_state TEXT
);

CREATE TABLE raw.order_items(
order_id TEXT,
order_item_id INT,
product_id TEXT,
seller_id TEXT,
shipping_limit_date TIMESTAMP,
price DECIMAL(10,2),
freight_value DECIMAL(10,2)
);

CREATE TABLE raw.order_payments(
order_id TEXT,
payment_sequential INT,
payment_type TEXT,
payment_installments INT,
payment_value DECIMAL(10,2)
);

CREATE TABLE raw.order_reviews(
review_id TEXT,
order_id TEXT,
review_score INT,
review_comment_title TEXT,
review_comment_message TEXT,
review_creation_date TIMESTAMP,
review_answer_timestamp TIMESTAMP
);

CREATE TABLE raw.orders(
order_id TEXT,
customer_id TEXT,
order_status TEXT,
order_purchase_timestamp TIMESTAMP,
order_approved_at TIMESTAMP,
order_delivered_carrier_date TIMESTAMP,
order_delivered_customer_date TIMESTAMP,
order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE raw.products(
product_id TEXT,
product_category_name TEXT,
product_name_lenght INT,
product_description_lenght INT,
product_photos_qty INT,
product_weight_g DECIMAL(10,2),
product_length_cm DECIMAL(10,2),
product_height_cm DECIMAL(10,2),
product_width_cm DECIMAL(10,2) -- due to I dont know if there are any data that contains float type i prefered to do decimal (cm and g may be not integer unlike photo quantity)
);

CREATE TABLE raw.sellers(
seller_id TEXT,
seller_zip_code_prefix TEXT,
seller_city TEXT,
seller_state TEXT
);

CREATE TABLE raw.product_category_name_translation(
product_category_name TEXT,
product_category_name_english TEXT
);

END;
