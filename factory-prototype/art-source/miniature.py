"""Build the original, orthographic Machikoba sprites. Requires Python, NumPy, Pillow and a C++17 compiler.
Run: python factory-prototype/art-source/miniature.py /path/to/scratch docs/forge-preview/art
"""
import json
import math
import os
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(__file__).resolve().parent
TAU = math.tau
MATS = {}
def material(name, color, metal=0, rough=.45, texture=0):
    rgb = [((int(color[k:k+2],16)/255)**2.2) for k in (0,2,4)]
    MATS[name] = (*rgb,metal,rough,texture)
for name,color in [('ochre','d78134'),('red','af4935'),('turq','3c8f93'),('blue','466e8b'),('mint','759c8b'),
                   ('olive','66755d'),('cream','dbd6b8'),('navy','364e58'),('black','303f44'),('green','426e66'),
                   ('brick','92583e'),('yellow','e2b856'),('white','e6e3c9')]:
    material(name,color,.16,.36,1)
for name,color,metal,rough in [('iron','626e6d',.67,.53),('dark','3b474b',.65,.42),('chrome','c6d0cf',.91,.19),
                              ('steel','a1b1b2',.82,.30),('brass','bf9960',.70,.29),('galv','91a29b',.62,.48)]:
    material(name,color,metal,rough,2)
material('rubber','293334',.04,.75)
material('oak','be9160',.05,.63,3)
material('walnut','885839',.04,.53,3)
material('paper','e6d8b4',0,.78)
material('slab','aea998',.02,.82,4)
material('asphalt','4c595d',.02,.87,4)
material('glass','bbd3c6',.10,.25,5)
material('lamp','ffe4a5',.02,.3,5)
material('shade','2a494b',.1,.62)
material('gasket','373e40',.05,.6)
material('skin','d5aa83',.01,.65)
material('hair','58493d',0,.74)
material('denim','42677d',.02,.69,1)
material('canvas','a8764f',.02,.73,1)
material('twill','558576',.02,.70,1)
material('wheel','535962',.34,.75,4)

EYE=np.eye(3)
class Scene:
    def __init__(self): self.rows=[]
    def add(self,k,mat,c,h,r=0,axes=EYE,layer=0):
        self.rows.append((k,list(MATS).index(mat),layer,*c,*h,r,*np.asarray(axes).flatten()))
    def box(self,x,y,z,w,d,h,mat,r=.01,layer=0):
        self.add(1,mat,(x+w/2,y+d/2,z+h/2),(w/2,d/2,h/2),min(r,w*.48,d*.48,h*.48),layer=layer)
    def rod(self,a,b,r,mat,layer=0,bevel=None):
        a,b=np.array(a),np.array(b); v=b-a; height=np.linalg.norm(v)
        self.add(2,mat,(a+b)/2,(r,r,height/2),min(r*.25 if bevel is None else bevel,height*.45),basis(v),layer)
    def chain(self,points,r,mat,layer=0):
        for a,b in zip(points,points[1:]): self.rod(a,b,r,mat,layer)
        for p in points[1:-1]: self.ball(p,r,mat,layer)
    def ball(self,c,r,mat,layer=0): self.add(3,mat,c,(r,r,r),layer=layer)
    def torus(self,c,axis,r,t,mat,layer=0): self.add(4,mat,c,(r,r,t),t,basis(axis),layer)
    def guard(self,c,axis,r,inner,thickness,mat,layer):
        self.add(5,mat,c,(r,inner,thickness/2),.006,basis(axis),layer)
    def beam(self,a,b,w,d,mat,r=.014):
        a,b=np.array(a),np.array(b);v=b-a
        self.add(1,mat,(a+b)/2,(w/2,d/2,np.linalg.norm(v)/2),min(r,w*.42,d*.42),basis(v))
def basis(v):
    z=np.asarray(v,float);z=z/np.linalg.norm(z)
    x=np.cross((0,0,1) if abs(z[2])<.96 else (0,1,0),z);x/=np.linalg.norm(x)
    return np.array([x,np.cross(z,x),z])
def wheel(s,c,axis,r,angle=0,mat='dark',layer=2,knob=False):
    x,y,z=c; a=basis(axis); normal=a[2]; center=np.array(c)
    s.torus(c,axis,r,.015,mat,layer)
    for i in range(3):
        th=angle+i*TAU/3; tip=center+r*(a[0]*math.cos(th)+a[1]*math.sin(th))
        s.rod(center,tip,.012,'steel',layer)
        if i==0 and knob:
            s.rod(tip,tip+normal*.045,.018,'chrome',layer);s.ball(tip+normal*.048,.032,'rubber',layer)
    s.rod(center-normal*.025,center+normal*.025,.035,'chrome',layer)
def badge(s,x,y,z,width,level):
    s.box(x,y,z,width,.012,.096,'dark',.006)
    s.box(x+.018,y+.014,z+.058,width*.66,.004,.011,'paper',0)
    for i in range(level):s.box(x+.019+i*.036,y+.015,z+.019,.023,.004,.014,'brass',0)
def foot(s):
    s.box(.08,.10,.025,.84,.79,.085,'dark',.026)
    for x in (.14,.85):
        for y in (.17,.80):
            s.rod((x,y,.105),(x,y,.127),.027,'steel')
            s.rod((x,y,.125),(x,y,.145),.017,'dark')
def cabinet(s,x,y,z,w,d,h,mat,level):
    s.box(x,y,z,w,d,h,mat,.036)
    s.box(x+.035,y+d-.006,z+.025,w-.07,.019,h-.05,'gasket',.012)
    s.box(x+.042,y+d+.007,z+.034,w-.084,.018,h-.067,mat,.012)
    for i in range(5):s.box(x+.08,y+d+.028,z+.075+i*.029,w*.25,.013,.012,'dark',.004)
    s.rod((x+w*.69,y+d+.047,z+h*.63),(x+w*.88,y+d+.047,z+h*.63),.014,'chrome')
    badge(s,x+w*.44,y+d+.027,z+.064,w*.38,level)
def saw(s,l,t,active):
    B=s.box;R=s.rod;foot(s)
    cabinet(s,.14,.15,.11,.68,.60,.43,'red',l)
    B(.087,.12,.54,.82,.68,.09,'dark',.027);B(.10,.135,.624,.79,.66,.039,'steel',.009)
    for y in (.29,.48,.67):B(.12,y,.662,.75,.016,.003,'dark',0)
    B(.24,.60,.668,.31,.071,.11,'iron',.015,1);B(.24,.31,.668,.31,.055,.10,'iron',.012)
    R((.38,.62,.725),(.38,.84,.725),.021,'chrome',1);wheel(s,(.38,.84,.725),(0,1,0),.066,0,'dark',1)
    B(.65,.125,.66,.17,.16,.30,'ochre',.035)
    R((.585,.195,.92),(.82,.195,.92),.072,'iron')
    s.chain([(.66,.20,.92),(.56,.31,1.02),(.51,.46,.96)],.073,'ochre',2)
    B(.19,.23,.67,.115,.35,.053,'iron')
    feed=(1+math.sin(t))*.065 if active else 0
    c=(.59,.46,.96-feed)
    R((.425,.46,c[2]),(.586,.46,c[2]),.11,'dark',2)
    for x in (.43,.463,.496):s.torus((x,.46,c[2]),(1,0,0),.107,.011,'iron',2)
    R((.584,.46,c[2]),(.605,.46,c[2]),.275,'wheel',2,0)
    s.torus((.608,.46,c[2]),(1,0,0),.263,.006,'steel',2)
    for i in range(4):
        a=i*TAU/4+t; R((.608,.46+.14*math.cos(a),c[2]+.14*math.sin(a)),(.611,.46+.21*math.cos(a),c[2]+.21*math.sin(a)),.012,'dark',2)
    s.guard((.588,.46,c[2]),(1,0,0),.306,.186,.14,'ochre',2)
    R((.60,.46,c[2]),(.66,.46,c[2]),.064,'chrome',2)
    s.chain([(.60,.46,1.22-feed),(.60,.68,1.27-feed),(.66,.95,1.06-feed)],.029,'dark',2)
    R((.633,.82,1.16-feed),(.66,.95,1.06-feed),.038,'rubber',2)
    if l>1:
        B(.11,.15,.666,.12,.22,.265,'navy',.019);B(.095,.16,.93,.15,.22,.035,'yellow',.008)
    if l>2:
        B(.75,.35,.67,.11,.21,.30,'cream');B(.766,.559,.82,.08,.009,.10,'shade');s.ball((.80,.57,.75),.023,'red')
def drill(s,l,t,active):
    B=s.box;R=s.rod;foot(s)
    B(.18,.17,.115,.59,.52,.073,'turq',.029)
    R((.43,.285,.17),(.43,.285,.37),.145,'turq');R((.43,.285,.29),(.43,.285,1.22),.080,'chrome')
    R((.43,.285,.48),(.43,.285,.62),.113,'iron')
    B(.25,.30,.52,.40,.29,.09,'turq',.023)
    B(.18,.31,.575,.57,.46,.066,'steel',.017)
    for x in (.25,.38,.51,.64):B(x,.36,.641,.020,.365,.004,'dark',0)
    B(.21,.68,.645,.19,.061,.09,'iron',.009,1);R((.25,.70,.718),(.25,.76,.76),.023,'dark',1)
    B(.25,.18,1.02,.40,.36,.21,'turq',.063,1)
    R((.43,.26,1.17),(.43,.26,1.245),.202,'turq',1)
    B(.16,.04,1.185,.54,.61,.19,'turq',.072,1);B(.197,.059,1.36,.47,.56,.039,'mint',.015,1)
    for i in range(6):B(.207+i*.063,.626,1.245,.033,.016,.052,'shade',.012,1)
    R((.43,.145,.91),(.43,.145,1.18),.122,'dark')
    for z in (.95,1,1.05,1.1):s.torus((.43,.145,z),(0,0,1),.121,.013,'iron')
    a=-.08+.55*math.sin(t) if active else .18
    z=.80+math.sin(a)*.18 if active else .86
    R((.445,.49,z-.015),(.445,.49,1.08),.053,'chrome',2)
    R((.445,.49,z-.074),(.445,.49,z+.004),.047,'dark',2)
    R((.445,.49,z-.142),(.445,.49,z-.055),.013,'steel',2)
    R((.64,.34,1.08),(.93,.34,1.08),.035,'chrome',1)
    for i in range(3):
        ang=a+i*TAU/3;tip=(.93,.34+.32*math.cos(ang),1.08+.32*math.sin(ang))
        R((.93,.34,1.08),tip,.016,'chrome',2);s.ball(tip,.043,'red' if i==0 else 'rubber',2)
    s.ball((.93,.34,1.08),.060,'steel',2)
    for z1 in np.arange(.36,.91,.065):B(.48,.31,z1,.027,.04,.022,'steel',.004)
    B(.17,.42,1.01,.11,.125,.177,'cream',.018,1);s.ball((.222,.55,1.11),.029,'red',1)
    if l>1:
        B(.15,.17,.26,.15,.23,.24,'mint',.02)
        s.chain([(.22,.22,.5),(.20,.16,.73),(.32,.30,.82)],.019,'dark')
    if l>2:
        B(.15,.11,.72,.18,.12,.28,'navy');B(.17,.228,.84,.14,.012,.12,'glass')
def lathe(s,l,t,active):
    B=s.box;R=s.rod;foot(s)
    cabinet(s,.10,.15,.11,.81,.60,.42,'blue',l)
    B(.085,.13,.53,.85,.65,.078,'dark',.025);B(.11,.17,.608,.79,.53,.044,'steel',.009)
    for y in (.31,.53):B(.18,y,.648,.66,.055,.038,'chrome',.01)
    R((.16,.727,.627),(.86,.727,.627),.022,'chrome')
    for xx in np.arange(.18,.85,.040):s.torus((xx,.727,.627),(1,0,0),.021,.005,'dark')
    for xx,zz in ((.152,.88),(.251,.91),(.20,.76)):
        R((xx,.647,zz),(xx,.672,zz),.029,'brass');s.ball((xx,.677,zz),.018,'dark')
    
    B(.09,.16,.64,.25,.49,.38,'blue',.047);B(.11,.19,1.01,.21,.43,.047,'navy',.018)
    R((.32,.43,.86),(.385,.43,.86),.146,'steel',2)
    for i in range(3):
        a=t*5+i*TAU/3;tip=(.389,.43+.115*math.cos(a),.86+.115*math.sin(a))
        R((.389,.43+.035*math.cos(a),.86+.035*math.sin(a)),tip,.026,'dark',2)
    B(.72,.25,.669,.15,.30,.17,'blue',.026);R((.70,.43,.86),(.80,.43,.86),.052,'chrome',1)
    B(.76,.32,.76,.09,.18,.15,'blue',.027)
    wheel(s,(.864,.43,.86),(1,0,0),.084,.45,'dark',1)
    slide=math.sin(t)*.08 if active else 0
    B(.44+slide,.52,.66,.21,.14,.11,'iron',.016,2)
    B(.48+slide,.49,.765,.13,.14,.068,'dark',.009,2);R((.55+slide,.55,.815),(.55+slide,.43,.85),.019,'brass',2)
    wheel(s,(.58+slide,.715,.74),(0,1,0),.104,math.pi-t,'dark',2,True)
    R((.20,.72,.65),(.30,.81,.72),.019,'chrome',1);s.ball((.30,.81,.72),.029,'rubber',1)
    R((.13,.65,.83),(.31,.65,.83),.018,'brass',1)
    if l>1:B(.16,.14,.65,.57,.065,.37,'mint',.025)
    if l>2:
        B(.76,.12,.84,.16,.11,.25,'cream');B(.77,.232,.95,.14,.008,.12,'shade')
def bench(s,l,t,active):
    B=s.box;R=s.rod;foot(s)
    for x in (.13,.76):
        for y in (.14,.68):B(x,y,.12,.073,.072,.60,'green',.012)
    B(.13,.14,.246,.68,.55,.042,'green',.009)
    B(.16,.24,.29,.29,.34,.18,'turq',.016);B(.18,.59,.33,.22,.025,.081,'navy')
    B(.13,.16,.51,.7,.53,.15,'green',.018)
    R((.39,.708,.58),(.57,.708,.58),.017,'chrome')
    B(.095,.10,.665,.80,.70,.112,'oak',.017)
    B(.21,.28,.777,.42,.386,.014,'green',.009);B(.65,.34,.78,.155,.231,.013,'paper',.003)
    for i in range(3):B(.668,.38+i*.045,.795,.106,.008,.002,'galv',0)
    s.chain([(.18,.18,.78),(.12,.18,1.09),(.43,.32,1.23)],.021,'dark',1)
    for p in ((.12,.18,1.09),(.43,.32,1.23)):s.ball(p,.039,'brass',1)
    R((.43,.32,1.17),(.43,.32,1.23),.073,'green',1)
    R((.43,.32,1.13),(.43,.32,1.19),.123,'green',1);R((.43,.32,1.12),(.43,.32,1.133),.118,'lamp',1)
    jaw=.54+.055*math.sin(t) if active else .56
    B(.225,.648,.825,.48,.030,.024,'steel',.005,2)
    for x in (.30,jaw):B(x-.012,.516,.829,.024,.15,.025,'chrome',.003,2)
    B(jaw-.024,.626,.834,.061,.06,.036,'dark',.006,2)
    # Dial comparator mounted clear of the hand caliper, with a steel probe and ivory dial.
    B(.53,.16,.779,.13,.11,.042,'iron')
    R((.565,.207,.82),(.565,.207,1.07),.017,'chrome')
    R((.565,.207,1.03),(.60,.34,1.045),.016,'chrome')
    R((.60,.312,1.015),(.60,.36,1.015),.062,'dark')
    R((.60,.359,1.015),(.60,.364,1.015),.051,'paper')
    R((.60,.366,1.015),(.578,.366,1.047),.005,'red')
    R((.60,.335,.908),(.60,.335,.970),.009,'chrome')
    if l>1:
        B(.67,.16,.778,.042,.035,.17,'dark');B(.56,.14,.91,.29,.05,.18,'navy');B(.58,.192,.935,.25,.009,.12,'glass')
    if l>2:B(.17,.32,.78,.09,.20,.14,'galv',.016);B(.2,.32,.893,.19,.032,.035,'chrome')

def render(scene,work,key,w,h,u,ox,oy,mode=0,samples=4,rays=6):
    desc=work/(key+'.scene');raw=work/(key+'.rgba')
    def emit(row):return ' '.join(f'{v:.7g}' for v in row)+'\n'
    with desc.open('w') as out:
        out.write(emit([w,h,u,ox,oy,mode,samples,rays,len(MATS),len(scene.rows)]))
        for mat in MATS.values():out.write(emit(mat))
        for row in scene.rows:out.write(emit(row))
    subprocess.run([str(work/'bake'),str(desc),str(raw)],check=True,env={**os.environ,'OMP_NUM_THREADS':os.environ.get('BAKE_THREADS','7')})
    pic=Image.frombytes('RGBA',(w,h),raw.read_bytes())
    bounds=pic.getchannel('A').getbbox()
    if not bounds:raise ValueError('Empty sprite: '+key)
    img=pic.crop(bounds);img.save(work/(key+'.png'))
    return img,[(bounds[0]-ox)/u,(bounds[1]-oy)/u,img.width/u,img.height/u]

def crew(s,person,facing,work):
    # Sculpt in shoulder/forward coordinates and rotate the entire bust to its path heading.
    coat=('denim','canvas','twill')[person]; cap=('yellow','cream','yellow')[person]
    lean=.13 if work else .025;neck=.85-(.025 if work else 0)
    def egg(c,h,mat,half=False):s.add(7 if half else 6,mat,c,h)
    slope=np.array([0.,lean,.37]);slope/=np.linalg.norm(slope)
    jacket_axes=[[1,0,0],[0,slope[2],-slope[1]],slope]
    s.add(8,coat,(0,lean*.5,.533),(.186,.121,.194),.058,jacket_axes)
    # A reinforced yoke, center seam and rear belt are visible while leaning into the machine.
    yoke=('steel','oak','mint')[person]
    s.chain([(-.139,lean*.84-.116,.655),(0,lean*.84-.134,.625),(.139,lean*.84-.116,.655)],.007,yoke)
    s.chain([(0,lean*.84-.135,.624),(0,lean*.50-.125,.53),(0,lean*.18-.115,.424)],.006,coat)
    s.chain([(-.083,lean*.3-.103,.462),(-.053,lean*.3-.115,.448)],.008,coat)
    s.box(-.140,lean*.29-.084,.342,.28,.168,.042,'dark',.013)
    s.box(-.037,lean*.29+.084,.345,.074,.012,.030,'brass',.004)
    s.rod((0,lean-.01,.685),(0,lean+.012,.802),.074,'skin')
    for side in (-1,1):
        s.chain([(side*.096,lean+.068,.704),(side*.047,lean+.126,.664),(side*.020,lean+.112,.706)],.013,'cream')
    s.box(-.121,lean*.19-.111,.372,.24,.025,.032,'dark',.006)
    s.box(.042,lean+.103,.548,.073,.018,.075,coat,.008)
    s.box(.04,lean+.120,.60,.078,.012,.014,'mint',.003)
    for z in (.46,.53,.60):s.ball((0,lean*.68+.125,z),.008,'brass')
    head=lean+(.052 if work else .009)
    egg((0,head,neck),(.117,.111,.137),'skin')
    egg((0,head-.043,neck+.063),(.116,.090,.087),'hair')
    for side in (-1,1):
        egg((side*.112,head-.004,neck),(.027,.033,.041),'skin')
        egg((side*.052,head+.092,neck+.021),(.014,.010,.010),'hair')
    egg((0,head+.106,neck+.001),(.028,.043,.035),'skin')
    egg((0,head+.004,neck+.096),(.156,.152,.114),cap,True)
    egg((0,head+.038,neck+.089),(.167,.183,.026),cap)
    s.chain([(0,head-.092,neck+.154),(0,head-.028,neck+.205),(0,head+.072,neck+.190)],.012,cap)
    dx,dy=((1,0),(0,1),(-1,0),(0,-1))[facing]
    orientation=np.array([[-dy,dx,0],[dx,dy,0],[0,0,1]])
    rotated=[]
    for row in s.rows:
        center=np.array(row[3:6])@orientation;axes=np.array(row[10:]).reshape(3,3)@orientation
        rotated.append((*row[:3],*center,*row[6:10],*axes.flatten()))
    s.rows=rotated

def pack(entries,width,dest,file,meta,export,indexed=False):
    # Tight rectangles, two transparent guard pixels on all sides.
    layout={};placements=[];x=y=row=0
    for key,im,world in entries:
        if x+im.width+4>width:x=0;y+=row+4;row=0
        placements.append((im,x+2,y+2))
        layout[key]=[x+2,y+2,im.width,im.height,*[round(k,6) for k in world]]
        x+=im.width+4;row=max(row,im.height)
    sheet=Image.new('RGBA',(width,y+row+4))
    for im,x,y in placements:sheet.paste(im,(x,y))
    sheet.save(dest/file,quality=91,method=6,exact=True)
    data=list(layout.values()) if indexed else layout
    literal=json.dumps(data,separators=(',',':')).replace('],','],\n')
    (dest/meta).write_text('export const '+export+' = '+literal+';\n')

def portraits(work,dest):
    entries=[]
    for person in range(3):
        for facing in range(4):
            for pose in range(2):
                s=Scene();crew(s,person,facing,pose)
                im,world=render(s,work,f'crew-{person}-{facing}-{pose}',120,165,128,60,147,0,8,9)
                entries.append((len(entries),im,world))
    pack(entries,512,dest,'crew-v015.webp','crew-frames-v015.mjs','crewFrames',indexed=True)

MODELS={'cut':saw,'drill':drill,'lathe':lathe,'inspect':bench}
def equipment(work,dest):
    sprites=[]
    for kind,model in MODELS.items():
        for level in (1,2,3):
            s=Scene();model(s,level,0,False);key=f'{kind}-L{level}'
            im,world=render(s,work,key,270,310,112,135,175)
            sprites.append((key,im,world))
        shadow=Scene();model(shadow,1,0,False)
        im,world=render(shadow,work,kind+'-shadow',325,360,94,140,128,2,4,18)
        sprites.append((kind+'-shadow',im,world))
        for f in range(25):
            s=Scene();model(s,1,(f-1)*TAU/24 if f else 0,f>0);key=f'{kind}-F{f}'
            im,world=render(s,work,key,270,310,112,135,175,1)
            sprites.append((key,im,world))
        print('Baked',kind,flush=True)
    pack(sprites,1152,dest,'machines-v015.webp','machine-frames-v015.mjs','frames')

def surroundings(work,dest):
    from building import room,vehicle
    info={}
    for w,h in ((8,6),(10,8)):
        s=Scene();room(s,w,h)
        u=90;ox=math.ceil((h+2.55)*u);oy=math.ceil(3.55*u)
        width=ox+math.ceil((w+1.67)*u);height=oy+math.ceil(((w+h+2.7)*.5+.70)*u)
        key=f'room-{w}'
        pic,world=render(s,work,key,width,height,u,ox,oy,0,8,9)
        pic.save(dest/f'{key}-v015.webp',quality=90,method=6,exact=True);info[key]=[round(n,6) for n in world]
        print('Baked room',w,h,flush=True)
    s=Scene();vehicle(s)
    pic,world=render(s,work,'truck',440,380,130,120,160,0,6,8)
    pic.save(dest/'truck-v015.webp',quality=91,method=6,exact=True);info['truck']=[round(n,6) for n in world]
    (dest/'room-frames-v015.mjs').write_text('export const roomFrames = '+json.dumps(info)+';\n')

if __name__=='__main__':
    work=Path(sys.argv[1]).resolve();dest=Path(sys.argv[2]).resolve()
    work.mkdir(parents=True,exist_ok=True);dest.mkdir(parents=True,exist_ok=True)
    subprocess.run(['c++','-std=c++17','-O3','-fopenmp',str(SRC/'bake.cpp'),'-o',str(work/'bake')],check=True)
    if len(sys.argv)<4 or sys.argv[3]=='machines':equipment(work,dest)
    if len(sys.argv)<4 or sys.argv[3]=='rooms':surroundings(work,dest)
    if len(sys.argv)<4 or sys.argv[3]=='crew':portraits(work,dest)
