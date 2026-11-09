-- Табилица продавцов
SELECT * FROM raw.sellers

SELECT
	MAX(LENGTH(seller_id)) max_len_seller_id,
	MIN(LENGTH(seller_id)) min_len_seller_id,
	COUNT(*) overall_strings,
	COUNT(DISTINCT seller_id) seller_id_cnt,
	COUNT(seller_zip_code_prefix),
	COUNT(seller_city),
	COUNT(seller_state) 
FROM raw.sellers
-- id сделаем варчар 32 и pk, null_значений нет
-- Значит спокойно удаляем все столбцы, и делаем одну ссылку на геолокацию, которая уже сущесвтует и была создана ранее


CREATE TABLE silver.sellers(
seller_id VARCHAR(32) PRIMARY KEY,
geolocation_id INT NOT NULL,

CONSTRAINT fk_geolocation_id FOREIGN KEY (geolocation_id)
	REFERENCES silver.geolocation (geolocation_id)
);