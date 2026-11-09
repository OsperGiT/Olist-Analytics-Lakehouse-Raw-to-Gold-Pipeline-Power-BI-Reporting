-- Двигаемся дальше, следующая таблица geolocation, сразу же первый вопрос, что тут делать первичным ключом
-- В голову сразу приходит идея сделать первичным ключом почтовый индекс, но к одному почтовому индексу могут принадлежать несколько домов, поэтому такой вариант сразу отбрасывается
-- Тем не менее стоит проверить уникальность почтовых индексов

SELECT
	COUNT(*) overall_strings,
	COUNT(DISTINCT geolocation_zip_code_prefix) post_code_cnt
FROM raw.geolocation -- Как и ожидалось, общее количество строк превышает в 50 раз количество уникальных почтовых индексов

-- Почтовый индекс однозначно не может быть первичным ключом, что насчет уникальности набора из почтового индекса, города и штата. Мое предположение, что такой набор тоже не подойдет, потому что он все еще не уникален
SELECT
	COUNT(*) overall_strings,
	COUNT(DISTINCT (geolocation_zip_code_prefix, geolocation_city, geolocation_state)) unique_sets
FROM raw.geolocation
-- Уникальных значений больше, но по прежнему в несколько десятков раз меньше чем строк всего, единственно уникальной записью тут могут быть координаты,
-- стоит проверить количество записей в geo таблице, с количеством записей в таблице customers, чтобы определить дублируются ли записи адресов для одного и того же пользователя, но для его разных заказов

SELECT
	COUNT(*) overall_strings
FROM raw.customers

UNION ALL

SELECT
	COUNT(*)
FROM raw.geolocation

-- Количество записей в customers ~100 тыс, против ~1 млн записей в geolocation

-- Думаю надо проверить наличие дублей и null - значений
SELECT * FROM raw.geolocation
WHERE geolocation_zip_code_prefix IS NULL
	OR geolocation_lat IS NULL
	OR geolocation_lng IS NULL
	OR geolocation_city IS NULL
	OR geolocation_state IS NULL
-- Null значения отсутствуют, поставлю везде NOT NULL ограничение, в конце концов заказ не может быть без пункта назначения

-- Надо проверить дубликаты
SELECT
	COUNT(*) overall_strings,
	COUNT(DISTINCT (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state)) unique_rows
FROM raw.geolocation
-- Около 300 тысяч дубликатов, против 700 тысяч уникальных записей адресов, просмотрев еще раз аккуратно raw слой, я пришел к выводу, что ни один столбец других таблиц не ссылается на geolocation за исключением customers и sellers, надо проверить таблицу sellers

SELECT
	COUNT(*) overall_strings, COUNT(DISTINCT seller_id) overall_distinct_sellers
FROM raw.sellers
-- Всего около 3 тыс продавцов.
-- Итоговое решение принято следующее, отсекаем столбцы широты и долготы, посколько они не имеют никакой смысловой нагрузки и не могут быть корректно обработаны
-- Отсекаем дубликаты и оставляем уникальные Штат, город и почтовый индекс, таким образом будет возможность отследить примерные адреса покупателей и продавцов.

-- Ограничения для почтового индекса, города и штата будут идентичны customers таблице
-- Поскольку мы ищем соответствия 3NF, сделаем набор всех трех столбцов PK, на который будут ссылаться customers и sellers

-- Подумав и посмотрев на структуру данных у нас тут избыточность, следует добавить суррогатный ключ для таблицы geolocation дабы избежать повторяющихся данных в customers и sellers.

-- Итоговая таблица выглядит следующим образом, также поменян порядок столбцов по мере роста детализации
CREATE TABLE IF NOT EXISTS silver.geolocation(
geolocation_id INT DEFAULT GENERATED AS IDENTITY PRIMARY KEY,
geolocation_state CHAR(2) NOT NULL,
geolocation_city VARCHAR(64) NOT NULL,
geolocation_zip_code_prefix VARCHAR(9) NOT NULL,

CONSTRAINT uq_state_city_post_code_set
UNIQUE (geolocation_zip_code_prefix, geolocation_city, geolocation_state)
);

-- Стоит отредактировать поля в таблицах customers и sellers

-- Смотрю на города и вижу один и тот же город с двумя названиями различающиеся одной буквой, надо проверить что это и сколько таких городов
SELECT
	geolocation_state,
	geolocation_city
FROM raw.geolocation
GROUP BY geolocation_state, geolocation_city
ORDER BY geolocation_state, geolocation_city

-- Города отличаются буквально на один символ, также есть повторяющиеся города с лишними пробелами, надо усечь их
SELECT
	geolocation_state,
	TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g'))
FROM raw.geolocation
GROUP BY geolocation_state, TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g'))
ORDER BY geolocation_state, TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g'))

-- Нашел в интернете функцию которая позволяет заменить все диакретические знаки на латиницу
CREATE EXTENSION IF NOT EXISTS unaccent; -- включаем расширение

SELECT
	geolocation_state,
	UNACCENT(TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g'))) clear_city
FROM raw.geolocation
GROUP BY geolocation_state, UNACCENT(TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g')))
ORDER BY geolocation_state, UNACCENT(TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g')))

-- Нашел какой-то город в кубе (третья степень), надо прописать условие регулярному выражению
WITH cleared_city AS (
	SELECT
		UNACCENT(LOWER(TRIM(REGEXP_REPLACE(geolocation_city, '\s+', ' ', 'g')))) clear_city
	FROM raw.geolocation
)
SELECT * FROM cleared_city
GROUP BY clear_city
HAVING clear_city ~ $re$^[a-zA-Z .\-\']+$$re$
ORDER BY clear_city

-- Думаю такой обработки достаточно, пришлось запариться, порядок следующий:
-- убираем лишние пробелы между слов, убираем лишние пробелы до и после текста, приводим текст к единому регистру, заменяем диакретические знаки