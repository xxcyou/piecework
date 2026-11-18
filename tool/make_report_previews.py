#!/usr/bin/env python3
"""生成 README 里三张「报表渲染效果」图（对外版 / 紧凑版 / 按型号分组）。

和 tool/make_screenshots.py 一样是**脚本绘制**，不是真机截图：
系统里唯一的 CJK 字体没有拉丁字形，所以按「中文段 / 拉丁段」分段用两套字体，
否则数字和符号会变成空心方块。

跑法：python3 tool/make_report_previews.py
产物：docs/preview/report_{external,compact,by_style}.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

FONT_CJK = '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf'
FONT_LATIN = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_LATIN_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
OUT = os.path.join(os.path.dirname(__file__), '..', 'docs', 'preview')

W = 1200
INK = (26, 29, 36)
INK2 = (110, 118, 132)
INK3 = (156, 163, 175)
PRIMARY = (46, 107, 255)
LINE = (226, 230, 238)
BAND = (240, 244, 253)


def _is_cjk(ch):
    o = ord(ch)
    return (0x2E80 <= o <= 0x9FFF) or (0xF900 <= o <= 0xFAFF) or \
        (0xFF00 <= o <= 0xFFEF) or (0x3000 <= o <= 0x303F)


def _runs(s):
    out = []
    for ch in s:
        c = _is_cjk(ch)
        if out and out[-1][1] == c:
            out[-1] = (out[-1][0] + ch, c)
        else:
            out.append((ch, c))
    return out


def _fonts(size, bold):
    return (ImageFont.truetype(FONT_CJK, size),
            ImageFont.truetype(FONT_LATIN_BOLD if bold else FONT_LATIN, size))


def measure(d, s, size, bold=False):
    cjk, latin = _fonts(size, bold)
    return sum(d.textlength(run, font=cjk if c else latin) for run, c in _runs(s))


def text(d, xy, s, size=24, color=INK, bold=False, anchor='la'):
    cjk, latin = _fonts(size, bold)
    total = measure(d, s, size, bold)
    x, y = xy
    if anchor in ('ra', 'rm'):
        x -= total
    elif anchor in ('ma', 'mm'):
        x -= total / 2
    for run, is_cjk in _runs(s):
        ft = cjk if is_cjk else latin
        d.text((x, y), run, font=ft, fill=color,
               stroke_width=1 if bold else 0, stroke_fill=color)
        x += d.textlength(run, font=ft)


RECORDS = [
    ('18:30', 'A1023', '黑色', 'M', '300 片', '0.225', '67.50'),
    ('13:10', 'A1023', '黑色', 'L', '240 片', '0.225', '54.00'),
    ('09:40', 'A1023', '白色', 'M', '150 片', '0.225', '33.75'),
    ('17:20', 'B2087', '米白', 'S', '180 片', '0.31', '55.80'),
    ('14:05', 'B2087', '藏青', 'M', '420 片', '0.29', '121.80'),
    ('11:30', 'B2087', '米白', 'M', '210 片', '0.31', '65.10'),
    ('12:05', 'C3311', '灰色', 'XL', '96 片', '0.36', '34.56'),
    ('10:15', 'C3311', '黑色', 'S', '500 片', '0.20', '100.00'),
]

HEAD = [('统计区间', '2026-11-11 ~ 11-17'), ('记录', '10 条'),
        ('折算数量', '1,360 件'), ('总金额', '¥1,038.60')]


def page(height=1500):
    img = Image.new('RGB', (W, height), (255, 255, 255))
    return img, ImageDraw.Draw(img)


def header(d, y, title):
    text(d, (60, y), title, 40, INK, bold=True)
    text(d, (W - 60, y + 12), '计件助手 · 报表', 22, INK3, anchor='ra')
    y += 74
    # 关键信息带
    d.rounded_rectangle((60, y, W - 60, y + 92), radius=14, fill=BAND)
    cw = (W - 120) // 4
    for i, (label, value) in enumerate(HEAD):
        x = 60 + i * cw + 26
        text(d, (x, y + 18), label, 20, INK3)
        text(d, (x, y + 48), value, 28, PRIMARY if i == 3 else INK, bold=True)
    return y + 92 + 34


def thumb(d, x, y, size=54):
    """缩略图位（App 里的「无图」占位样式）"""
    d.rounded_rectangle((x, y, x + size, y + size), radius=8, fill=(243, 245, 249))
    d.rounded_rectangle((x + 12, y + 14, x + size - 12, y + size - 14),
                        radius=4, outline=INK3, width=2)
    d.ellipse((x + 17, y + 19, x + 24, y + 26), outline=INK3, width=2)


def group_title(d, y, title, sub):
    text(d, (60, y), title, 28, INK, bold=True)
    text(d, (W - 60, y + 6), sub, 20, INK3, anchor='ra')
    d.line((60, y + 46, W - 60, y + 46), fill=LINE, width=2)
    return y + 64


def subtotal(d, y, label, qty, amount):
    d.rounded_rectangle((60, y, W - 60, y + 56), radius=10, fill=(248, 250, 254))
    text(d, (80, y + 14), label, 22, INK2, bold=True)
    text(d, (W - 300, y + 14), qty, 22, INK2, anchor='ra')
    text(d, (W - 80, y + 14), amount, 22, INK2, anchor='ra', bold=True)
    return y + 76


def external():
    img, d = page(1420)
    y = header(d, 56, '对外版报表（带缩略图）')
    y = group_title(d, y, '11 月 17 日', '3 条 · 690 片')
    for (t, style, color, size, qty, price, amt) in RECORDS[:3]:
        thumb(d, 62, y - 4)
        text(d, (134, y + 2), t, 22, INK3)
        text(d, (210, y), f'{style}  {color}  {size}', 26, INK, bold=True)
        text(d, (210, y + 34), f'{qty} × ¥{price}', 20, INK2)
        text(d, (W - 200, y), qty, 24, INK, anchor='ra')
        text(d, (W - 62, y), f'¥{amt}', 24, PRIMARY, anchor='ra', bold=True)
        y += 74
        d.line((60, y - 18, W - 60, y - 18), fill=LINE, width=1)
    y = subtotal(d, y - 6, '小计 · 3 条', '690 片', '¥155.25')
    y = group_title(d, y, '11 月 16 日', '2 条 · 600 片')
    for (t, style, color, size, qty, price, amt) in RECORDS[3:5]:
        thumb(d, 62, y - 4)
        text(d, (134, y + 2), t, 22, INK3)
        text(d, (210, y), f'{style}  {color}  {size}', 26, INK, bold=True)
        text(d, (210, y + 34), f'{qty} × ¥{price}', 20, INK2)
        text(d, (W - 200, y), qty, 24, INK, anchor='ra')
        text(d, (W - 62, y), f'¥{amt}', 24, PRIMARY, anchor='ra', bold=True)
        y += 74
        d.line((60, y - 18, W - 60, y - 18), fill=LINE, width=1)
    subtotal(d, y - 6, '小计 · 2 条', '600 片', '¥177.60')
    text(d, (60, 1370), '注：缩略图按 App 真实的「无图」占位绘制；数据为示例', 18, INK3)
    img.save(os.path.join(OUT, 'report_external.png'))


def compact():
    img, d = page(1180)
    y = header(d, 56, '自用紧凑版报表')
    # 表头
    cols = [60, 220, 420, 640, 840, 1040]
    heads = ['时间', '型号', '颜色 / 码数', '数量', '单价', '小计']
    for x, h in zip(cols, heads):
        text(d, (x, y), h, 20, INK3)
    y += 40
    d.line((60, y, W - 60, y), fill=LINE, width=2)
    y += 16
    for (t, style, color, size, qty, price, amt) in RECORDS:
        text(d, (cols[0], y), t, 22, INK3)
        text(d, (cols[1], y - 2), style, 24, INK, bold=True)
        text(d, (cols[2], y), f'{color} / {size}', 22, INK2)
        text(d, (cols[3], y), qty, 22, INK, anchor='ra')
        text(d, (cols[4] + 120, y), f'¥{price}', 22, INK2, anchor='ra')
        text(d, (W - 60, y), f'¥{amt}', 22, PRIMARY, anchor='ra', bold=True)
        y += 62
        d.line((60, y - 20, W - 60, y - 20), fill=LINE, width=1)
    y = subtotal(d, y, '合计 · 10 条', '1,360 片', '¥1,038.60')
    text(d, (60, 1100), '注：数据为示例；同一份排版就是导出 PNG 的样子', 18, INK3)
    img.save(os.path.join(OUT, 'report_compact.png'))


def by_style():
    img, d = page(1320)
    y = header(d, 56, '按型号分组')
    groups = [
        ('A1023', '3 条 · 690 片 · ¥155.25', RECORDS[0:3]),
        ('B2087', '3 条 · 810 片 · ¥242.70', RECORDS[3:6]),
        ('C3311', '2 条 · 596 片 · ¥134.56', RECORDS[6:8]),
    ]
    for name, summary, rows in groups:
        y = group_title(d, y, name, summary)
        for (t, style, color, size, qty, price, amt) in rows:
            text(d, (76, y), t, 22, INK3)
            text(d, (200, y), f'{color} / {size}', 24, INK2)
            text(d, (W - 300, y), qty, 22, INK, anchor='ra')
            text(d, (W - 60, y), f'¥{amt}', 22, PRIMARY, anchor='ra', bold=True)
            y += 56
        y += 18
    text(d, (60, 1240), '注：每组末尾都有「条数 · 数量 · 金额」小计，方便对账', 18, INK3)
    img.save(os.path.join(OUT, 'report_by_style.png'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    external()
    compact()
    by_style()
    print('wrote', OUT)
