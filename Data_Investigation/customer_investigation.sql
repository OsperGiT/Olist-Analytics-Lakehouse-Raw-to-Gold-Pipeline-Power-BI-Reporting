-- Начнем по порядку со стола customers, стоит проверить customer_id и customer_unique_id, что их значения ограничиваются 32 символами
SElECT
	MAX(LENGTH(customer_id)) max_chars_c_id,
	MAX(LENGTH(customer_unique_id)) max_chars_cu_id
FROM raw.customers -- Для обоих столбцов установлю VARCHAR(32)

-- Посмотрим максимальную длину почтвого индекса и сравним его с тем какую информацию нам даст интернет
SELECT MAX(LENGTH(customer_zip_code_prefix)) FROM raw.customers
-- Получилось 5, однако в интернете нам общеают максимум до 9 символов c учетом дефиса (-), посмотрю как вглядят индексы тут

SELECT customer_zip_code_prefix FROM raw.customers
-- Поскольку могут быть индексы, которые начинаются с нуля я не буду использовать INT, а поставлю VARCHAR(9), который позволит избежать несостыковки данных в дальнейшем

-- Также проверю максимальную длинну столбцов customer_city и customer_state
SELECT
	MAX(LENGTH(customer_city)) max_length_c_city,
	MAX(LENGTH(customer_state)) max_length_c_state
FROM raw.customers
-- Получилось 32 и 2, очевидно что название города в теории может быть больше, поэтому VARCHAR(64) будет достаточно с запасом, а штат обозначается только двумя символами, что подтверждается поиском в интернете, поэтому правильным будет поставить значение CHAR(2)

-- Надо разобраться далее с pk, т.к. не ясно что вообще брать за основу customer_id или customer_unique_id.
SELECT
	COUNT(*) overall_strings,
	COUNT(DISTINCT customer_id) d_customer_ids,
	COUNT(DISTINCT customer_unique_id) d_customer_unique_ids
FROM raw.customers
-- Отчет показал, что общее количество строк полностью совпадает с количенством customer_id, и не совпадает с количеством уникальных пользователей
-- Отсюда следующий вывод: customer_id уникальный идентификатор всех строк по которому будет соединяться таблица с заказами, однако возникает следующий вопрос: стоит ли делать только customer_id первичным ключом или сделать составной вместе customer_unique_id
-- Постольку поскольку один пользователь может для разных заказов указать разные адреса, получается что все поля будут зависимы только от уникального заказа т.е. от customer_id, что удовлетворяет и 2NF и 3NF. Первичный ключ - customer_id.

-- Еще стоит исследовать наличие NULL значений в остальных полях
SELECT * FROM raw.customers
WHERE customer_zip_code_prefix IS NULL
	OR customer_city IS NULL
	OR customer_state IS NULL
-- вывелось 0 строк, значит можно ставить ограничение NOT NULL

-- Заменим почтовый индекс, город и штат, на один fk который будет ссылаться на geolocation таблицу

-- Итоговый результат таблицы customers
CREATE TABLE IF NOT EXISTS silver.customers (
customer_id VARCHAR(32) PRIMARY KEY,
customer_unique_id VARCHAR(32) NOT NULL,
geolocation_id INT NOT NULL,

CONSTRAINT fk_geolocation_id
FOREIGN KEY (geolocation_id)
REFERENCES silver.geolocation(geolocation_id)
);