-- Отзывы к заказам

SELECT * FROM raw.order_reviews

SELECT
	MIN(LENGTH(review_id)) min_len_review_id,
	MAX(LENGTH(review_id)) max_len_review_id,
	MIN(LENGTH(order_id)) min_len_order_id,
	MAX(LENGTH(order_id)) max_len_order_id,
	MAX(review_score) max_review_score,
	MAX(LENGTH(review_comment_message)) max_len_rev_com_mes,
	COUNT(*) overall_strings,
	COUNT(review_id) review_id_cnt,
	COUNT(order_id) order_id_cnt,
	COUNT(review_creation_date) review_creation_date_cnt,
	COUNT(review_creation_date) review_answer_date_cnt
FROM raw.order_reviews

-- id поля - varchar(32), добавим chech для поле review_score, поле для отзыва либо оставить текст, либо сделать большой VARCHAR, тип времени создания и ответа оставляем прежним, null значений нет

SELECT DISTINCT review_score FROM raw.order_reviews -- проверю что других значений нет, NULL значений тоже нет

SELECT DISTINCT review_comment_title FROM raw.order_reviews -- гляну нет ли тут определенных типов заголовков
SELECT MAX(LENGTH(review_comment_title)) FROM raw.order_reviews -- Максимальная длинна 26, поставлю варчар 64

-- Стоит подумать что взять за PK глянем уникальность order_id, возможно, что на один заказ можно оставить больше одного отзыва

SELECT
	COUNT(*) overall_strings,
	COUNT(DISTINCT order_id) order_id_cnt,
	COUNT(DISTINCT review_id) review_id_cnt,
	COUNT(DISTINCT (order_id, review_id)) order_review_id_cnt
FROM raw.order_reviews -- Уникальным значением тут будет только пара order_reveiw_id_cnt

-- Хочу глянуть почему повторяется review_id и order_id
WITH ranked_order_reviews AS (
	SELECT *,
		ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY order_id) order_id_rn,
		ROW_NUMBER() OVER(PARTITION BY review_id ORDER BY review_id) review_id_rn
	FROM raw.order_reviews
),
order_id_dublicates AS (
	SELECT * FROM ranked_order_reviews ror1
	WHERE EXISTS (
		SELECT 1 FROM ranked_order_reviews ror2
		WHERE ror1.order_id = ror2.order_id
		AND ror2.order_id_rn >= 2
	)
	ORDER BY order_id -- Судя по датасету, review_creation_date это дата, когда был отправлен опрос пользователю об удовлетворенности покупкой, а review_answer_timestamp - дата когда ответ получен.
	-- Получается потребителю могли отсылать повторные опросы спустя какое-то время. В таком случае понятно откуда берутся два отзыва на один заказ, однако стоит проверить откуда берется два одинаковых отзыва.
),
review_id_dublicates AS (
	SELECT * FROM ranked_order_reviews ror1
	WHERE EXISTS (
		SELECT 1 FROM ranked_order_reviews ror2
		WHERE ror1.review_id = ror2.review_id
		AND ror2.review_id_rn >= 2
	)
	ORDER BY review_id, review_id_rn
)
SELECT * FROM review_id_dublicates
-- Действительно один отзыв на несколько товаров, в теории это возможно только если пользователь сделал несколько заказов и опрос отправили ему сразу по всем трем, потому что даты создания опроса и ответа идентичны для всех заказов
-- Тогда pk это составной ключ из айди отзыва и заказа

CREATE TABLE silver.order_reviews(
review_id VARCHAR(32) NOT NULL,
order_id VARCHAR(32) NOT NULL,
review_score SMALLINT CHECK (review_score > 0 AND review_score <= 5) NOT NULL,
review_comment_title VARCHAR(64) NOT NULL,
review_comment_message TEXT,
review_creation_date TIMESTAMP,
review_answer_timestamp TIMESTAMP NOT NULL,

PRIMARY KEY (review_id, order_id),

CONSTRAINT fk_order_id FOREIGN KEY (order_id)
	REFERENCES silver.orders (order_id)
);