# Хранилище данных видеопроката (3НФ и Data Vault)

Лабораторная работа № 2 по дисциплине «Хранилища данных», вариант 14 – система учёта в видеопрокате.
Автор: А.В. Белоус, группа 231-363, Московский Политех.

## Состав

| Путь | Содержимое |
|---|---|
| `sql/01_create_3nf.sql` | Структура базы в третьей нормальной форме (схема `rental_3nf`, 13 таблиц) |
| `sql/02_fill_3nf.sql` | Тестовые данные |
| `sql/03_create_data_vault.sql` | Структура Data Vault 2.0 (схема `rental_dv`: 9 хабов, 6 ссылок, 9 сателлитов) |
| `sql/04_load_data_vault.sql` | Загрузка Data Vault из 3НФ (процедура `load_all`) |
| `sql/05_checks.sql` | Сравнение отчётов и проверка истории в сателлитах |
| `scripts/gen_data.py` | Генерация тестовых данных |
| `scripts/erd.py` | Построение даталогических моделей по метаданным PostgreSQL |
| `docs/` | Даталогические модели |

## Запуск

```bash
docker run -d --name dwh-postgres -e POSTGRES_PASSWORD=lab -e POSTGRES_DB=videorental postgres:16-alpine
for f in sql/0*.sql; do docker exec -i dwh-postgres psql -U postgres -d videorental < "$f"; done
```
