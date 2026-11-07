-- =====================================================================
-- ЛР2. Вариант 14. Система учёта в видеопрокате. Модель 3НФ (PostgreSQL)
-- Схема rental_3nf - оперативная база видеопроката.
-- =====================================================================
DROP SCHEMA IF EXISTS rental_3nf CASCADE;
CREATE SCHEMA rental_3nf;
SET search_path TO rental_3nf;

-- Справочник жанров
CREATE TABLE genre (
    genre_id SERIAL PRIMARY KEY,
    name     VARCHAR(50) NOT NULL UNIQUE
);
COMMENT ON TABLE genre IS 'Жанры фильмов';

-- Режиссёры
CREATE TABLE director (
    director_id SERIAL PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    country     VARCHAR(50)
);
COMMENT ON TABLE director IS 'Режиссёры';

-- Актёры
CREATE TABLE actor (
    actor_id  SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL
);
COMMENT ON TABLE actor IS 'Актёры';

-- Фильмы. film_code - бизнес-ключ, в Data Vault он станет ключом хаба
CREATE TABLE film (
    film_id      SERIAL PRIMARY KEY,
    film_code    VARCHAR(10)  NOT NULL UNIQUE,
    title        VARCHAR(150) NOT NULL,
    release_year SMALLINT     NOT NULL CHECK (release_year BETWEEN 1895 AND 2100),
    duration_min SMALLINT     NOT NULL CHECK (duration_min > 0),
    age_rating   VARCHAR(3)   NOT NULL CHECK (age_rating IN ('0+', '6+', '12+', '16+', '18+')),
    director_id  INT          NOT NULL REFERENCES director (director_id)
);
COMMENT ON TABLE film IS 'Фильмы каталога (описание фильма, а не конкретного диска)';

-- Связь «многие ко многим»: фильм - жанр
CREATE TABLE film_genre (
    film_id  INT NOT NULL REFERENCES film (film_id) ON DELETE CASCADE,
    genre_id INT NOT NULL REFERENCES genre (genre_id),
    PRIMARY KEY (film_id, genre_id)
);

-- Связь «многие ко многим»: фильм - актёр
CREATE TABLE film_actor (
    film_id  INT NOT NULL REFERENCES film (film_id) ON DELETE CASCADE,
    actor_id INT NOT NULL REFERENCES actor (actor_id),
    PRIMARY KEY (film_id, actor_id)
);

-- Форматы носителей с тарифом: цена зависит только от формата,
-- поэтому вынесена сюда, а не хранится в каждом экземпляре (иначе нарушится 3НФ)
CREATE TABLE media_format (
    format_id     SERIAL PRIMARY KEY,
    name          VARCHAR(20)   NOT NULL UNIQUE,
    price_per_day NUMERIC(8, 2) NOT NULL CHECK (price_per_day > 0),
    late_fee      NUMERIC(8, 2) NOT NULL CHECK (late_fee >= 0)
);
COMMENT ON TABLE media_format IS 'Форматы носителей и тарифы';

-- Экземпляры: конкретные диски на полке
CREATE TABLE film_copy (
    copy_id        SERIAL PRIMARY KEY,
    inventory_code VARCHAR(12) NOT NULL UNIQUE,
    film_id        INT         NOT NULL REFERENCES film (film_id),
    format_id      INT         NOT NULL REFERENCES media_format (format_id),
    purchased_on   DATE        NOT NULL,
    condition      VARCHAR(20) NOT NULL DEFAULT 'хорошее'
                   CHECK (condition IN ('новое', 'хорошее', 'удовлетворительное', 'списано'))
);
COMMENT ON TABLE film_copy IS 'Физические экземпляры фильмов';

-- Клиенты
CREATE TABLE customer (
    customer_id   SERIAL PRIMARY KEY,
    card_number   VARCHAR(10)  NOT NULL UNIQUE,
    full_name     VARCHAR(100) NOT NULL,
    phone         VARCHAR(20)  NOT NULL,
    email         VARCHAR(100),
    address       VARCHAR(200),
    registered_on DATE         NOT NULL
);
COMMENT ON TABLE customer IS 'Клиенты видеопроката; card_number - номер клубной карты';

-- Сотрудники
CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    personnel_no VARCHAR(10)  NOT NULL UNIQUE,
    full_name   VARCHAR(100) NOT NULL,
    position    VARCHAR(50)  NOT NULL,
    hired_on    DATE         NOT NULL
);
COMMENT ON TABLE employee IS 'Сотрудники видеопроката';

-- Заказ на прокат: один клиент может взять сразу несколько дисков
CREATE TABLE rental (
    rental_id     SERIAL PRIMARY KEY,
    rental_number VARCHAR(12) NOT NULL UNIQUE,
    customer_id   INT         NOT NULL REFERENCES customer (customer_id),
    employee_id   INT         NOT NULL REFERENCES employee (employee_id),
    rented_at     TIMESTAMP   NOT NULL,
    due_on        DATE        NOT NULL,
    CHECK (due_on >= rented_at::date)
);
COMMENT ON TABLE rental IS 'Заказы на прокат';

-- Позиции заказа. Цена фиксируется на момент выдачи: тариф потом может измениться
CREATE TABLE rental_item (
    rental_id     INT           NOT NULL REFERENCES rental (rental_id) ON DELETE CASCADE,
    copy_id       INT           NOT NULL REFERENCES film_copy (copy_id),
    price_per_day NUMERIC(8, 2) NOT NULL CHECK (price_per_day > 0),
    returned_at   TIMESTAMP,
    late_fee_paid NUMERIC(8, 2) NOT NULL DEFAULT 0 CHECK (late_fee_paid >= 0),
    PRIMARY KEY (rental_id, copy_id)
);
COMMENT ON TABLE rental_item IS 'Экземпляры в заказе; returned_at пуст, пока диск не вернули';

-- Оплаты
CREATE TABLE payment (
    payment_id     SERIAL PRIMARY KEY,
    payment_number VARCHAR(12)   NOT NULL UNIQUE,
    rental_id      INT           NOT NULL REFERENCES rental (rental_id),
    paid_at        TIMESTAMP     NOT NULL,
    amount         NUMERIC(10, 2) NOT NULL CHECK (amount > 0),
    method         VARCHAR(10)   NOT NULL CHECK (method IN ('наличные', 'карта'))
);
COMMENT ON TABLE payment IS 'Оплаты заказов';

-- Индексы по внешним ключам для частых соединений
CREATE INDEX idx_film_director ON film (director_id);
CREATE INDEX idx_copy_film ON film_copy (film_id);
CREATE INDEX idx_rental_customer ON rental (customer_id);
CREATE INDEX idx_rental_item_copy ON rental_item (copy_id);
CREATE INDEX idx_payment_rental ON payment (rental_id);
-- Один экземпляр не может быть выдан дважды одновременно
CREATE UNIQUE INDEX uq_copy_on_hand ON rental_item (copy_id) WHERE returned_at IS NULL;
