#!/usr/bin/env python3
"""生成 README 展示用的界面示意图（纯脚本绘制，不用真机截图）。

为什么要脚本画：Flutter golden 渲染在 flutter test 环境里，默认字体是
FlutterTest（所有字符都是空心方块），要逐处注入中文字体非常脆弱；
这里直接用系统 CJK 字体绘制，字形一定正确，也更好看。

跑法：python3 tool/make_screenshots.py
产物：docs/screenshots/{home_records,report}.png
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# 系统里能用的两种字体：Droid 只有中文字形、DejaVu 只有拉丁字形，
# 所以画文字要按「中文/非中文」分段用不同字体（PIL 没有 fallback 机制）
FONT_CJK = '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf'
FONT_LATIN = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_LATIN_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
OUT = os.path.join(os.path.dirname(__file__), '..', 'docs', 'screenshots')

W, H = 1080, 2160
BG = (246, 247, 251)
CARD = (255, 255, 255)
INK = (26, 29, 36)
INK2 = (110, 118, 132)
INK3 = (156, 163, 175)
PRIMARY = (46, 107, 255)
GREEN = (14, 159, 110)
LINE = (232, 235, 241)


def _is_cjk(ch):
    o = ord(ch)
    return (0x2E80 <= o <= 0x9FFF) or (0xF900 <= o <= 0xFAFF) or \
        (0xFF00 <= o <= 0xFFEF) or (0x3000 <= o <= 0x303F)


def f(size, bold=False):
    return ImageFont.truetype(FONT_CJK, size)


def _fonts(size, bold):
    cjk = ImageFont.truetype(FONT_CJK, size)
    latin = ImageFont.truetype(FONT_LATIN_BOLD if bold else FONT_LATIN, size)
    return cjk, latin


def measure(d, s, size=26, bold=False):
    cjk, latin = _fonts(size, bold)
    total = 0.0
    for run, is_cjk in _runs(s):
        total += d.textlength(run, font=cjk if is_cjk else latin)
    return total


def _runs(s):
    """把字符串切成「中文段 / 非中文段」"""
    out = []
    for ch in s:
        c = _is_cjk(ch)
        if out and out[-1][1] == c:
            out[-1] = (out[-1][0] + ch, c)
        else:
            out.append((ch, c))
    return out


def text(d, xy, s, size=26, color=INK, bold=False, anchor='la'):
    """按段用对应字体绘制；anchor 支持 la / ra / ma / mm"""
    cjk, latin = _fonts(size, bold)
    total = measure(d, s, size, bold)
    x, y = xy
    if anchor in ('ra', 'rm'):
        x -= total
    elif anchor in ('ma', 'mm'):
        x -= total / 2
    if anchor in ('mm',):
        y -= size / 2
    for run, is_cjk in _runs(s):
        ft = cjk if is_cjk else latin
        d.text((x, y), run, font=ft, fill=color,
               stroke_width=1 if bold else 0, stroke_fill=color)
        x += d.textlength(run, font=ft)


def round_rect(d, box, r, fill=None, outline=None, width=1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def shadow_card(img, box, r=28, blur=18, alpha=22):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(layer)
    dl.rounded_rectangle((box[0], box[1] + 6, box[2], box[3] + 6), radius=r,
                         fill=(23, 28, 38, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer)


def phone_frame(canvas):
    """整张图当作一块手机屏：外面留一点边，画个圆角+阴影，像展示图"""
    img = Image.new('RGBA', (W + 160, H + 160), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    # 外阴影
    for i in range(24, 0, -1):
        a = int(3 + (24 - i) * 0.7)
        d.rounded_rectangle((80 - i, 80 - i, 80 + W + i, 80 + H + i),
                            radius=64 + i, fill=(23, 28, 38, a))
    # 机身
    d.rounded_rectangle((80, 80, 80 + W, 80 + H), radius=64, fill=(255, 255, 255))
    screen = Image.new('RGBA', (W, H), BG + (255,))
    img.alpha_composite(screen, (80, 80))
    return img


def appbar(img, d, title, icons=True):
    d.rectangle((0, 0, W, 150), fill=BG)
    text(d, (56, 74), title, 40, INK, bold=True)
    if icons:
        for i, cx in enumerate((W - 150, W - 76)):
            d.ellipse((cx - 26, 62, cx + 26, 114), fill=(236, 240, 248))
            if i == 0:  # 搜索
                d.ellipse((cx - 9, 79, cx + 5, 93), outline=INK2, width=3)
                d.line((cx + 5, 93, cx + 12, 100), fill=INK2, width=3)
            else:  # 更多
                for k in (-8, 0, 8):
                    d.ellipse((cx + k - 3, 86, cx + k + 3, 92), fill=INK2)


def summary_card(img, d, y):
    box = (40, y, W - 40, y + 250)
    shadow_card(img, box)
    round_rect(d, box, 30, CARD)
    text(d, (76, y + 34), '本周汇总', 28, INK2)
    text(d, (W - 76, y + 34), '11-11 ~ 11-17', 24, INK3, anchor='ra')
    # 三个数字
    cols = [('1,360', '件', '数量'), ('¥1,038.60', '', '金额'), ('10', '条', '记录')]
    cw = (W - 152) // 3
    for i, (v, unit, label) in enumerate(cols):
        x = 76 + i * cw
        text(d, (x, y + 96), v, 46, PRIMARY if i == 1 else INK, bold=True)
        if unit:
            wv = measure(d, v, 46, True)
            text(d, (x + wv + 6, y + 112), unit, 24, INK2)
        text(d, (x, y + 168), label, 24, INK3)
    # 进度条（本周完成度示意）
    bar_y = y + 214
    round_rect(d, (76, bar_y, W - 76, bar_y + 12), 6, (233, 238, 250))
    round_rect(d, (76, bar_y, 76 + int((W - 152) * 0.68), bar_y + 12), 6, PRIMARY)


def record_card(img, d, y, rec):
    h = 190
    box = (40, y, W - 40, y + h)
    shadow_card(img, box, blur=14, alpha=16)
    round_rect(d, box, 26, CARD)
    # 缩略图：统一用 App 的「无图」占位（不拿生成图冒充货物实拍）
    round_rect(d, (66, y + 25, 206, y + 165), 20, (238, 241, 247))
    # 简单的「图片」图标：圆角矩形 + 太阳 + 山
    d.rounded_rectangle((96, y + 62, 176, y + 128), radius=8, outline=INK3, width=3)
    d.ellipse((106, y + 72, 118, y + 84), outline=INK3, width=3)
    d.line((100, y + 122, 128, y + 96), fill=INK3, width=3)
    d.line((128, y + 96, 146, y + 114), fill=INK3, width=3)
    d.line((146, y + 114, 160, y + 102), fill=INK3, width=3)
    d.line((160, y + 102, 172, y + 122), fill=INK3, width=3)
    text(d, (136, y + 136), '无图', 20, INK3, anchor='ma')
    # 型号 · 颜色 · 码数
    text(d, (232, y + 28), rec['title'], 32, INK, bold=True)
    text(d, (232, y + 82), rec['sub'], 24, INK2)
    text(d, (232, y + 124), rec['time'], 22, INK3)
    # 右侧数量 / 小计
    text(d, (W - 66, y + 28), rec['qty'], 34, INK, bold=True, anchor='ra')
    text(d, (W - 66, y + 84), rec['amount'], 26, GREEN, bold=True, anchor='ra')
    tag = rec.get('tag')
    if tag:
        tw = measure(d, tag, 20) + 24
        round_rect(d, (W - 66 - tw, y + 128, W - 66, y + 164), 10, (255, 243, 232))
        text(d, (W - 66 - tw / 2, y + 134), tag, 20, (196, 116, 40), anchor='ma')


def fab_and_nav(img, d, active=0):
    # FAB
    fx, fy = W - 250, H - 300
    shadow_card(img, (fx, fy, fx + 210, fy + 96), r=48, blur=16, alpha=40)
    round_rect(d, (fx, fy, fx + 210, fy + 96), 48, PRIMARY)
    text(d, (fx + 40, fy + 24), '＋', 44, (255, 255, 255), bold=True)
    text(d, (fx + 96, fy + 30), '记一笔', 28, (255, 255, 255), bold=True)
    # 底部导航
    d.rectangle((0, H - 170, W, H), fill=(252, 252, 254))
    d.line((0, H - 170, W, H - 170), fill=LINE, width=3)
    labels = ['记录', '报表', 'AI', '设置']
    for i, lb in enumerate(labels):
        cx = W // 8 + i * (W // 4)
        color = PRIMARY if i == active else INK3
        if i == active:
            round_rect(d, (cx - 54, H - 156, cx + 54, H - 96), 30,
                       (232, 239, 255))
        # 图标用简单几何表示
        cy = H - 126
        if i == 0:
            for k in range(3):
                d.line((cx - 16, cy - 12 + k * 12, cx + 16, cy - 12 + k * 12),
                       fill=color, width=3)
                d.ellipse((cx - 19, cy - 15 + k * 12, cx - 13, cy - 9 + k * 12),
                          fill=color)
        elif i == 1:
            d.line((cx - 18, cy + 10, cx - 6, cy - 4), fill=color, width=3)
            d.line((cx - 6, cy - 4, cx + 4, cy + 4), fill=color, width=3)
            d.line((cx + 4, cy + 4, cx + 18, cy - 12), fill=color, width=3)
        elif i == 2:
            d.polygon([(cx, cy - 14), (cx + 14, cy + 2), (cx - 14, cy + 2)],
                      outline=color, width=3)
        else:
            d.ellipse((cx - 13, cy - 13, cx + 13, cy + 13), outline=color, width=3)
        text(d, (cx, H - 66), lb, 22, color, anchor='ma')


RECORDS = [
    dict(thumb=None, title='A1023 · 黑色 · M', sub='300 件 × ¥0.45',
         time='今天 18:30', qty='300 件', amount='¥135.00'),
    dict(thumb=None, title='B2087 · 米白 · S', sub='180 件 × ¥0.62',
         time='今天 13:10', qty='180 件', amount='¥111.60'),
    dict(thumb=None, title='B2087 · 藏青 · M', sub='420 件 × ¥0.58',
         time='昨天 17:20', qty='420 件', amount='¥243.60'),
    dict(thumb=None, title='C3311 · 灰色 · XL', sub='96 件 × ¥0.72',
         time='昨天 12:05', qty='96 件', amount='¥69.12', tag='已上报'),
    dict(thumb=None, title='E7712 · 未填颜色', sub='340 件 · 未计价',
         time='11-14 09:40', qty='340 件', amount='未计价'),
    dict(thumb=None, title='D5590 · 酒红 · L', sub='260 件 × ¥0.50',
         time='11-15 14:20', qty='260 件', amount='¥130.00'),
]


def home():
    frame = phone_frame(None)
    screen = Image.new('RGBA', (W, H), BG + (255,))
    d = ImageDraw.Draw(screen)
    appbar(screen, d, '计件记录')
    summary_card(screen, d, 186)
    y = 470
    for rec in RECORDS:
        record_card(screen, d, y, rec)
        y += 210
    fab_and_nav(screen, d, 0)
    frame.alpha_composite(screen, (80, 80))
    frame.save(os.path.join(OUT, 'home_records.png'))


def report():
    frame = phone_frame(None)
    screen = Image.new('RGBA', (W, H), BG + (255,))
    d = ImageDraw.Draw(screen)
    ld = d
    appbar(screen, ld, '报表')
    # 统计卡
    box = (40, 186, W - 40, 396)
    shadow_card(screen, box)
    round_rect(ld, box, 30, CARD)
    text(ld, (76, 218), '本周 11-11 ~ 11-17', 28, INK2)
    text(ld, (76, 268), '1,360 件', 52, INK, bold=True)
    text(ld, (76, 340), '合计 ¥1,038.60 · 10 条记录', 26, INK2)
    # 分组柱状图
    box2 = (40, 430, W - 40, 900)
    shadow_card(screen, box2)
    round_rect(ld, box2, 30, CARD)
    text(ld, (76, 462), '按型号分组', 30, INK, bold=True)
    text(ld, (W - 76, 466), '数量', 22, INK3, anchor='ra')
    groups = [('A1023', 690, 0.92), ('B2087', 810, 1.0), ('C3311', 596, 0.74),
              ('D5590', 260, 0.32), ('E7712', 340, 0.42)]
    maxv = max(g[1] for g in groups)
    gy = 530
    for name, v, _ in groups:
        text(ld, (76, gy + 6), name, 26, INK)
        text(ld, (W - 76, gy + 4), f'{v} 件', 24, INK2, anchor='ra')
        barw = int((W - 400) * v / maxv)
        round_rect(ld, (300, gy, 300 + barw, gy + 34), 17, (232, 239, 255))
        round_rect(ld, (300, gy, 300 + int(barw * 0.82), gy + 34), 17, PRIMARY)
        gy += 66
    # 明细
    box3 = (40, 934, W - 40, 1870)
    shadow_card(screen, box3)
    round_rect(ld, box3, 30, CARD)
    text(ld, (76, 966), '明细（10 条）', 30, INK, bold=True)
    rows = [('A1023 黑色 M', '300 件', '¥135.00'),
            ('A1023 黑色 L', '240 件', '¥108.00'),
            ('B2087 米白 S', '180 件', '¥111.60'),
            ('B2087 藏青 M', '420 件', '¥243.60'),
            ('C3311 灰色 XL', '96 件', '¥69.12'),
            ('D5590 酒红 L', '260 件', '¥130.00'),
            ('E7712 未填颜色', '340 件', '未计价'),
            ('A1023 白色 M', '150 件', '¥67.50')]
    ry = 1026
    for name, qty, amt in rows:
        ld.line((76, ry - 14, W - 76, ry - 14), fill=LINE, width=2)
        text(ld, (76, ry), name, 26, INK)
        text(ld, (W - 320, ry), qty, 24, INK2, anchor='ra')
        text(ld, (W - 76, ry), amt, 24, GREEN, anchor='ra', bold=True)
        ry += 90
    fab_and_nav(screen, ld, 1)
    frame.alpha_composite(screen, (80, 80))
    frame.save(os.path.join(OUT, 'report.png'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    home()
    report()
    print('wrote', OUT)
