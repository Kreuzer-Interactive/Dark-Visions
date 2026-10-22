"""Validate indexed assets, hotspot geometry, and world connectivity."""
from pathlib import Path
from PIL import Image
import json, hashlib
root=Path(__file__).resolve().parents[1]
rooms=json.loads((root/'ART/vga-world.json').read_text())
pal=None; hashes=set()
for n,r in enumerate(rooms,1):
    im=Image.open(root/f'VGA/RM{n:02}.BMP')
    assert im.mode=='P' and im.size==(320,154), n
    if pal is None: pal=im.getpalette()
    assert im.getpalette()==pal, f'Palette drift: room {n}'
    hashes.add(hashlib.sha256(im.tobytes()).hexdigest())
    assert len(r['hotspots'])<=12
    for h in r['hotspots']:
        x,y,xx,yy=h['rect']
        assert 0<=x<xx<320 and 0<=y<yy<154,(n,h['name'])
        if h['kind']==1: assert 1<=h['value']<=16
assert len(hashes)==16, 'Every background must be distinct'
im=Image.open(root/'VGA/CAR.BMP')
assert im.mode=='P' and im.size==(320,154) and im.getpalette()==pal
for n in range(9):
    im=Image.open(root/f'VGA/CHAR{n:02}.BMP')
    assert im.mode=='P' and im.size==(48,88) and im.getpalette()==pal
    assert 227 in im.tobytes(), 'Sprite transparency absent'
    opaque=Image.frombytes('L',im.size,bytes(0 if i==227 else 255 for i in im.tobytes())).getbbox()
    assert opaque and opaque[3]-opaque[1]>=82, 'Character does not fill its height'
for r in rooms:
    s=r['staging']; half=round(s['height']*24/88)
    assert 72<=s['height']<=88 and s['floor_y']<171
    assert half<=s['left']<=s['spawn_x']<=s['right']<320-half
    for h in r['hotspots']:
        if h['kind']==4:
            x,y,xx,yy=h['rect']
            assert yy-y+1==s['height']+yy-s['floor_y']
faces=set()
for n in range(7):
    im=Image.open(root/f'VGA/FACE{n:02}.BMP')
    assert im.mode=='P' and im.size==(80,96) and im.getpalette()==pal
    faces.add(hashlib.sha256(im.tobytes()).hexdigest())
assert len(faces)==7, 'Portraits must be distinct'
im=Image.open(root/'VGA/YOU.BMP')
assert im.mode=='P' and im.size==(48,64) and im.getpalette()==pal
expressions=set()
for person in [0,1,2,3,4,5,6,8]:
    for mood in range(4):
        levels=[]
        for state,size in [('A',(96,104)),('L',(72,80))]:
            im=Image.open(root/f'VGA/P{person}{mood}{state}.BMP')
            assert im.mode=='P' and im.size==size and im.getpalette()==pal
            pixels=im.tobytes()
            assert pixels.count(227)>len(pixels)//5, 'Portrait must overlay scenery'
            assert all(im.getpixel(p)==227 for p in [(0,0),(size[0]-1,0),(0,size[1]-1),(size[0]-1,size[1]-1)])
            colors=[sum(pal[i*3:i*3+3])/3 for i in pixels if i!=227]
            levels.append(sum(colors)/len(colors))
            if state=='A': expressions.add(hashlib.sha256(pixels).hexdigest())
        assert levels[1]<levels[0]*0.85, 'Listener should be visibly dimmer'
assert len(expressions)==32, 'Every character needs four distinct expressions'
def reachable(flags):
    found={1};todo=[1]
    while todo:
        for h in rooms[todo.pop()-1]['hotspots']:
            if h['kind']==1 and (h['need']==0 or h['need'] in flags) and h['value'] not in found:
                found.add(h['value']);todo.append(h['value'])
    return found
assert reachable(set())=={1}, 'Invitation gate bypass'
assert not ({9,10,11,12,15,16}&reachable({1})), 'Clock bypass through lake'
assert len(reachable({1,2,9}))==16, 'Unreachable room'
print(f'PASS: 16 indexed rooms and car opening, shared palette, 9 masked sprites, 32 expressions in 64 masked portraits, all {sum(len(r["hotspots"]) for r in rooms)} hotspots, gated room graph.')
