extends RefCounted
## Authored equipment geometry with opaque vertex colours,
## one shared mesh per equipment variant; no new simulation or cargo objects.
const STEEL := Color("344c60")
const DARK := Color("172a38")
const EDGE := Color("738591")
const ORANGE := Color("db8e42")
const IVORY := Color("d8dedb")
const WOOD := Color("938773")
const RUBBER := Color("19232b")
const CYAN := Color("59bbaa")
var st := SurfaceTool.new()

func _init() -> void:
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

func _tri(a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
    var normal := (c-a).cross(b-a).normalized()
    for point in [a,b,c]:
        st.set_normal(normal)
        st.set_color(tint)
        st.add_vertex(point)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
    _tri(a,c,b,tint)
    _tri(a,d,c,tint)

func box(size: Vector3, pos: Vector3, tint: Color, basis := Basis.IDENTITY) -> void:
    var shape := BoxMesh.new()
    shape.size = size
    var faces := shape.get_faces()
    for i in range(0,faces.size(),3):
        _tri(pos+basis*faces[i],pos+basis*faces[i+1],pos+basis*faces[i+2],tint)

func bevel(size: Vector3, pos: Vector3, tint: Color, edge := .025) -> void:
    var x := size.x*.5
    var y := size.y*.5
    var z := size.z*.5
    var b := minf(edge,minf(x,minf(y,z))*.45)
    var ring: Array[Vector2] = [Vector2(-x+b,-z),Vector2(x-b,-z),Vector2(x,-z+b),Vector2(x,z-b),Vector2(x-b,z),Vector2(-x+b,z),Vector2(-x,z-b),Vector2(-x,-z+b)]
    var rows: Array = []
    for level in 4:
        var row: Array[Vector3] = []
        var h: float = [-y,-y+b,y-b,y][level]
        for p in ring:
            var inset := Vector2(signf(p.x)*b,signf(p.y)*b) if level in [0,3] else Vector2.ZERO
            row.append(pos+Vector3(p.x-inset.x,h,p.y-inset.y))
        rows.append(row)
    for level in 3:
        for i in 8:
            var j := (i+1)%8
            _quad(rows[level][i],rows[level+1][i],rows[level+1][j],rows[level][j],tint)
    for i in range(1,7):
        _tri(rows[0][0],rows[0][i+1],rows[0][i],tint)
        _tri(rows[3][0],rows[3][i],rows[3][i+1],tint)

func rod(a: Vector3, b: Vector3, width: float, tint: Color) -> void:
    var direction := b-a
    var basis := Basis.looking_at(direction.normalized(),Vector3.UP)
    box(Vector3(width,width,direction.length()),(a+b)*.5,tint,basis)

func cylinder(radius: float, depth: float, pos: Vector3, tint: Color, axis := Vector3.UP, segments := 10) -> void:
    var basis := Basis(Quaternion(Vector3.UP,axis.normalized()))
    for i in segments:
        var a := TAU*float(i)/segments
        var b := TAU*float(i+1)/segments
        var lo_a := pos+basis*Vector3(cos(a)*radius,-depth*.5,sin(a)*radius)
        var lo_b := pos+basis*Vector3(cos(b)*radius,-depth*.5,sin(b)*radius)
        var hi_a := pos+basis*Vector3(cos(a)*radius,depth*.5,sin(a)*radius)
        var hi_b := pos+basis*Vector3(cos(b)*radius,depth*.5,sin(b)*radius)
        _quad(lo_a,hi_a,hi_b,lo_b,tint)
        _tri(pos-basis.y*depth*.5,lo_b,lo_a,tint)
        _tri(pos+basis.y*depth*.5,hi_a,hi_b,tint)

func finish() -> ArrayMesh:
    st.index()
    var mesh := st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = .68
    mat.metallic = .12
    mat.metallic_specular = .35
    mesh.surface_set_material(0,mat)
    return mesh

func rack(upgraded: bool) -> ArrayMesh:
    # Canonical model bounds remain 2.22 x 1.85 x 1.25; the scene owns scale.
    for x in [-1.02,1.02]:
        for z in [-.55,.55]:
            bevel(Vector3(.12,1.82,.12),Vector3(x,.925,z),STEEL,.015)
            bevel(Vector3(.18,.07,.14),Vector3(x,.035,z),EDGE,.014)
            box(Vector3(.16,.28,.14),Vector3(x,.21,z),ORANGE)
            # Upright slots are broad recessed dots rather than costly bolts.
            for y in [.55,.88,1.20,1.52]:
                box(Vector3(.045,.045,.012),Vector3(x,y,z+(.066 if z>0 else -.066)),DARK)
        rod(Vector3(x,.34,-.49),Vector3(x,1.15,.49),.035,EDGE)
        rod(Vector3(x,1.15,-.49),Vector3(x,1.77,.49),.035,EDGE)
        box(Vector3(.07,.07,1.18),Vector3(x,1.79,0),STEEL)
    var levels := [.28,.92,1.52] if not upgraded else [.18,.57,.97,1.37]
    for y in levels:
        for z in [-.56,.56]:
            bevel(Vector3(2.10,.105,.12),Vector3(0,y,z),ORANGE,.012)
            box(Vector3(.27,.038,.013),Vector3(-.58,y,z+(.058 if z>0 else -.058)),IVORY)
        # Slatted load deck replaces the opaque roof-sized slab; dark gaps and
        # side braces read as a manufactured rack from rotating overhead views.
        for z in [-.40,-.20,0.0,.20,.40]:
            box(Vector3(1.97,.038,.135),Vector3(0,y+.065,z),WOOD)
        for x in [-.78,.78]:
            box(Vector3(.07,.08,.94),Vector3(x,y-.015,0),STEEL)
    return finish()

func packing(automated: bool) -> ArrayMesh:
    # Two genuine owned states: manual workbench, or purchased automatic packer.
    # Both stay inside the authoritative 1.6 x .95 x 1.0 footprint.
    for x in [-.65,.65]:
        for z in [-.36,.36]:
            bevel(Vector3(.10,.52,.10),Vector3(x,.28,z),STEEL,.012)
            box(Vector3(.15,.04,.15),Vector3(x,.02,z),RUBBER)
    box(Vector3(1.37,.065,.065),Vector3(0,.20,-.36),STEEL)
    box(Vector3(1.37,.065,.065),Vector3(0,.20,.36),STEEL)
    # Retain the original real parcel transforms. Carton bottoms are .59375;
    # the broad working surfaces sit immediately below that height.
    bevel(Vector3(1.56,.10,.94),Vector3(0,.49 if automated else .54,0),IVORY,.025)
    if automated:
        # Low conveyor bed and a recognisable U-shaped sealing head. The open
        # centre is real negative space, not a dark rectangular box.
        box(Vector3(1.50,.02,.90),Vector3(0,.548,0),DARK)
        for x in [-.64,-.48,-.32,-.16,0,.16,.32,.48,.64]:
            cylinder(.04,.90,Vector3(x,.552,0),EDGE,Vector3.FORWARD,8)
        # The narrow gantry occupies the real gap between discrete carton
        # columns (.195 < x < .275), so neither live row intersects its head.
        for z in [-.405,.405]:
            bevel(Vector3(.05,.39,.12),Vector3(.235,.745,z),STEEL,.012)
        bevel(Vector3(.06,.12,.92),Vector3(.235,.89,0),IVORY,.012)
        box(Vector3(.04,.055,.42),Vector3(.235,.805,0),ORANGE)
        bevel(Vector3(.29,.15,.27),Vector3(-.47,.615,-.30),STEEL,.014)
        box(Vector3(.20,.011,.17),Vector3(-.47,.696,-.30),CYAN)
        box(Vector3(.06,.014,.06),Vector3(-.60,.703,-.20),ORANGE)
    else:
        bevel(Vector3(.49,.035,.47),Vector3(.20,.575,.05),WOOD,.008)
        # Flat scale and tape roller are tools, never pretend cargo.
        bevel(Vector3(.33,.04,.20),Vector3(-.46,.61,-.33),EDGE,.008)
        box(Vector3(.18,.012,.07),Vector3(-.46,.637,-.26),DARK)
        cylinder(.08,.055,Vector3(.59,.67,-.32),ORANGE,Vector3.RIGHT,10)
        for x in [-.60,.60]:
            box(Vector3(.045,.34,.045),Vector3(x,.76,-.39),STEEL)
        bevel(Vector3(1.36,.09,.15),Vector3(0,.902,-.39),IVORY,.012)
        box(Vector3(.78,.012,.085),Vector3(0,.847,-.39),CYAN)
    return finish()

func robot() -> ArrayMesh:
    # Low industrial AMR carrier, within the same .18m reserved radial envelope.
    bevel(Vector3(.27,.14,.245),Vector3(0,.17,0),IVORY,.025)
    bevel(Vector3(.29,.045,.23),Vector3(0,.088,0),RUBBER,.013)
    bevel(Vector3(.235,.045,.205),Vector3(0,.262,0),STEEL,.009)
    box(Vector3(.175,.009,.13),Vector3(0,.292,0),ORANGE)
    # Real wheel silhouettes and a low navigation scanner distinguish it from
    # a standing person, without changing the conserved carried parcel.
    for x in [-.122,.122]:
        for z in [-.055,.055]:
            cylinder(.057,.035,Vector3(x,.065,z),RUBBER,Vector3.RIGHT,8)
            cylinder(.028,.037,Vector3(x,.065,z),EDGE,Vector3.RIGHT,8)
    cylinder(.046,.047,Vector3(0,.305,-.057),DARK,Vector3.UP,10)
    cylinder(.044,.012,Vector3(0,.331,-.057),CYAN,Vector3.UP,10)
    box(Vector3(.18,.025,.009),Vector3(0,.175,-.126),CYAN)
    box(Vector3(.025,.055,.009),Vector3(-.09,.16,.127),ORANGE)
    box(Vector3(.025,.055,.009),Vector3(.09,.16,.127),ORANGE)
    return finish()
