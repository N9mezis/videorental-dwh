-- =====================================================================
-- ЛР2. Вариант 14. Система учёта в видеопрокате. Модель Data Vault 2.0
-- Хабы хранят бизнес-ключи, ссылки - связи, сателлиты - описания и историю.
-- Ключи - MD5 от бизнес-ключа; у всех таблиц есть load_date и record_source.
-- =====================================================================
DROP SCHEMA IF EXISTS rental_dv CASCADE;
CREATE SCHEMA rental_dv;
SET search_path TO rental_dv;

-- ---------------------------- ХАБЫ -----------------------------------
CREATE TABLE hub_film (
    film_hk       CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    film_code     VARCHAR(10) NOT NULL UNIQUE
);
CREATE TABLE hub_genre (
    genre_hk      CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    genre_name    VARCHAR(50) NOT NULL UNIQUE
);
CREATE TABLE hub_person (              -- режиссёры и актёры: один тип сущности «персона»
    person_hk     CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP    NOT NULL,
    record_source VARCHAR(50)  NOT NULL,
    person_name   VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE hub_format (
    format_hk     CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    format_name   VARCHAR(20) NOT NULL UNIQUE
);
CREATE TABLE hub_copy (
    copy_hk        CHAR(32) PRIMARY KEY,
    load_date      TIMESTAMP   NOT NULL,
    record_source  VARCHAR(50) NOT NULL,
    inventory_code VARCHAR(12) NOT NULL UNIQUE
);
CREATE TABLE hub_customer (
    customer_hk   CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    card_number   VARCHAR(10) NOT NULL UNIQUE
);
CREATE TABLE hub_employee (
    employee_hk   CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    personnel_no  VARCHAR(10) NOT NULL UNIQUE
);
CREATE TABLE hub_rental (
    rental_hk     CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    rental_number VARCHAR(12) NOT NULL UNIQUE
);
CREATE TABLE hub_payment (
    payment_hk     CHAR(32) PRIMARY KEY,
    load_date      TIMESTAMP   NOT NULL,
    record_source  VARCHAR(50) NOT NULL,
    payment_number VARCHAR(12) NOT NULL UNIQUE
);

-- ---------------------------- ССЫЛКИ ---------------------------------
CREATE TABLE lnk_film_genre (
    film_genre_hk CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    film_hk       CHAR(32) NOT NULL REFERENCES hub_film,
    genre_hk      CHAR(32) NOT NULL REFERENCES hub_genre
);
CREATE TABLE lnk_film_person (          -- role: режиссёр или актёр входит в ключ связи
    film_person_hk CHAR(32) PRIMARY KEY,
    load_date      TIMESTAMP   NOT NULL,
    record_source  VARCHAR(50) NOT NULL,
    film_hk        CHAR(32) NOT NULL REFERENCES hub_film,
    person_hk      CHAR(32) NOT NULL REFERENCES hub_person,
    role           VARCHAR(10) NOT NULL
);
CREATE TABLE lnk_copy (                 -- экземпляр - фильм - формат
    copy_link_hk  CHAR(32) PRIMARY KEY,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    copy_hk       CHAR(32) NOT NULL REFERENCES hub_copy,
    film_hk       CHAR(32) NOT NULL REFERENCES hub_film,
    format_hk     CHAR(32) NOT NULL REFERENCES hub_format
);
CREATE TABLE lnk_rental (               -- заказ - клиент - сотрудник
    rental_link_hk CHAR(32) PRIMARY KEY,
    load_date      TIMESTAMP   NOT NULL,
    record_source  VARCHAR(50) NOT NULL,
    rental_hk      CHAR(32) NOT NULL REFERENCES hub_rental,
    customer_hk    CHAR(32) NOT NULL REFERENCES hub_customer,
    employee_hk    CHAR(32) NOT NULL REFERENCES hub_employee
);
CREATE TABLE lnk_rental_copy (          -- позиция заказа
    rental_copy_hk CHAR(32) PRIMARY KEY,
    load_date      TIMESTAMP   NOT NULL,
    record_source  VARCHAR(50) NOT NULL,
    rental_hk      CHAR(32) NOT NULL REFERENCES hub_rental,
    copy_hk        CHAR(32) NOT NULL REFERENCES hub_copy
);
CREATE TABLE lnk_payment_rental (
    payment_rental_hk CHAR(32) PRIMARY KEY,
    load_date         TIMESTAMP   NOT NULL,
    record_source     VARCHAR(50) NOT NULL,
    payment_hk        CHAR(32) NOT NULL REFERENCES hub_payment,
    rental_hk         CHAR(32) NOT NULL REFERENCES hub_rental
);

-- ---------------------------- САТЕЛЛИТЫ ------------------------------
-- Ключ: родитель + load_date, поэтому новая версия атрибутов - новая строка.
-- hash_diff - MD5 всех атрибутов: быстрая проверка, изменилось ли что-то.
CREATE TABLE sat_film (
    film_hk       CHAR(32) NOT NULL REFERENCES hub_film,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    hash_diff     CHAR(32) NOT NULL,
    title         VARCHAR(150) NOT NULL,
    release_year  SMALLINT NOT NULL,
    duration_min  SMALLINT NOT NULL,
    age_rating    VARCHAR(3) NOT NULL,
    PRIMARY KEY (film_hk, load_date)
);
CREATE TABLE sat_person (
    person_hk     CHAR(32) NOT NULL REFERENCES hub_person,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    hash_diff     CHAR(32) NOT NULL,
    country       VARCHAR(50),
    PRIMARY KEY (person_hk, load_date)
);
CREATE TABLE sat_format_tariff (        -- история тарифов
    format_hk     CHAR(32) NOT NULL REFERENCES hub_format,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    hash_diff     CHAR(32) NOT NULL,
    price_per_day NUMERIC(8, 2) NOT NULL,
    late_fee      NUMERIC(8, 2) NOT NULL,
    PRIMARY KEY (format_hk, load_date)
);
CREATE TABLE sat_copy (
    copy_hk       CHAR(32) NOT NULL REFERENCES hub_copy,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    hash_diff     CHAR(32) NOT NULL,
    purchased_on  DATE NOT NULL,
    condition     VARCHAR(20) NOT NULL,
    PRIMARY KEY (copy_hk, load_date)
);
CREATE TABLE sat_customer (             -- история контактов клиента
    customer_hk   CHAR(32) NOT NULL REFERENCES hub_customer,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    hash_diff     CHAR(32) NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    phone         VARCHAR(20) NOT NULL,
    email         VARCHAR(100),
    address       VARCHAR(200),
    registered_on DATE NOT NULL,
    PRIMARY KEY (customer_hk, load_date)
);
CREATE TABLE sat_employee (
    employee_hk   CHAR(32) NOT NULL REFERENCES hub_employee,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    hash_diff     CHAR(32) NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    position      VARCHAR(50) NOT NULL,
    hired_on      DATE NOT NULL,
    PRIMARY KEY (employee_hk, load_date)
);
CREATE TABLE sat_rental (
    rental_hk     CHAR(32) NOT NULL REFERENCES hub_rental,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    hash_diff     CHAR(32) NOT NULL,
    rented_at     TIMESTAMP NOT NULL,
    due_on        DATE NOT NULL,
    PRIMARY KEY (rental_hk, load_date)
);
CREATE TABLE sat_rental_copy (          -- сателлит ссылки: возврат появляется новой версией
    rental_copy_hk CHAR(32) NOT NULL REFERENCES lnk_rental_copy,
    load_date      TIMESTAMP   NOT NULL,
    record_source  VARCHAR(50) NOT NULL,
    hash_diff      CHAR(32) NOT NULL,
    price_per_day  NUMERIC(8, 2) NOT NULL,
    returned_at    TIMESTAMP,
    late_fee_paid  NUMERIC(8, 2) NOT NULL,
    PRIMARY KEY (rental_copy_hk, load_date)
);
CREATE TABLE sat_payment (
    payment_hk    CHAR(32) NOT NULL REFERENCES hub_payment,
    load_date     TIMESTAMP   NOT NULL,
    record_source VARCHAR(50) NOT NULL,
    hash_diff     CHAR(32) NOT NULL,
    paid_at       TIMESTAMP NOT NULL,
    amount        NUMERIC(10, 2) NOT NULL,
    method        VARCHAR(10) NOT NULL,
    PRIMARY KEY (payment_hk, load_date)
);
