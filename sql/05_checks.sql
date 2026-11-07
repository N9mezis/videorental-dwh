-- =====================================================================
-- ЛР2. Проверка: одинаковый ответ из 3НФ и из Data Vault, работа истории.
-- =====================================================================

-- Витрина поверх Data Vault: актуальная версия клиента
CREATE OR REPLACE VIEW rental_dv.v_customer_current AS
SELECT h.card_number, s.full_name, s.phone, s.email, s.load_date
FROM rental_dv.hub_customer h
JOIN LATERAL (SELECT * FROM rental_dv.sat_customer t WHERE t.customer_hk = h.customer_hk
              ORDER BY t.load_date DESC LIMIT 1) s ON true;

-- Отчёт «Топ-5 фильмов по числу выдач» в 3НФ
SELECT f.title, count(*) AS rentals
FROM rental_3nf.rental_item i
JOIN rental_3nf.film_copy c USING (copy_id)
JOIN rental_3nf.film f USING (film_id)
GROUP BY f.title ORDER BY rentals DESC, f.title LIMIT 5;

-- Тот же отчёт в Data Vault
SELECT s.title, count(*) AS rentals
FROM rental_dv.lnk_rental_copy rc
JOIN rental_dv.lnk_copy lc USING (copy_hk)
JOIN rental_dv.sat_film s USING (film_hk)
GROUP BY s.title ORDER BY rentals DESC, s.title LIMIT 5;

-- Выручка: 3НФ и Data Vault
SELECT (SELECT sum(amount) FROM rental_3nf.payment) AS revenue_3nf,
       (SELECT sum(amount) FROM rental_dv.sat_payment) AS revenue_dv;

-- История: клиент сменил телефон, в 3НФ старое значение теряется, а в сателлите остаётся
UPDATE rental_3nf.customer SET phone = '+7-900-000-00-14' WHERE card_number = 'C00001';
CALL rental_dv.load_all('2025-02-01 00:00:00', 'VIDEORENTAL_3NF');

SELECT phone FROM rental_3nf.customer WHERE card_number = 'C00001';

SELECT s.load_date, s.phone
FROM rental_dv.hub_customer h JOIN rental_dv.sat_customer s USING (customer_hk)
WHERE h.card_number = 'C00001' ORDER BY s.load_date;

SELECT phone FROM rental_dv.v_customer_current WHERE card_number = 'C00001';
