-- Таблица предметы в заказах

-- Посмотрим на содержимое столбцов
SELECT * FROM raw.order_items

-- Непонятно что такое order_item_id, посмотрим какие он значения принимает
SELECT
	COUNT(*),
	COUNT(order_item_id) overall_cnt,
	MAX(order_item_id) max_oi_id
FROM raw.order_items

-- Null значения отсутствуют, макс значение 21, посмотрел описание столбца на Kaggle, там сказано что этот столбец показывает последовательный порядковый номер товара
-- Поставлю тип данных SMALLINT на order_item_id

-- Проверим все остальные ключевыее столбцы order_id, product_id и seller_id
SELECT
	COUNT(*) overall_cnt,
	COUNT(order_id) order_id_cnt,
	COUNT(product_id) product_id_cnt,
	COUNT(seller_id) seller_id_cnt
FROM raw.order_items

-- NULL значения отсутствуют, т.к. все значения идентичны, проверим макс длинну полей
SELECT
	MAX(LENGTH(order_id)) length_order_id,
	MAX(LENGTH(product_id)) length_product_id,
	MAX(LENGTH(seller_id)) length_seller_id,
	MIN(LENGTH(order_id)) length_order_id,
	MIN(LENGTH(product_id)) length_product_id,
	MIN(LENGTH(seller_id)) length_seller_id
FROM raw.order_items
-- длина - 32, поэтому тип данных VARCHAR(32)

-- Глянем наличие пропусков в остальных столбцах
SELECT
	COUNT(*) overall_strings,
	COUNT(shipping_limit_date) shipping_limit_date_cnt,
	COUNT(price) price_cnt,
	COUNT(freight_value) freight_value_cnt
FROM raw.order_items
-- NULL значения отсутствуют, добавим ограничения, тип данных оставим прежним

-- Также надо добавить fk и pk, в качестве pk будет составной ключ из order_id, product_id, т.к. такой набор будет гарантировать уникальность, проверим это на всякий случай
SELECT
	COUNT(*) overall_strings,
	COUNT(DISTINCT (order_id, product_id)) unique_sets
FROM raw.order_items

-- Внезапно это не гарантирует уникальность для текущих данных, всего строк 112650 против 102425, добавление seller_id в набор не изменило ситуацию, возможно в наборе есть дубликаты

WITH ranked_order_items AS (
	SELECT
		*,
		ROW_NUMBER() OVER(PARTITION BY order_id, product_id ORDER BY order_id, product_id) rn
	FROM raw.order_items
)
SELECT * FROM ranked_order_items roi1
WHERE EXISTS (
	SELECT 1 FROM ranked_order_items roi2
	WHERE roi1.order_id = roi2.order_id
	AND roi1.product_id = roi2.product_id
	AND roi2.rn >= 2
)
ORDER BY order_id, product_id, rn DESC -- Этот запрос отыскивает все строки у которых есть больше одного дубликата по (order_id, product_id)
-- Из отчета видно, что ключевые все столбцы включая полностью повторяются, однако есть одно различие, а именно order_item_id.
-- Есть предположение, что одинаковые товары добавляются в заказ под другим порядковым номером, тогда pk должен будет стать (order_id, order_item_id)

SELECT
	*
FROM raw.order_items oi1
WHERE NOT EXISTS (
	SELECT 1
	FROM raw.order_items oi2
	WHERE oi1.order_id = oi2.order_id
	AND oi2.order_item_id < 2
) -- Отыскивает строки для которых не существует 1-го элемента в списке заказа, таких записей нет, следовательно гипотеза верна

SELECT COUNT(distinct(order_id, order_item_id)) FROM raw.order_items -- Гарантирует уникальность поэтому идея выше будет принята

-- Итоговый вариант таблицы:
CREATE TABLE silver.order_items (
order_id VARCHAR(32) NOT NULL,
order_item_id SMALLINT NOT NULL,
product_id VARCHAR(32) NOT NULL,
seller_id VARCHAR(32) NOT NULL,
shipping_limit_date TIMESTAMP NOT NULL,
price DECIMAL(10,2) NOT NULL,
freight_value DECIMAL(10,2) NOT NULL,

PRIMARY KEY (order_id, order_item_id),

CONSTRAINT fk_order_id FOREIGN KEY (order_id)
	REFERENCES silver.orders (order_id),
CONSTRAINT fk_product_id FOREIGN KEY (product_id)
	REFERENCES silver.products (product_id),
CONSTRAINT fk_seller_id FOREIGN KEY (seller_id)
	REFERENCES silver.sellers (seller_id)
);