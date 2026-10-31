"""Returnable plate cases, braced shaft boxes and the actual cargo on the kei truck."""
from building import vehicle

def case(s,x,y,z,product):
    b=s.box
    length,width,height=(.43,.36,.30) if product=='plate' else (.72,.28,.235)
    strap='dark' if product=='plate' else 'turq'
    b(x,y,z,length,width,height,'oak',.012)
    for xx in (x+.075,x+length-.097):
        b(xx,y-.005,z+.008,.024,width+.010,height,'steel' if product=='plate' else strap,.004)
    for yy in (y+.018,y+width-.044):
        b(x-.01,yy,z+height-.01,length+.02,.033,.038,'walnut',.005)
    b(x+.145,y+width+.002,z+.09,.126,.006,.087,'paper',.002)
    for i in range(3):
        b(x+.156+i*.030,y+width+.009,z+.108,.012,.004,.035,'dark',.001)
    if product=='shaft':
        s.beam((x+.022,y-.01,z+.025),(x+length-.020,y-.01,z+height-.033),.032,.024,'walnut',.003)
        b(x+.05,y+width+.008,z+.03,length-.1,.014,.028,'walnut',.003)

def build(s,key):
    if key=='pallet':
        for yy in (.055,.49):
            s.box(.025,yy,0,.69,.12,.108,'walnut',.012)
        for i in range(5):
            yy=.018+i*.128
            s.box(0,yy,.11,.72,.111,.060,'oak',.008)
            for xx in (.045,.675):s.rod((xx,yy+.05,.168),(xx,yy+.05,.174),.011,'dark')
        return
    product=key.split('-')[0]
    if '-' not in key:
        case(s,0,0,0,product)
        return
    vehicle(s)
    count=int(key.split('-')[1])
    if product=='plate':
        for i in range(count):case(s,.10+i*.49,.18,.475,'plate')
    else:
        for i in range(count):case(s,.18,.107+i*.282,.475,'shaft')
