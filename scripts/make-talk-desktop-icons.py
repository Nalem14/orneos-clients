#!/usr/bin/env python3
"""Generates every image of the Orneos Meet desktop app (nextcloud/talk-desktop) into talk-desktop/img/, from the
Orneos "meet" camera: app icons, logos, tray icons (Windows, macOS, Linux; light and dark), Squirrel splash, .icns.
They replace the Nextcloud Talk trademark images of the same name. Needs ImageMagick. Run, then commit."""
import os, struct, subprocess, sys, tempfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'talk-desktop', 'img')
os.makedirs(os.path.join(ROOT, 'icons'), exist_ok=True)
BLUE, SAFFRON, WHITE, BLACK = '#002FA7', '#F0A202', '#FFFFFF', '#000000'

def glyph(frame, lens, width=1.8):
    return (f'<path d="M3 5h12v11H8l-3.5 3v-3H3z" fill="none" stroke="{frame}" stroke-width="{width}" stroke-linejoin="round"/>'
            f'<path d="M6 9.2h6M6 12.2h4" fill="none" stroke="{frame}" stroke-width="{width}" stroke-linecap="round"/>'
            f'<path d="M15 9l6-3v9l-6-3z" fill="none" stroke="{lens}" stroke-width="{width}" stroke-linejoin="round"/>')

def svg(name, body, view='0 0 24 24'):
    with open(os.path.join(ROOT, name), 'w') as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}">{body}</svg>\n')

def tile(rx, pad=0.0, scale=0.75):
    """Blue tile with the Meet glyph; pad = transparent margin around the tile (fraction of 24)."""
    s = 24 - 2 * pad * 24
    o = pad * 24
    inner = f'<g transform="translate({o + (s - s * scale) / 2} {o + (s - s * scale) / 2}) scale({s * scale / 24})">{glyph(WHITE, SAFFRON)}</g>'
    return f'<rect x="{o}" y="{o}" width="{s}" height="{s}" rx="{rx * s / 24}" fill="{BLUE}" stroke="none"/>' + inner

# App icons
svg('talk-icon-rounded.svg', tile(5.3))
svg('talk-icon-square.svg', tile(0))
svg('talk-icon-rounded-spaced.svg', tile(5.3, pad=0.1))
svg('talk-icon-mac.svg', tile(5.3, pad=0.1))          # macOS grid: ~10 % margin
svg('talk-icon-mac-shadow.svg', tile(5.3, pad=0.1))
# Plain glyphs: "light" = for light backgrounds (dark glyph), "dark" = for dark backgrounds (white glyph)
svg('talk-icon-plain-light.svg', glyph(BLUE, SAFFRON))
svg('talk-icon-plain-dark.svg', glyph(WHITE, SAFFRON))
svg('talk-icon-plain-spaced-light.svg', f'<g transform="translate(2.4 2.4) scale(.8)">{glyph(BLUE, SAFFRON)}</g>')
svg('talk-icon-plain-spaced-dark.svg', f'<g transform="translate(2.4 2.4) scale(.8)">{glyph(WHITE, SAFFRON)}</g>')
# Logos shown on the brand background (white)
svg('talk-logo.svg', glyph(WHITE, WHITE, 1.6), view='0 2 24 20')
svg('talk-logo-spaced.svg', f'<g transform="translate(3 3) scale(.75)">{glyph(WHITE, WHITE, 1.6)}</g>')
# Server logo: the Orneos 3C Prism mark, white
svg('server-logo-plain.svg', '<path d="M21.4 3.2C11.2 2 2.8 9.8 2.8 19.4c0 2.4.6 4.6 1.6 6.6L11 19.4c-.8-5 2.8-9.6 7.8-10l2.6-6.2z" fill="#fff" stroke="none"/>'
    '<path d="M32.8 16.2c.8 9.4-6.6 17-16 17-4 0-7.7-1.5-10.4-4.2l6.6-6.6c3.8 3.4 9.8 2.6 12.6-2.2l7.2-4z" fill="#fff" fill-opacity=".8" stroke="none"/>'
    '<path d="M24.4 4.2c4.4 2 7.4 5.8 8.2 9.4l-6.8 3.8c-.8-3.4-3-6-6-7.2l4.6-6z" fill="#fff" stroke="none"/>', view='-18 0 72 36')

def raster(svgfile, size, out, extra=()):
    subprocess.run(['convert', '-background', 'none', '-density', str(max(72, size * 6)), os.path.join(ROOT, svgfile),
                    '-resize', f'{size}x{size}', '-gravity', 'center', '-extent', f'{size}x{size}', *extra,
                    '-strip', '-define', 'png:exclude-chunk=date,time', out], check=True)

def ico(svgfile, out, sizes=(16, 24, 32, 48, 64, 256)):
    with tempfile.TemporaryDirectory() as t:
        pngs = []
        for s in sizes:
            p = os.path.join(t, f'{s}.png'); raster(svgfile, s, p); pngs.append(p)
        subprocess.run(['convert', *pngs, os.path.join(ROOT, 'icons', out)], check=True)

raster('talk-icon-rounded-spaced.svg', 512, os.path.join(ROOT, 'icons', 'icon.png'))
ico('talk-icon-rounded.svg', 'icon.ico')

# Tray: colored, "Light" = for light taskbars (black glyph), "Dark" = for dark taskbars (white glyph)
svg('.tray-color.svg', glyph(BLUE, SAFFRON, 2.2))
svg('.tray-black.svg', glyph(BLACK, BLACK, 2.2))
svg('.tray-white.svg', glyph(WHITE, WHITE, 2.2))
for name, src in [('IconTrayLinux.png', '.tray-color.svg'), ('IconTrayLinuxLight.png', '.tray-black.svg'), ('IconTrayLinuxDark.png', '.tray-white.svg')]:
    raster(src, 32, os.path.join(ROOT, 'icons', name))
for name, src in [('IconTrayMac', '.tray-color.svg'), ('IconTrayMacTemplate', '.tray-black.svg')]:
    raster(src, 16, os.path.join(ROOT, 'icons', name + '.png'))
    raster(src, 32, os.path.join(ROOT, 'icons', name + '@2x.png'))
ico('.tray-color.svg', 'IconTrayWin32.ico', (16, 24, 32, 48, 64))
ico('.tray-black.svg', 'IconTrayWin32Light.ico', (16, 24, 32, 48, 64))
ico('.tray-white.svg', 'IconTrayWin32Dark.ico', (16, 24, 32, 48, 64))
for f in ('.tray-color.svg', '.tray-black.svg', '.tray-white.svg'):
    os.remove(os.path.join(ROOT, f))

# Squirrel (Windows installer) splash: the icon on the brand blue, 312x504 like the original
subprocess.run(['convert', '-size', '312x504', f'xc:{BLUE}', '(', '-background', 'none', '-density', '600',
                os.path.join(ROOT, 'talk-icon-plain-dark.svg'), '-resize', '220x220', ')', '-gravity', 'center',
                '-composite', '-strip', os.path.join(ROOT, 'squirrel-install-loading.gif')], check=True)

# DMG window background (drag the app onto Applications), 658x498 and @2x, slots where Talk Desktop places the icons
for scale, name in [(1, 'dmg-background.png'), (2, 'dmg-background@2x.png')]:
    k = lambda v: str(v * scale)
    subprocess.run(['convert', '-size', f'{658 * scale}x{498 * scale}', 'gradient:' + BLUE + '-#0A1F66', '-rotate', '0',
                    '-fill', 'rgba(255,255,255,0.14)', '-stroke', 'none',
                    '-draw', f'roundrectangle {k(129)},{k(295)} {k(255)},{k(419)} {k(12)},{k(12)}',
                    '-draw', f'roundrectangle {k(385)},{k(295)} {k(511)},{k(419)} {k(12)},{k(12)}',
                    '-fill', 'none', '-stroke', SAFFRON, '-strokewidth', k(6), '-draw', 'stroke-linecap round',
                    '-draw', f'line {k(310)},{k(337)} {k(330)},{k(357)}', '-draw', f'line {k(330)},{k(357)} {k(310)},{k(377)}',
                    '-strip', '-define', 'png:exclude-chunk=date,time', os.path.join(ROOT, name)], check=True)

# macOS .icns: PNG chunks (ic07 128, ic08 256, ic09 512, ic10 1024@2x, ic11 32 = 16@2x, ic12 64 = 32@2x, ic13 256 = 128@2x, ic14 512 = 256@2x)
chunks = b''
with tempfile.TemporaryDirectory() as t:
    for code, size in [(b'ic11', 32), (b'ic12', 64), (b'ic07', 128), (b'ic13', 256), (b'ic08', 256), (b'ic14', 512), (b'ic09', 512), (b'ic10', 1024)]:
        p = os.path.join(t, f'{size}.png'); raster('talk-icon-mac.svg', size, p)
        data = open(p, 'rb').read()
        chunks += code + struct.pack('>I', len(data) + 8) + data
with open(os.path.join(ROOT, 'icons', 'icon.icns'), 'wb') as f:
    f.write(b'icns' + struct.pack('>I', len(chunks) + 8) + chunks)
print('talk-desktop images ok')
