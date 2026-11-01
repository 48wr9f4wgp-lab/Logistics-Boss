"""Work lights, fixtures and actual stock. All dimensions use the machine's tile frame."""

def light(s, base, elbow, head, case):
    x,y,z=base
    s.rod((x,y,z-.052),(x,y,z+.028),.064,'iron')
    s.rod(base,elbow,.025,'dark')
    s.rod(elbow,head,.025,'galv')
    s.ball(elbow,.048,'brass')
    x,y,z=head
    s.rod((x,y,z-.015),(x,y,z+.044),.054,'dark')
    s.rod((x,y,z-.077),(x,y,z),.092,case)
    s.rod((x,y,z-.107),(x,y,z-.061),.126,case)
    s.torus((x,y,z-.105),(0,0,1),.118,.011,'galv')
    s.rod((x,y,z-.111),(x,y,z-.104),.113,'paper')

def part(s,product,stage):
    if product=='plate':
        width=.335 if stage==0 else .30
        metal='millscale' if stage==0 else 'stock'
        s.add(9 if stage==2 else 1,metal,(width/2,.095,.021),(width/2,.095,.021),
              .007 if stage==0 else .012)
        if stage==0:
            # A single pale layout scribe on the blank.
            s.box(.045,.009,.041,.004,.17,.002,'steel',0)
        elif stage==1:
            for x in (.065,.235):
                s.rod((x,.095,.041),(x,.095,.043),.007,'dark')
        return
    if stage<2:
        length=.37 if stage==0 else .335
        s.rod((0,.07,.042),(length,.07,.042),.042,'millscale' if stage==0 else 'stock',bevel=.003)
        s.rod((length-.002,.07,.042),(length+.002,.07,.042),.040,'steel',bevel=.001)
        return
    for a,b,r in ((.00,.055,.029),(.053,.095,.044),(.094,.234,.037),(.232,.263,.046),(.261,.343,.026)):
        s.rod((a,.07,.046),(b,.07,.046),r,'stock',bevel=.003)
    for x in (.281,.291,.301,.311,.321):
        s.torus((x,.07,.046),(1,0,0),.026,.002,'iron')

def containers(s,key):
    b=s.box
    if key=='raw-layer':
        # Mill scale remains on the faces; sheared edges expose brighter metal.
        b(.003,.004,0,.573,.441,.042,'millscale',.006)
        b(.004,.440,.004,.57,.006,.019,'stock',.002)
        b(.573,.008,.005,.005,.428,.017,'steel',.001)
        b(.074,.016,.042,.003,.415,.001,'steel',0)
        return
    if key=='tote-back':
        b(.008,.009,.008,.422,.315,.031,'press',.009)
        b(.012,.015,.04,.414,.299,.005,'shade',.002)
        b(0,0,.01,.44,.030,.125,'press',.008)
        b(0,.025,.01,.022,.28,.124,'press',.005)
        return
    # Side mouths and front label hide just the lower portion of the contents.
    b(.418,.024,.01,.022,.30,.123,'press',.006)
    b(0,.307,.01,.44,.025,.089,'press',.006)
    for x in (0,.290):b(x,.307,.085,.15,.025,.046,'press',.005)
    b(0,.305,.120,.44,.031,.018,'cover',.006)
    for x in (.022,.12,.30,.40):b(x,.332,.023,.014,.009,.063,'cover',.003)
    b(.176,.333,.036,.087,.004,.043,'paper',.002)

def station(s,kind):
    if kind=='inspect': # Its articulated green lamp already belongs to the bench.
        # Caliper case open, behind the measuring surface. Dark felt cradles the spare tools.
        s.box(.47,.022,.712,.35,.14,.092,'walnut',.012)
        s.box(.47,.011,.795,.35,.027,.14,'walnut',.012)
        s.box(.489,.037,.81,.312,.005,.10,'shade',.006)
        for i in range(3):
            x=.51+i*.084
            s.rod((x,.069,.811),(x+.044,.116,.811),.012,'chrome')
        return
    mounts={'cut':((.16,.17,.66),(.015,.09,1.26),(.28,.145,1.45),'ochre'),
            'drill':((.64,.25,.165),(.87,.025,1.11),(1.00,.27,1.33),'cream'),
            'lathe':((.24,.20,1.03),(.18,.04,1.29),(.50,.20,1.32),'green')}
    light(s,*mounts[kind])
    if kind=='cut':
        # Bundled offcuts confined to the machine footprint.
        for i in range(3):
            x=.55+i*.079
            s.rod((x,.04,.052),(x,.25,.052),.034,'iron')
    if kind=='drill':
        s.box(.76,.11,.02,.17,.20,.22,'turq',.02)
        s.rod((.847,.205,.23),(.847,.205,.30),.028,'brass')
        s.chain([(.85,.20,.29),(.92,.17,.45),(.90,.17,.90),(.83,.18,1.02)],.016,'rubber')

def figure_shadow(s,crew,facing,working):
    crew(s,0,facing,working)
    dx,dy=((1,0),(0,1),(-1,0),(0,-1))[facing]
    def point(side,ahead,z):
        return (-dy*side+dx*ahead,dx*side+dy*ahead,z)
    for side in (-1,1):
        foot=point(side*.115,.04,.07)
        s.rod(point(side*.094,0,.40),foot,.063,'denim')
        s.rod(foot,point(side*.115,.13,.041),.052,'rubber')
        shoulder=point(side*.14,.13 if working else .025,.69)
        elbow=point(side*.19,.24 if working else .016,.55 if working else .48)
        s.rod(shoulder,elbow,.059,'denim')
        s.rod(elbow,point(side*.20,.4 if working else .05,.65 if working else .38),.046,'skin')

def build(work,dest,scene,render,pack,crew):
    entries=[]
    for kind in ('cut','drill','lathe','inspect'):
        s=scene();station(s,kind)
        im,world=render(s,work,'station-'+kind,300,350,145,134,233,0,8,8)
        entries.append((kind,im,world))
    for product in ('plate','shaft'):
        for stage in range(3):
            key=f'{product}-{stage}'
            s=scene();part(s,product,stage)
            im,world=render(s,work,key,185,120,268,63,41,0,8,10)
            entries.append((key,im,world))
    for key in ('raw-layer','tote-back','tote-front'):
        s=scene();containers(s,key)
        im,world=render(s,work,key,310,205,239,128,41,0,8,8)
        entries.append((key,im,world))
    for facing in range(4):
        for working in (0,1):
            key=f'shadow-{facing}-{working}';s=scene()
            figure_shadow(s,crew,facing,working)
            im,world=render(s,work,key,230,235,96,114,49,2,5,16)
            entries.append((key,im,world))
    pack(entries,512,dest,'station-v017.webp','station-frames-v017.mjs','stationFrames')
