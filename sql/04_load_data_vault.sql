-- =====================================================================
-- ЛР2. Загрузка Data Vault из 3НФ (ETL): хабы -> ссылки -> сателлиты.
-- Повторный запуск безопасен: хабы и ссылки вставляются через ON CONFLICT DO NOTHING,
-- а новая версия сателлита появляется, только если изменился hash_diff.
-- =====================================================================
SET search_path TO rental_dv, rental_3nf;

CREATE OR REPLACE FUNCTION rental_dv.hk(VARIADIC parts TEXT[]) RETURNS CHAR(32)
LANGUAGE sql IMMUTABLE AS $$ SELECT md5(upper(array_to_string(parts, '||'))) $$;

CREATE OR REPLACE PROCEDURE rental_dv.load_all(p_load TIMESTAMP, p_src VARCHAR)
LANGUAGE plpgsql
-- search_path закреплён: иначе процедура зависит от настроек вызывающей сессии
SET search_path = rental_dv, rental_3nf
AS $$
BEGIN
    -- Хабы
    INSERT INTO hub_film SELECT hk(film_code), p_load, p_src, film_code FROM film ON CONFLICT DO NOTHING;
    INSERT INTO hub_genre SELECT hk(name), p_load, p_src, name FROM genre ON CONFLICT DO NOTHING;
    INSERT INTO hub_person SELECT hk(full_name), p_load, p_src, full_name
        FROM (SELECT full_name FROM director UNION SELECT full_name FROM actor) p ON CONFLICT DO NOTHING;
    INSERT INTO hub_format SELECT hk(name), p_load, p_src, name FROM media_format ON CONFLICT DO NOTHING;
    INSERT INTO hub_copy SELECT hk(inventory_code), p_load, p_src, inventory_code FROM film_copy ON CONFLICT DO NOTHING;
    INSERT INTO hub_customer SELECT hk(card_number), p_load, p_src, card_number FROM customer ON CONFLICT DO NOTHING;
    INSERT INTO hub_employee SELECT hk(personnel_no), p_load, p_src, personnel_no FROM employee ON CONFLICT DO NOTHING;
    INSERT INTO hub_rental SELECT hk(rental_number), p_load, p_src, rental_number FROM rental ON CONFLICT DO NOTHING;
    INSERT INTO hub_payment SELECT hk(payment_number), p_load, p_src, payment_number FROM payment ON CONFLICT DO NOTHING;

    -- Ссылки
    INSERT INTO lnk_film_genre
    SELECT hk(f.film_code, g.name), p_load, p_src, hk(f.film_code), hk(g.name)
    FROM film_genre fg JOIN film f USING (film_id) JOIN genre g USING (genre_id) ON CONFLICT DO NOTHING;

    INSERT INTO lnk_film_person
    SELECT hk(f.film_code, d.full_name, 'director'), p_load, p_src, hk(f.film_code), hk(d.full_name), 'director'
    FROM film f JOIN director d USING (director_id) ON CONFLICT DO NOTHING;
    INSERT INTO lnk_film_person
    SELECT hk(f.film_code, a.full_name, 'actor'), p_load, p_src, hk(f.film_code), hk(a.full_name), 'actor'
    FROM film_actor fa JOIN film f USING (film_id) JOIN actor a USING (actor_id) ON CONFLICT DO NOTHING;

    INSERT INTO lnk_copy
    SELECT hk(c.inventory_code, f.film_code, m.name), p_load, p_src, hk(c.inventory_code), hk(f.film_code), hk(m.name)
    FROM film_copy c JOIN film f USING (film_id) JOIN media_format m USING (format_id) ON CONFLICT DO NOTHING;

    INSERT INTO lnk_rental
    SELECT hk(r.rental_number, c.card_number, e.personnel_no), p_load, p_src, hk(r.rental_number), hk(c.card_number), hk(e.personnel_no)
    FROM rental r JOIN customer c USING (customer_id) JOIN employee e USING (employee_id) ON CONFLICT DO NOTHING;

    INSERT INTO lnk_rental_copy
    SELECT hk(r.rental_number, c.inventory_code), p_load, p_src, hk(r.rental_number), hk(c.inventory_code)
    FROM rental_item i JOIN rental r USING (rental_id) JOIN film_copy c USING (copy_id) ON CONFLICT DO NOTHING;

    INSERT INTO lnk_payment_rental
    SELECT hk(p.payment_number, r.rental_number), p_load, p_src, hk(p.payment_number), hk(r.rental_number)
    FROM payment p JOIN rental r USING (rental_id) ON CONFLICT DO NOTHING;

    -- Сателлиты: только новые версии
    INSERT INTO sat_film
    SELECT s.k, p_load, p_src, s.d, s.title, s.release_year, s.duration_min, s.age_rating
    FROM (SELECT hk(film_code) k, md5(concat_ws('|', title, release_year, duration_min, age_rating)) d, * FROM film) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_film t WHERE t.film_hk = s.k ORDER BY load_date DESC LIMIT 1);

    INSERT INTO sat_person
    SELECT s.k, p_load, p_src, s.d, s.country
    FROM (SELECT hk(full_name) k, md5(coalesce(country, '')) d, country FROM director) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_person t WHERE t.person_hk = s.k ORDER BY load_date DESC LIMIT 1);

    INSERT INTO sat_format_tariff
    SELECT s.k, p_load, p_src, s.d, s.price_per_day, s.late_fee
    FROM (SELECT hk(name) k, md5(concat_ws('|', price_per_day, late_fee)) d, * FROM media_format) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_format_tariff t WHERE t.format_hk = s.k ORDER BY load_date DESC LIMIT 1);

    INSERT INTO sat_copy
    SELECT s.k, p_load, p_src, s.d, s.purchased_on, s.condition
    FROM (SELECT hk(inventory_code) k, md5(concat_ws('|', purchased_on, condition)) d, * FROM film_copy) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_copy t WHERE t.copy_hk = s.k ORDER BY load_date DESC LIMIT 1);

    INSERT INTO sat_customer
    SELECT s.k, p_load, p_src, s.d, s.full_name, s.phone, s.email, s.address, s.registered_on
    FROM (SELECT hk(card_number) k, md5(concat_ws('|', full_name, phone, email, address, registered_on)) d, * FROM customer) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_customer t WHERE t.customer_hk = s.k ORDER BY load_date DESC LIMIT 1);

    INSERT INTO sat_employee
    SELECT s.k, p_load, p_src, s.d, s.full_name, s.position, s.hired_on
    FROM (SELECT hk(personnel_no) k, md5(concat_ws('|', full_name, position, hired_on)) d, * FROM employee) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_employee t WHERE t.employee_hk = s.k ORDER BY load_date DESC LIMIT 1);

    INSERT INTO sat_rental
    SELECT s.k, p_load, p_src, s.d, s.rented_at, s.due_on
    FROM (SELECT hk(rental_number) k, md5(concat_ws('|', rented_at, due_on)) d, * FROM rental) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_rental t WHERE t.rental_hk = s.k ORDER BY load_date DESC LIMIT 1);

    INSERT INTO sat_rental_copy
    SELECT s.k, p_load, p_src, s.d, s.price_per_day, s.returned_at, s.late_fee_paid
    FROM (SELECT hk(r.rental_number, c.inventory_code) k, md5(concat_ws('|', i.price_per_day, i.returned_at, i.late_fee_paid)) d,
                 i.price_per_day, i.returned_at, i.late_fee_paid
          FROM rental_item i JOIN rental r USING (rental_id) JOIN film_copy c USING (copy_id)) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_rental_copy t WHERE t.rental_copy_hk = s.k ORDER BY load_date DESC LIMIT 1);

    INSERT INTO sat_payment
    SELECT s.k, p_load, p_src, s.d, s.paid_at, s.amount, s.method
    FROM (SELECT hk(payment_number) k, md5(concat_ws('|', paid_at, amount, method)) d, * FROM payment) s
    WHERE s.d IS DISTINCT FROM (SELECT hash_diff FROM sat_payment t WHERE t.payment_hk = s.k ORDER BY load_date DESC LIMIT 1);
END $$;

CALL rental_dv.load_all('2025-01-01 00:00:00', 'VIDEORENTAL_3NF');
