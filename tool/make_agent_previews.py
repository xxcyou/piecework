#!/usr/bin/env python3
"""生成 README 主打的「Agent」示意图（对话 / 终端）。

脚本绘制，不是真机截图；中文与数字分别用 CJK / 拉丁字体，避免方块。

跑法：python3 tool/make_agent_previews.py
产物：docs/screenshots/agent_chat.png, agent_terminal.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

FONT_CJK = '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf'
FONT_LATIN = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_LATIN_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_MONO = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
OUT = os.path.join(os.path.dirname(__file__), '..', 'docs', 'screenshots')

W, H = 1080, 2160
BG = (246, 247, 251)
CARD = (255, 255, 255)
INK = (26, 29, 36)
INK2 = (110, 118, 132)
INK3 = (156, 163, 175)
PRIMARY = (46, 107, 255)
GREEN = (14, 159, 110)
ORANGE = (232, 131, 12)
LINE = (230, 234, 242)
DARK = (24, 27, 33)


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


def _fonts(size, bold, mono=False):
    if mono:
        f = ImageFont.truetype(FONT_MONO, size)
        return f, f
    return (ImageFont.truetype(FONT_CJK, size),
            ImageFont.truetype(FONT_LATIN_BOLD if bold else FONT_LATIN, size))


def measure(d, s, size, bold=False, mono=False):
    cjk, latin = _fonts(size, bold, mono)
    return sum(d.textlength(run, font=cjk if c else latin) for run, c in _runs(s))


def text(d, xy, s, size=24, color=INK, bold=False, anchor='la', mono=False):
    cjk, latin = _fonts(size, bold, mono)
    total = measure(d, s, size, bold, mono)
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


def wrap(d, s, size, maxw, bold=False):
    """按宽度折行（中英混排按字符切）"""
    lines, cur = [], ''
    for ch in s:
        if measure(d, cur + ch, size, bold) <= maxw:
            cur += ch
        else:
            lines.append(cur)
            cur = ch
    if cur:
        lines.append(cur)
    return lines


def frame():
    img = Image.new('RGBA', (W + 120, H + 120), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    for i in range(20, 0, -1):
        d.rounded_rectangle((60 - i, 60 - i, 60 + W + i, 60 + H + i),
                            radius=56 + i, fill=(23, 28, 38, 3 + (20 - i)))
    d.rounded_rectangle((60, 60, 60 + W, 60 + H), radius=56, fill=(255, 255, 255))
    screen = Image.new('RGBA', (W, H), BG + (255,))
    img.alpha_composite(screen, (60, 60))
    return img


def bubble_user(d, y, lines, maxw=740):
    """右侧蓝色气泡"""
    pad = 26
    h = sum(30 for _ in lines) + pad * 2
    x1 = W - 40
    x0 = x1 - maxw
    d.rounded_rectangle((x0, y, x1, y + h), radius=24, fill=PRIMARY)
    ty = y + pad
    for ln in lines:
        text(d, (x0 + pad, ty), ln, 27, (255, 255, 255))
        ty += 30
    return y + h


def tool_row(d, y, icon, title, detail, accent=PRIMARY):
    """AI 气泡里的工具行"""
    d.rounded_rectangle((40, y, W - 40, y + 62), radius=12,
                        fill=(248, 250, 254), outline=LINE, width=2)
    d.ellipse((58, y + 20, 78, y + 40), fill=accent)
    text(d, (86, y + 18), title, 24, INK, bold=True)
    text(d, (86 + measure(d, title, 24, True) + 14, y + 20), detail, 21, INK2)
    return y + 72


def diff_block(d, y):
    """修改前后对比（双条形图 + 差值）"""
    d.rounded_rectangle((40, y, W - 40, y + 250), radius=14,
                        fill=(247, 250, 248), outline=(206, 226, 214), width=2)
    text(d, (62, y + 16), '修改前后', 22, GREEN, bold=True)
    rows = [('数量合计', '300 片', '350 片', '+50', 300, 350, '片'),
            ('金额合计', '¥135.00', '¥157.50', '+¥22.50', 135, 157.5, '')]
    ry = y + 56
    for label, before, after, delta, b, a, unit in rows:
        text(d, (62, ry), label, 21, INK2)
        text(d, (200, ry - 2), f'{before} → {after}', 23, INK, bold=True)
        dw = measure(d, delta, 19, True) + 20
        d.rounded_rectangle((W - 62 - dw, ry - 2, W - 62, ry + 26), radius=8,
                            fill=(226, 245, 236))
        text(d, (W - 62 - dw / 2, ry), delta, 19, GREEN, bold=True, anchor='ma')
        # 双条
        bx0, bx1 = 200, W - 80
        maxv = max(b, a)
        for k, (val, color, tag) in enumerate(((b, (196, 202, 214), '原'),
                                               (a, GREEN, '新'))):
            by = ry + 38 + k * 20
            text(d, (62, by - 4), tag, 17, INK3)
            d.rounded_rectangle((bx0, by, bx1, by + 12), radius=6, fill=(234, 238, 244))
            w = int((bx1 - bx0) * val / maxv)
            d.rounded_rectangle((bx0, by, bx0 + max(18, w), by + 12), radius=6, fill=color)
        ry += 96
    return y + 250


def input_bar(d):
    y = H - 130
    d.rounded_rectangle((30, y, W - 30, y + 92), radius=26, fill=CARD,
                        outline=LINE, width=2)
    text(d, (58, y + 28), '问点什么，比如「本周多少件」', 24, INK3)
    d.ellipse((W - 118, y + 16, W - 54, y + 80), fill=PRIMARY)
    d.polygon([(W - 100, y + 34), (W - 100, y + 62), (W - 72, y + 48)],
              fill=(255, 255, 255))


def appbar(d, title, chip=''):
    d.rectangle((0, 0, W, 132), fill=BG)
    text(d, (40, 62), title, 36, INK, bold=True)
    if chip:
        cw = measure(d, chip, 20) + 28
        d.rounded_rectangle((40 + measure(d, title, 36, True) + 18, 66,
                             40 + measure(d, title, 36, True) + 18 + cw, 112),
                            radius=16, fill=(232, 239, 255))
        text(d, (40 + measure(d, title, 36, True) + 32, 74), chip, 20, PRIMARY, bold=True)


def agent_chat():
    img = frame()
    d = ImageDraw.Draw(img)
    appbar(d, 'AI 助手', '内置免费 · kilo')
    y = 160
    # 用户气泡（多需求）
    lines = wrap(d, '把昨天那批数量改成 350，顺便关联 #1 的图，再看看本周一共多少', 27, 660)
    y = bubble_user(d, y, lines) + 22

    # AI 气泡：先把内容画在透明层上，量出高度再画卡片（避免大片空白）
    box_top = y
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    y = box_top + 24
    # 计数徽标
    badge = '⚡+3'
    bw = measure(d, badge, 21, True) + 26
    d.rounded_rectangle((W - 70 - bw, y - 6, W - 70, y + 32), radius=12,
                        fill=(232, 239, 255), outline=(170, 196, 255), width=2)
    text(d, (W - 70 - bw / 2, y), badge, 21, PRIMARY, bold=True, anchor='ma')
    text(d, (60, y), '本次调用 3 次工具', 21, INK2)
    y += 56
    # 工具行
    y = tool_row(d, y, '', '查询记录', '2 条 · 300 片 · 昨天')
    y = tool_row(d, y, '', '修改记录', '数量 300 → 350（待确认）')
    y = tool_row(d, y, '', '关联图片', '#1 → 2 条记录（待确认）')
    y += 6
    y = diff_block(d, y) + 22
    # 正文
    body = ('已生成 2 张确认卡片（改数量 / 关联图片），你点确认后才生效。\n'
            '本周合计 1,360 片（≈ 680 件），金额 ¥1,038.60，共 10 条。')
    for ln in body.split('\n'):
        for seg in wrap(d, ln, 26, W - 130):
            text(d, (60, y), seg, 26, INK)
            y += 40
    y += 16
    # 动作按钮
    d.rounded_rectangle((60, y, 60 + 260, y + 58), radius=16,
                        fill=(232, 239, 255))
    text(d, (86, y + 14), '查看这批记录 →', 23, PRIMARY, bold=True)
    box_bottom = y + 58 + 26

    # 卡片底 + 内容
    card = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((30, box_top, W - 30, box_bottom), radius=26,
                         fill=CARD, outline=LINE, width=2)
    img.alpha_composite(card, (0, 0))
    img.alpha_composite(layer, (0, 0))

    d = ImageDraw.Draw(img)
    y2 = box_bottom + 22
    y2 = bubble_user(d, y2, ['再画一张本周的图，顺便说说怎么算的']) + 22

    # 第二张 AI 气泡：图表卡 + 计算过程卡
    top2 = y2
    layer2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(layer2)
    yy = top2 + 24
    badge2 = '⚡+2'
    bw2 = measure(d2, badge2, 21, True) + 26
    d2.rounded_rectangle((W - 70 - bw2, yy - 6, W - 70, yy + 32), radius=12,
                         fill=(232, 239, 255), outline=(170, 196, 255), width=2)
    text(d2, (W - 70 - bw2 / 2, yy), badge2, 21, PRIMARY, bold=True, anchor='ma')
    text(d2, (60, yy), '本次调用 2 次工具', 21, INK2)
    yy += 52

    # 图表卡（柱状图）
    d2.rounded_rectangle((40, yy, W - 40, yy + 300), radius=14, fill=(252, 253, 255),
                         outline=LINE, width=2)
    text(d2, (62, yy + 14), '本周数量（按天）', 22, INK, bold=True)
    bars = [180, 240, 210, 300, 260, 340, 320]
    bw, gap = 88, 32
    x0 = 70
    for i, v in enumerate(bars):
        h = int(v * 0.55)
        bx = x0 + i * (bw + gap)
        d2.rounded_rectangle((bx, yy + 260 - h, bx + bw, yy + 260), radius=8,
                             fill=PRIMARY if i == 6 else (206, 220, 250))
        text(d2, (bx + bw / 2, yy + 268), ['11', '12', '13', '14', '15', '16', '17'][i],
             18, INK3, anchor='ma')
    yy += 320

    # 计算过程卡
    d2.rounded_rectangle((40, yy, W - 40, yy + 190), radius=14,
                         fill=(246, 251, 248), outline=(206, 226, 214), width=2)
    text(d2, (62, yy + 14), '本周合计怎么算的', 22, GREEN, bold=True)
    steps = [('七天合计', '180+240+210+300+260+340+320', '1,850 片'),
             ('折算成件', '1,850 ÷ 2', '925 件')]
    sy = yy + 52
    for label, expr, res in steps:
        text(d2, (62, sy), label, 20, INK2)
        text(d2, (220, sy), expr, 21, INK)
        text(d2, (W - 62, sy), res, 21, GREEN, bold=True, anchor='ra')
        sy += 44
    yy += 190 + 24
    for seg in wrap(d2, '图里最高是 17 号 320 片；七天一共 1,850 片（≈ 925 件）。', 25, W - 130):
        text(d2, (60, yy), seg, 25, INK)
        yy += 38
    bottom2 = yy + 10

    card2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cd2 = ImageDraw.Draw(card2)
    cd2.rounded_rectangle((30, top2, W - 30, bottom2), radius=26, fill=CARD,
                          outline=LINE, width=2)
    img.alpha_composite(card2, (0, 0))
    img.alpha_composite(layer2, (0, 0))

    input_bar(ImageDraw.Draw(img))
    img.save(os.path.join(OUT, 'agent_chat.png'))


def agent_terminal():
    img = frame()
    d = ImageDraw.Draw(img)
    appbar(d, 'AI 助手')
    y = 150
    lines = wrap(d, '把 #1 的图关联到昨天那批，再用终端确认一下', 27, 660)
    y = bubble_user(d, y, lines) + 22

    # 终端卡片（深色）：先画内容，再按内容高度画底色
    top = y
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ty = top + 22
    # 标题行
    text(d, (58, ty), '终端 · linux · /etc', 22, (150, 200, 255), bold=True)
    chip = '运行中'
    cw = measure(d, chip, 18) + 22
    d.rounded_rectangle((W - 70 - cw, ty - 4, W - 70, ty + 28), radius=10,
                        fill=(38, 60, 44))
    text(d, (W - 70 - cw / 2, ty), chip, 18, (120, 220, 150), anchor='ma')
    ty += 52

    cmds = [
        ('$ ls /etc', (150, 220, 160)),
        ('alpine-release  hosts  passwd  resolv.conf', (170, 178, 190)),
        ('$ @query_records {"date_preset":"yesterday"} | head -3', (150, 220, 160)),
        ('{"ok": true, "recordCount": 2, ...}', (170, 178, 190)),
        ('$ @update_settings {"theme":"dark"}', (150, 220, 160)),
        ('{"ok": true, "status": "pending_user_confirmation"}', (170, 178, 190)),
        ('$ ❯', (150, 200, 255)),
    ]
    for s, color in cmds:
        for seg in wrap(d, s, 22, W - 130):
            text(d, (58, ty), seg, 22, color, mono=True)
            ty += 36
        ty += 6
    ty += 10
    text(d, (58, ty), '终端里 @工具名 是真命令，for/while 循环里也能用', 20, (140, 150, 165))
    ty += 40
    text(d, (58, ty), '写操作会生成确认卡片，点确认才落库', 20, (140, 150, 165))

    term_bottom = ty + 40
    card = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((30, top, W - 30, term_bottom), radius=26, fill=DARK)
    img.alpha_composite(card, (0, 0))
    img.alpha_composite(layer, (0, 0))
    d = ImageDraw.Draw(img)

    # AI 回复
    ry = term_bottom + 24
    d.rounded_rectangle((30, ry, W - 30, ry + 300), radius=26, fill=CARD,
                        outline=LINE, width=2)
    text(d, (60, ry + 24), '终端里查到的 2 条记录：#1 的图已关联，', 25, INK)
    text(d, (60, ry + 66), '昨天合计 300 片（≈ 150 件），¥135.00。', 25, INK)
    text(d, (60, ry + 118), '主题也切到深色了（待你点确认）。', 25, INK2)
    d.rounded_rectangle((60, ry + 186, 60 + 240, ry + 244), radius=16,
                        fill=(232, 239, 255))
    text(d, (86, ry + 200), '问 AI 这段 →', 23, PRIMARY, bold=True)

    # 确认卡片（修改前后）
    cy = ry + 300
    d.rounded_rectangle((30, cy, W - 30, cy + 470), radius=26,
                        fill=(247, 250, 248), outline=(206, 226, 214), width=3)
    text(d, (60, cy + 24), '待确认 · 影响 2 条', 26, GREEN, bold=True)
    text(d, (60, cy + 68), '修改 2 条记录：数量=350，图片=#1', 24, INK)
    diff_top = cy + 120
    diff_block(d, diff_top)
    d.rounded_rectangle((60, cy + 396, 60 + 220, cy + 452), radius=14, fill=GREEN)
    text(d, (86, cy + 410), '确认修改', 24, (255, 255, 255), bold=True)
    d.rounded_rectangle((300, cy + 396, 300 + 200, cy + 452), radius=14,
                        fill=(236, 239, 245))
    text(d, (326, cy + 410), '取消', 24, INK2, bold=True)
    input_bar(d)
    img.save(os.path.join(OUT, 'agent_terminal.png'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    agent_chat()
    agent_terminal()
    print('wrote', OUT)
