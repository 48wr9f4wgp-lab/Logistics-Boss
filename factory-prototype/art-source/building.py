"""Static room and delivery vehicle for the same isometric projection as the floor simulation."""
import math
import numpy as np

def roof(s,x,span,end):
    B=s.box; a=np.array([x,-.45,1.89]); b=np.array([x+span,-.45,2.82]); slope=b-a
    along=slope/np.linalg.norm(slope);normal=np.cross(along,[0,1,0]);origin=(a+b)*.5
    s.add(1,'zinc',origin,(np.linalg.norm(slope)/2,.55,.044),.018,(along,(0,1,0),normal))
    for j in range(10):
        p=a+slope*(j+.25)/10+normal*.045;s.rod(p+[0,-.54,0],p+[0,.54,0],.019,'zinc')
    s.beam((x,.082,1.88),(x+span,.082,2.81),.070,.08,'brick')
    s.beam((x,-.99,1.88),(x+span,-.99,2.81),.070,.08,'brick')
    # Each pane sits between a sill and the sloping roof. The facets of the
    # glazed triangle also remain legible at the expanded factory's overview scale.
    steps=18
    for k in range(steps):
        xx=x+span*k/steps; height=(k+.40)/steps*.90
        B(xx,-.004,1.865,span/steps+.003,.026,height,'wired',.001)
    for j in range(1,6):
        xx=x+span*j/6; B(xx-.015,.026,1.86,.03,.034,.90*j/6,'green',.005)
    for i in range(3):
        yy=-.95+i*.33;B(x+span-.024,yy,1.87,.050,.316,.895,'zinc' if end else 'wired',.005)
        B(x+span+.014,yy,1.87,.03,.028,.895,'green',.003)
    B(x+span+.016,-.95,2.26,.027,.97,.032,'green',.004)
    B(x-.018,.014,1.81,span+.035,.10,.075,'brick',.008)

def room(s,w,h):
    B=s.box;R=s.rod
    # Furniture-quality base with a thin brass reveal and a separate road casting.
    B(-.55,-1.03,-.58,w+1.02,h+2.90,.36,'walnut',.085)
    B(-.535,-1.015,-.265,w+.99,h+2.87,.048,'brass',.014)
    B(-.53,-1.01,-.223,w+.98,h+2.86,.13,'apron',.043)
    B(-.13,-.15,-.13,w+.26,h+.29,.123,'galv',.027)
    for x in range(0,w,2):
        for y in range(0,h,2):B(x+.006,y+.006,-.057,1.988,1.988,.057,'concrete',.007)
    # Painted aisle wears through to the aggregate between incoming and dispatch.
    for yy in range(0,h,2):B(.035,yy+.009,.0006,.94,1.982,.0018,'walkway',0)
    for j in np.arange(.18,h-.20,.67):B(.91,j,.0025,.05,.37,.002,'yellow',.001)
    for xx,yy in ((.50,h*.50),(w-.57,h-.70)):
        R((xx,yy,.0026),(xx,yy,.010),.19,'iron')
        s.torus((xx,yy,.010),(0,0,1),.167,.009,'galv')
        for k in range(-2,3):
            span=math.sqrt(.14**2-(k*.045)**2)
            B(xx-span,yy+k*.045,.012,2*span,.017,.003,'dark',.001)
    for x in np.arange(.1,w-.3,1.42):B(x,h+1.38,-.092,.75,.046,.004,'cream',0)
    B(.05,h-.085,.0005,w-.10,.055,.003,'yellow',.001)
    for x in np.arange(.14,w-.11,.38):
        s.beam((x,h-.14,.007),(x+.09,h-.05,.007),.039,.008,'dark',.002)
    # Set the drain inside the curb. Repeated pale metal slots are visible at zoom.
    B(.38,h-.35,.001,w-.76,.107,.007,'dark',.002)
    for xx in np.arange(.41,w-.40,.10):B(xx,h-.339,.008,.041,.084,.004,'galv',.002)
    # Brass corner fasteners on the road and a short timber loading stop.
    for xx in (.04,w-.10):
        for yy in (h+.52,h+1.41):R((xx,yy,-.089),(xx,yy,-.080),.036,'brass')
    # Pier-and-window construction casts real frame shadows onto the usable slab.
    B(-.15,-.22,0,w+.30,.22,.55,'brickwork');B(-.12,-.015,0,w+.24,.064,.40,'brickwork')
    B(-.15,-.21,1.56,w+.30,.22,.24,'cream')
    count=round(w/2.6);span=w/count
    for i in range(count):
        a=i*span; ww=span-.39
        B(a-.065,-.195,.40,.24,.20,1.39,'cream')
        B(a-.064,-.016,.02,.095,.10,1.84,'brick')
        B(a-.10,-.008,.03,.16,.12,.12,'iron')
        B(a+.16,-.10,.56,ww,.06,.985,'wired',.005)
        for z in (.56,.99,1.535):B(a+.14,-.034,z,ww+.047,.078,.04,'green',.006)
        for j in range(5):B(a+.145+j*(ww/4),-.033,.56,.033,.08,.99,'green',.005)
        B(a+.113,-.052,.507,ww+.12,.15,.062,'galv',.01)
        for n in range(4):
            xx=a+.35+n*.37
            if xx<a+span-.12:B(xx,-.01,1.61,.023,.025,.17,'cream',.003)
        roof(s,a,span,i==count-1)
        x=a+span*.56
        s.chain([(x,.04,1.82),(x,.51,1.91),(x,.65,1.91),(x,.65,1.66)],.022,'dark')
        R((x,.65,1.58),(x,.65,1.68),.075,'green')
        R((x,.65,1.54),(x,.65,1.60),.145,'green')
        R((x,.65,1.51),(x,.65,1.55),.208,'green')
        R((x,.65,1.502),(x,.65,1.515),.194,'lamp')
    B(-.13,-.018,1.74,w+.26,.13,.10,'green')
    # Loading shutter, exit box and cable conduits.
    x=w-1.24
    B(x,.08,.02,1.03,.057,1.46,'shade')
    B(x+.08,.131,.08,.87,.015,.39,'dark',.002)
    for xx in (x+.12,x+.43,x+.82):B(xx,.142,.10,.021,.025,.33,'iron',.003)
    B(x+.04,.13,.04,.95,.20,.045,'galv',.004)
    B(x,.15,.46,1.03,.039,1.0,'galv',.006)
    B(x,.183,.444,1.03,.045,.042,'gasket',.006)
    R((x+.39,.228,.54),(x+.66,.228,.54),.016,'chrome')
    # Rolled steel rain hood, gussets and a caged amber service light.
    B(x-.14,.06,1.64,1.31,.39,.059,'brick',.012)
    B(x-.14,.410,1.612,1.31,.041,.07,'brick',.007)
    for xx in (x+.03,x+.95):s.beam((xx,.09,1.39),(xx,.395,1.64),.032,.037,'iron',.005)
    B(x-.17,.135,1.11,.086,.077,.23,'dark',.011)
    R((x-.127,.214,1.157),(x-.127,.214,1.274),.045,'ochre')
    for zz in (1.165,1.257):s.torus((x-.127,.214,zz),(0,0,1),.048,.007,'brass')
    for z in np.arange(.50,1.46,.109):B(x,.185,z,1.03,.034,.030,'steel',.009)
    for xx in (x-.066,x+1.03):B(xx,.05,0,.067,.18,1.52,'dark')
    B(x-.09,.035,1.46,1.21,.23,.16,'green',.024)
    for yy in (.077,.123):s.chain([(.14,yy,.46),(w-1.49,yy,.46),(w-1.44,yy,.49),(w-1.44,yy,.78)],.016,'steel')
    B(w-1.57,.04,.63,.25,.16,.38,'cream',.024);B(w-1.515,.202,.77,.13,.014,.12,'navy')
    B(w-1.51,.218,.729,.07,.01,.024,'red')
    # Left return, rack and an enamel filing chest immediately outside the floor.
    B(-.20,-.04,0,.20,h+.1,.34,'brickwork');B(-.20,-.04,.34,.20,4.63,.19,'brickwork')
    B(-.18,.00,1.45,.20,4.55,.18,'green')
    B(-.07,.10,.53,.054,4.34,.94,'wired')
    for yy in np.arange(.10,4.57,.75):B(-.025,yy,.48,.075,.055,1.01,'green',.007)
    B(-.015,.08,.96,.058,4.44,.045,'green');B(-.016,.04,.51,.12,4.52,.056,'galv')
    B(.018,2.73,.59,.08,1.72,.76,'walnut',.015)
    for i in range(7):
        yy=2.88+i*.214; ll=.22+(i%3)*.045
        s.chain([(.12,yy,1.22),(.12,yy+.022,1.22-ll),(.12,yy+.048,1.18-ll)],.020,'steel')
        if i<4:s.torus((.135,yy,1.245),(1,0,0),.044,.014,'steel')
        else:R((.14,yy+.02,1.20-ll),(.14,yy+.04,1.11-ll),.030,'red' if i%2 else 'green')
    B(-.61,3.48,.025,.48,1.20,.79,'red',.037);B(-.64,3.45,.80,.54,1.26,.069,'dark')
    for j in range(6):
        B(-.116,3.54,.12+j*.104,.025,1.08,.091,'red',.009)
        R((-.079,3.63,.178+j*.104),(-.079,4.52,.178+j*.104),.016,'chrome')
    for xx in (-.07,w+.08):
        R((xx,h+.12,-.09),(xx,h+.12,.46),.055,'yellow');R((xx,h+.12,.15),(xx,h+.12,.28),.057,'dark')
    # Front-facing drawer handles, pressure gauges and coiled hose add scale.
    for j in range(6):
        B(-.58,4.685,.112+j*.107,.40,.022,.094,'red',.008)
        R((-.527,4.719,.181+j*.107),(-.24,4.719,.181+j*.107),.015,'chrome')
    s.torus((w+.21,1.30,.45),(1,0,0),.210,.027,'rubber')
    s.torus((w+.24,1.30,.45),(1,0,0),.166,.026,'green')
    # Painted fascia plaque, four rivets and an old station clock.
    mid=w*.51
    B(mid-1.20,.061,1.49,2.40,.103,.50,'dark',.031)
    B(mid-1.155,.161,1.526,2.31,.021,.428,'enamel',.024)
    B(mid-1.11,.183,1.559,2.22,.008,.020,'brick',.004)
    B(mid-1.11,.183,1.905,2.22,.008,.020,'brick',.004)
    for xx in (mid-1.10,mid+1.10):
        for zz in (1.60,1.87):R((xx,.182,zz),(xx,.198,zz),.018,'brass')
    xx=w-2.07
    R((xx,.087,1.24),(xx,.183,1.24),.16,'dark')
    R((xx,.181,1.24),(xx,.197,1.24),.140,'cream')
    R((xx,.201,1.24),(xx-.061,.201,1.302),.009,'dark')
    R((xx,.201,1.24),(xx+.084,.201,1.255),.008,'dark')
    # Steel fire bottle with bracket, valve, hose and cream inspection band.
    R((.22,2.63,.055),(.22,2.63,.61),.089,'red')
    s.ball((.22,2.63,.60),.088,'red')
    R((.22,2.63,.62),(.22,2.63,.73),.027,'brass')
    R((.20,2.63,.73),(.32,2.63,.73),.020,'dark')
    s.chain([(.27,2.63,.70),(.34,2.66,.62),(.33,2.66,.30)],.016,'rubber')
    R((.22,2.63,.35),(.22,2.63,.43),.09,'cream')
    # Roof extractor with rolled sheet seams and a mushroom rain cap.
    x=w-1.65;y=-.73
    R((x,y,2.15),(x,y,3.10),.161,'galv')
    for zz in (2.65,2.97,3.09):s.torus((x,y,zz),(0,0,1),.162,.015,'chrome')
    for xx in (x-.10,x+.10):R((xx,y,3.1),(xx,y,3.24),.018,'dark')
    R((x,y,3.24),(x,y,3.285),.23,'galv')
    # A belt-driven rooftop cyclone with a curved intake and dust collector.
    # It is behind the glazed wall, clear of workers and selectable floor cells.
    cx=w/count*.63;cy=-.61
    B(cx-.25,cy-.24,2.53,.50,.48,.075,'brick',.018)
    for dx in (-.17,.17):
        for dy in (-.13,.13):R((cx+dx,cy+dy,2.54),(cx+dx,cy+dy,2.82),.028,'iron')
    R((cx,cy,2.76),(cx,cy,3.06),.217,'galv',bevel=.034)
    for z,r in ((2.80,.218),(3.03,.218),(3.09,.17)):
        s.torus((cx,cy,z),(0,0,1),r,.017,'steel')
    R((cx,cy,3.04),(cx,cy,3.12),.174,'galv')
    R((cx,cy,3.11),(cx,cy,3.18),.104,'dark')
    R((cx,cy,3.17),(cx,cy,3.22),.188,'galv',bevel=.014)
    s.chain([(cx+.08,cy,2.94),(cx+.40,cy,2.94),(cx+.52,cy,2.86),(cx+.54,cy,2.71)],.094,'galv')
    # Horizontal gutter, gooseneck and strapped copper downpipe at the first pier.
    R((.02,.090,1.80),(w-.02,.090,1.80),.047,'galv')
    s.chain([(.14,.11,1.81),(.14,.22,1.69),(.14,.22,.22),(.18,.26,.14),(.25,.28,.14)],.041,'brick')
    for z in (.38,1.13,1.57):
        R((.14,.22,z),(.14,.22,z+.035),.05,'brass')
    # Gridded copper heat exchanger on the outside, ducted into the roof.
    ex=w*.54
    B(ex-.40,-.81,2.39,.80,.41,.43,'galv',.036)
    B(ex-.36,-.402,2.45,.72,.019,.29,'dark',.008)
    for i in range(9):B(ex-.33+i*.077,-.389,2.465,.023,.022,.25,'galv',.004)
    for xx in (ex-.43,ex+.38):B(xx,-.85,2.36,.07,.53,.073,'iron',.012)
    # Exterior storage shelves and compressed-air receiver.
    for xx in (w+.15,w+.51):
        for yy in (.05,.86):B(xx,yy,.015,.044,.044,.85,'green',.005)
    for zz in (.10,.45,.83):B(w+.12,.02,zz,.47,.9,.045,'galv',.008)
    for yy in (.09,.38,.64):B(w+.17,yy,.49,.32,.20,.24,'oak',.008)
    R((w+.25,1.39,.09),(w+.25,1.39,.72),.16,'turq');s.ball((w+.25,1.39,.71),.157,'turq')
    s.chain([(w+.25,1.40,.83),(w+.25,1.59,.83),(w+.20,1.71,.47),(w+.20,1.77,.13)],.024,'rubber')

def vehicle(s):
    B=s.box;R=s.rod
    B(.01,.072,.22,2.14,.62,.14,'dark',.03)
    for x in (.40,1.73):
        for y in (.075,.68):
            R((x,y-.055,.23),(x,y+.055,.23),.187,'rubber',bevel=.021)
            R((x,y+.047,.23),(x,y+.065,.23),.098,'steel',bevel=.009)
            R((x,y+.065,.23),(x,y+.073,.23),.049,'dark')
    B(.014,.07,.39,1.42,.62,.078,'cream',.02)
    for y in (.067,.648):B(.015,y,.46,1.41,.048,.23,'cream',.015)
    B(.016,.085,.454,.053,.59,.235,'cream',.012)
    for x in np.arange(.12,1.37,.215):B(x,.696,.49,.029,.014,.15,'white',.004)
    for x in np.arange(.12,1.32,.10):B(x,.15,.474,.014,.47,.009,'galv',.001)
    B(1.46,.075,.35,.64,.62,.45,'cream',.058)
    B(1.46,.069,.381,.63,.634,.105,'green',.028)
    B(1.50,.095,.75,.49,.58,.273,'navy',.046)
    B(1.496,.089,.995,.51,.59,.064,'cream',.026)
    for y in (.085,.657):
        B(1.52,y,.763,.035,.032,.232,'cream');B(1.935,y,.77,.035,.032,.227,'cream')
    B(1.986,.153,.80,.018,.475,.16,'shade',.011)
    B(2.059,.078,.32,.112,.64,.12,'galv',.031)
    for y in (.125,.547):B(2.094,y,.56,.017,.112,.072,'lamp',.012)
    for z in (.47,.51):B(2.098,.252,z,.019,.284,.020,'dark',.005)
    B(2.117,.31,.355,.029,.158,.070,'yellow',.005)
    s.chain([(1.96,.69,.73),(1.98,.79,.82),(1.90,.81,.84)],.015,'dark')
    B(1.85,.795,.797,.094,.042,.091,'navy',.013)
    B(1.56,.699,.62,.093,.012,.023,'dark',.005)
