"""ЛР2. Построение даталогических моделей по метаданным PostgreSQL (information_schema).
Таблицы, столбцы, типы, PK и FK читаются из базы, поэтому схема совпадает с созданной структурой."""
import json
import subprocess
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

SQL = r"""
SELECT json_agg(x) FROM (
  SELECT c.table_name AS t, c.column_name AS c, c.ordinal_position AS o,
         CASE WHEN c.data_type IN ('character varying','character') THEN
                   (CASE c.data_type WHEN 'character' THEN 'char' ELSE 'varchar' END) || '(' || c.character_maximum_length || ')'
              WHEN c.data_type = 'numeric' THEN 'numeric(' || c.numeric_precision || ',' || c.numeric_scale || ')'
              WHEN c.data_type LIKE 'timestamp%%' THEN 'timestamp'
              ELSE c.data_type END AS ty,
         c.is_nullable = 'NO' AS nn,
         EXISTS (SELECT 1 FROM information_schema.table_constraints tc JOIN information_schema.key_column_usage k
                 USING (constraint_schema, constraint_name)
                 WHERE tc.constraint_type = 'PRIMARY KEY' AND k.table_schema = c.table_schema
                   AND k.table_name = c.table_name AND k.column_name = c.column_name) AS pk,
         (SELECT ccu.table_name FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage k USING (constraint_schema, constraint_name)
            JOIN information_schema.constraint_column_usage ccu USING (constraint_schema, constraint_name)
           WHERE tc.constraint_type = 'FOREIGN KEY' AND k.table_schema = c.table_schema
             AND k.table_name = c.table_name AND k.column_name = c.column_name LIMIT 1) AS fk
  FROM information_schema.columns c
  WHERE c.table_schema = '%s' ORDER BY c.table_name, c.ordinal_position) x
"""


def meta(schema):
    r = subprocess.run(['docker', 'exec', 'dwh-postgres', 'psql', '-U', 'postgres', '-d', 'videorental', '-At', '-c', SQL % schema],
                       capture_output=True, text=True, encoding='utf8')
    tabs = {}
    for row in json.loads(r.stdout):
        tabs.setdefault(row['t'], []).append(row)
    return tabs


COL = {'hub': '#cfe8cf', 'lnk': '#cfe0f5', 'sat': '#fbeec8'}
W, RH = 3.3, 0.27


def kind(t):
    return t[:3] if t[:3] in COL else 'tab'


def draw(schema, layout, out, skip_cols=(), title=None):
    tabs = meta(schema)
    boxes = {}
    for t, (x, y) in layout.items():
        cols = [c for c in tabs[t] if c['c'] not in skip_cols]
        boxes[t] = (x, y, W, RH * (len(cols) + 1) + 0.08, cols)
    xs = [b[0] for b in boxes.values()] + [b[0] + W for b in boxes.values()]
    ys = [b[1] for b in boxes.values()] + [b[1] - b[3] for b in boxes.values()]
    fw, fh = max(xs) - min(xs) + 0.6, max(ys) - min(ys) + 0.6
    fig, ax = plt.subplots(figsize=(fw * 0.62, fh * 0.62), dpi=220)
    ax.set_xlim(min(xs) - 0.3, max(xs) + 0.3); ax.set_ylim(min(ys) - 0.3, max(ys) + 0.3); ax.axis('off')
    plt.rcParams['font.family'] = 'DejaVu Sans'
    used = []
    # связи: FK дочерней таблицы -> родитель
    for t, (x, y, w, h, cols) in boxes.items():
        for i, c in enumerate(cols):
            if c['fk'] and c['fk'] in boxes and c['fk'] != t:
                px, py, pw, ph, pcols = boxes[c['fk']]
                cy = y - RH * (i + 1.5) - 0.04
                pidx = next((j for j, pc in enumerate(pcols) if pc['pk']), 0)
                pcy = py - RH * (pidx + 1.5) - 0.04
                if px > x + w:
                    x0, x1 = x + w, px
                elif px + pw < x:
                    x0, x1 = x, px + pw
                else:
                    x0, x1 = (x + w, px + pw) if True else (x, px)
                    xm = max(x + w, px + pw) + 0.25
                    ax.plot([x0, xm, xm, x1], [cy, cy, pcy, pcy], color='#55606e', lw=0.8, zorder=1)
                    ax.plot([x1 + 0.06], [pcy], marker='<', ms=3.5, color='#55606e', zorder=3)
                    continue
                xm = (x0 + x1) / 2
                lo, hi = min(cy, pcy), max(cy, pcy)
                while any(abs(xm - ux) < 0.1 and lo < uh and ul < hi for ux, ul, uh in used):
                    xm += 0.18           # разводим вертикальные участки, которые иначе слились бы
                used.append((xm, lo, hi))
                ax.plot([x0, xm, xm, x1], [cy, cy, pcy, pcy], color='#55606e', lw=0.8, zorder=1)
                ax.plot([x1], [pcy], marker='>' if x1 > x0 else '<', ms=3.5, color='#55606e', zorder=3)
                ax.plot([x0], [cy], marker='o', ms=2.2, color='#55606e', zorder=3)
    for t, (x, y, w, h, cols) in boxes.items():
        k = kind(t)
        ax.add_patch(FancyBboxPatch((x, y - h), w, h, boxstyle='round,pad=0.0,rounding_size=0.06', fc='white', ec='#334155', lw=0.9, zorder=2))
        ax.add_patch(FancyBboxPatch((x, y - RH - 0.04), w, RH + 0.04, boxstyle='round,pad=0.0,rounding_size=0.06',
                                    fc=COL.get(k, '#dbe4ee'), ec='#334155', lw=0.9, zorder=2))
        ax.text(x + w / 2, y - RH / 2 - 0.02, t, ha='center', va='center', fontsize=6.6, weight='bold', zorder=4)
        for i, c in enumerate(cols):
            cy = y - RH * (i + 1.5) - 0.04
            tag = 'PK' if c['pk'] else ('FK' if c['fk'] else '')
            if c['pk'] and c['fk']:
                tag = 'PK FK'
            ax.text(x + 0.06, cy, tag, ha='left', va='center', fontsize=4.6, color='#9a3412' if c['pk'] else '#1d4ed8', weight='bold', zorder=4)
            ax.text(x + 0.62, cy, c['c'], ha='left', va='center', fontsize=5.6, weight='bold' if c['nn'] else 'normal', zorder=4)
            ax.text(x + w - 0.06, cy, c['ty'], ha='right', va='center', fontsize=4.9, color='#475569', zorder=4)
    fig.savefig(out, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print('saved', out, len(boxes), 'tables')


if __name__ == '__main__':
    O = sys.argv[1]
    draw('rental_3nf', {
        'genre': (0, 0), 'film_genre': (4.3, 0), 'director': (12.9, 0),
        'actor': (0, -2.2), 'film_actor': (4.3, -2.2), 'film': (8.6, -0.6),
        'media_format': (12.9, -3.2), 'film_copy': (8.6, -3.6),
        'rental_item': (4.3, -4.8), 'customer': (0, -6.8), 'rental': (4.3, -7.2), 'employee': (8.6, -7.0),
        'payment': (0, -4.4),
    }, O + '\\model_3nf.png')
    SK = ('load_date', 'record_source')
    draw('rental_dv', {
        'sat_film': (0, 0), 'hub_film': (4.3, -0.2), 'lnk_film_genre': (8.6, 0), 'hub_genre': (12.9, 0),
        'lnk_film_person': (8.6, -2.0), 'hub_person': (12.9, -2.0), 'sat_person': (12.9, -3.6),
        'lnk_copy': (4.3, -2.4), 'hub_copy': (0, -3.4), 'sat_copy': (0, -5.0), 'hub_format': (8.6, -4.4), 'sat_format_tariff': (12.9, -5.0),
    }, O + '\\model_dv_catalog.png', skip_cols=SK)
    draw('rental_dv', {
        'hub_copy': (0, 0), 'lnk_rental_copy': (4.3, 0), 'sat_rental_copy': (4.3, -1.6), 'hub_rental': (8.6, 0), 'sat_rental': (12.9, 0),
        'lnk_rental': (8.6, -2.0), 'hub_customer': (4.3, -3.9), 'sat_customer': (0, -3.9), 'hub_employee': (12.9, -2.0), 'sat_employee': (12.9, -3.6),
        'lnk_payment_rental': (8.6, -4.6), 'hub_payment': (12.9, -5.6), 'sat_payment': (8.6, -6.4),
    }, O + '\\model_dv_rental.png', skip_cols=SK)
