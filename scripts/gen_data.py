"""ЛР2. Генерация тестовых данных для базы видеопроката (клиенты вымышленные).
Запуск: python gen_data.py 02_fill_3nf.sql"""
import random
import sys
from datetime import date, datetime, timedelta

random.seed(14)
q = lambda s: "'" + str(s).replace("'", "''") + "'"
out = ['-- Тестовые данные для схемы rental_3nf (сгенерировано gen_data.py)', 'SET search_path TO rental_3nf;']


def ins(table, cols, rows):
    out.append(f'INSERT INTO {table} ({", ".join(cols)}) VALUES')
    out.append(',\n'.join('  (' + ', '.join(v if isinstance(v, str) and v.startswith('@') is False and v == 'NULL' else (str(v) if isinstance(v, (int, float)) else q(v)) for v in r) + ')' for r in rows) + ';')


genres = ['Драма', 'Комедия', 'Фантастика', 'Боевик', 'Триллер', 'Мелодрама', 'Анимация', 'Приключения']
ins('genre', ['name'], [[g] for g in genres])
directors = [('Кристофер Нолан', 'Великобритания'), ('Стивен Спилберг', 'США'), ('Квентин Тарантино', 'США'), ('Хаяо Миядзаки', 'Япония'),
             ('Эльдар Рязанов', 'СССР'), ('Леонид Гайдай', 'СССР'), ('Джеймс Кэмерон', 'Канада'), ('Роберт Земекис', 'США')]
ins('director', ['full_name', 'country'], directors)
actors = ['Леонардо Ди Каприо', 'Том Хэнкс', 'Сигурни Уивер', 'Майкл Дж. Фокс', 'Кристофер Ллойд', 'Сэм Нилл', 'Джон Траволта', 'Ума Турман',
          'Андрей Мягков', 'Барбара Брыльска', 'Александр Демьяненко', 'Юрий Никулин', 'Арнольд Шварценеггер', 'Линда Хэмилтон', 'Мэттью Макконахи']
ins('actor', ['full_name'], [[a] for a in actors])
# название, год, минут, рейтинг, режиссёр, жанры, актёры
films = [
    ('Начало', 2010, 148, '12+', 1, [3, 5], [1]), ('Интерстеллар', 2014, 169, '12+', 1, [3, 1], [15]), ('Парк юрского периода', 1993, 127, '12+', 2, [3, 8], [6]),
    ('Спасти рядового Райана', 1998, 169, '16+', 2, [1, 4], [2]), ('Криминальное чтиво', 1994, 154, '18+', 3, [5, 2], [7, 8]), ('Убить Билла', 2003, 111, '18+', 3, [4, 5], [8]),
    ('Унесённые призраками', 2001, 125, '6+', 4, [7, 8], []), ('Мой сосед Тоторо', 1988, 86, '0+', 4, [7], []), ('Ирония судьбы, или С лёгким паром!', 1976, 184, '12+', 5, [2, 6], [9, 10]),
    ('Служебный роман', 1977, 159, '12+', 5, [2, 6], [9]), ('Бриллиантовая рука', 1969, 100, '6+', 6, [2], [12]), ('Кавказская пленница', 1967, 82, '6+', 6, [2, 8], [11, 12]),
    ('Операция «Ы»', 1965, 95, '6+', 6, [2], [11, 12]), ('Титаник', 1997, 194, '12+', 7, [1, 6], [1]), ('Терминатор 2', 1991, 137, '16+', 7, [3, 4], [13, 14]),
    ('Чужие', 1986, 137, '16+', 7, [3, 5], [3]), ('Назад в будущее', 1985, 116, '12+', 8, [3, 2], [4, 5]), ('Форрест Гамп', 1994, 142, '12+', 8, [1, 6], [2]),
]
ins('film', ['film_code', 'title', 'release_year', 'duration_min', 'age_rating', 'director_id'],
    [[f'F{i:03d}', f[0], f[1], f[2], f[3], f[4]] for i, f in enumerate(films, 1)])
ins('film_genre', ['film_id', 'genre_id'], [[i, g] for i, f in enumerate(films, 1) for g in f[5]])
ins('film_actor', ['film_id', 'actor_id'], [[i, a] for i, f in enumerate(films, 1) for a in f[6]])
formats = [('VHS', 40, 20), ('DVD', 80, 40), ('Blu-ray', 120, 60)]
ins('media_format', ['name', 'price_per_day', 'late_fee'], formats)
copies = []
for fi in range(1, len(films) + 1):
    for k in range(random.randint(2, 4)):
        fmt = random.choices([1, 2, 3], [1, 5, 3])[0]
        copies.append((fi, fmt, date(2023, 1, 1) + timedelta(days=random.randint(0, 500)), random.choice(['новое', 'хорошее', 'хорошее', 'удовлетворительное'])))
ins('film_copy', ['inventory_code', 'film_id', 'format_id', 'purchased_on', 'condition'],
    [[f'INV-{i:05d}', c[0], c[1], c[2].isoformat(), c[3]] for i, c in enumerate(copies, 1)])
names = 'Иван Пётр Сергей Алексей Николай Дмитрий Анна Мария Елена Ольга Татьяна Светлана'.split()
sur = 'Кравцов Белов Титов Ершов Гусев Шубин Жуков Ефимов Рябов Тихонов Панов Фомин'.split()
streets = ['Ленина', 'Садовая', 'Мира', 'Парковая', 'Центральная']
custs = []
for i in range(1, 31):
    n = random.choice(names)
    s = random.choice(sur) + ('а' if n in names[6:] else '')
    custs.append([f'C{i:05d}', f'{n} {s}', f'+7-9{random.randint(10, 99)}-{random.randint(100, 999)}-{random.randint(10, 99)}-{random.randint(10, 99)}',
                  f'client{i}@example.com', f'ул. {random.choice(streets)}, д. {random.randint(1, 80)}', (date(2023, 3, 1) + timedelta(days=random.randint(0, 300))).isoformat()])
ins('customer', ['card_number', 'full_name', 'phone', 'email', 'address', 'registered_on'], custs)
ins('employee', ['personnel_no', 'full_name', 'position', 'hired_on'], [
    ['E001', 'Андрей Киселёв', 'администратор', '2022-02-01'], ['E002', 'Вера Соловьёва', 'продавец-консультант', '2022-06-15'], ['E003', 'Глеб Романов', 'продавец-консультант', '2023-04-10']])
rentals, items, pays = [], [], []
busy = {}
t = datetime(2024, 1, 3, 11)
for i in range(1, 201):
    t += timedelta(hours=random.randint(10, 60))
    t = t.replace(hour=random.randint(10, 20), minute=random.choice([0, 15, 30, 45]))
    days = random.choice([1, 1, 2, 2, 3, 5])
    due = t.date() + timedelta(days=days)
    avail = [c for c in range(1, len(copies) + 1) if busy.get(c, datetime.min) < t]
    picks = random.sample(avail, random.choice([1, 1, 1, 2, 2, 3]))
    total = 0
    pending = i > 195
    for c in picks:
        fmt = copies[c - 1][1]
        price, fee = formats[fmt - 1][1], formats[fmt - 1][2]
        late = random.choices([0, 1, 2, 3], [8, 2, 1, 1])[0]
        ret = datetime.combine(due + timedelta(days=late), t.time())
        total += price * days + fee * late
        busy[c] = ret if not pending else datetime.max
        items.append([i, c, price, 'NULL' if pending else ret.isoformat(sep=' '), 0 if pending else fee * late])
    rentals.append([f'R{i:06d}', random.randint(1, 30), random.randint(1, 3), t.isoformat(sep=' '), due.isoformat()])
    if pending:
        total = sum(formats[copies[c - 1][1] - 1][1] * days for c in picks)
    pays.append([f'P{i:06d}', i, t.isoformat(sep=' '), total, random.choice(['наличные', 'карта', 'карта'])])
ins('rental', ['rental_number', 'customer_id', 'employee_id', 'rented_at', 'due_on'], rentals)
ins('rental_item', ['rental_id', 'copy_id', 'price_per_day', 'returned_at', 'late_fee_paid'], items)
ins('payment', ['payment_number', 'rental_id', 'paid_at', 'amount', 'method'], pays)
open(sys.argv[1], 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print('фильмов', len(films), 'экземпляров', len(copies), 'заказов', len(rentals), 'позиций', len(items))
