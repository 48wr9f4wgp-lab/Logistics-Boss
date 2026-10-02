"""FLOTRA original packing workbench. Run with Blender 4.3+ in background.
No third-party geometry/textures/add-ons. Runtime GLB is one mesh/material.
Godot world: X right, Y up, Z depth. Blender: X right, Y=-depth, Z up.
"""
import bpy, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot/assets/models/packing_workbench.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for mat in list(bpy.data.materials):
    bpy.data.materials.remove(mat)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
palette = {
    'navy': (0.047, 0.075, 0.090, 1),
    'steel': (0.185, 0.245, 0.270, 1),
    'light': (0.36, 0.43, 0.45, 1),
    'amber': (0.88, 0.43, 0.075, 1),
    'cyan': (0.16, 0.65, 0.79, 1),
    'dark': (0.026, 0.039, 0.049, 1),
}
material = bpy.data.materials.new('FLOTRA_VertexPalette')
material.use_nodes = True
material.use_backface_culling = True
bsdf = material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 0.53
bsdf.inputs['Metallic'].default_value = 0.15
color_node = material.node_tree.nodes.new('ShaderNodeVertexColor')
color_node.layer_name = 'Color'
material.node_tree.links.new(color_node.outputs['Color'], bsdf.inputs['Base Color'])
objects=[]
def box(name, size, pos, color, bevel=0):
    # authored in Godot axes, converted once for Blender/glTF's standard Y-up export
    bpy.ops.mesh.primitive_cube_add(size=1, location=(pos[0], -pos[2], pos[1]))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Single_segment_edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(material)
    attr = obj.data.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for c in attr.data: c.color = palette[color]
    objects.append(obj)
    return obj
# Broad 2.35 x 1.15 tabletop sits at exactly 1.03 m; authoritative carton bottom is 1.04 m.
box('ChamferedWorktop', (2.35,.14,1.15), (0,.96,0), 'light', .035)
box('RecessedWorkSurface', (2.13,.014,.90), (0,1.025,0), 'steel')
# Open under-bench volume remains visible from the overview, unlike the old floating block.
# Left support is inset to clear the authoritative 12-parcel backlog envelope.
for x in (-.50,.99):
    for z in (-.43,.43):
        box('SquareLeg', (.14,.83,.14), (x,.475,z), 'navy')
        box('Foot', (.22,.075,.23), (x,.092,z), 'dark')
box('RearCrossBrace', (2.12,.16,.10), (0,.34,-.43), 'steel')
box('LowShelf', (1.40,.065,.78), (.245,.30,.0), 'navy')
box('FrontApron', (2.20,.23,.09), (0,.805,.50), 'navy')
box('SafetyEdge', (1.99,.055,.018), (0,.866,.552), 'amber')
for x in (-1.14,1.14):
    box('SafetyCorner', (.06,.075,.95), (x,.97,0), 'amber')
# Rear HMI is static instrumentation, not a cargo/status signal. No emission or text atlas.
box('TerminalStem', (.10,.40,.09), (.18,1.23,-.48), 'navy')
box('TerminalBezel', (.68,.49,.13), (.18,1.535,-.50), 'navy', .02)
box('TerminalGlass', (.55,.36,.015), (.18,1.54,-.426), 'cyan')
box('TerminalBack', (.42,.26,.016), (.18,1.54,-.576), 'steel')
# No cartons, lights, animation, collision, or invented machine capacity.
bpy.ops.object.select_all(action='DESELECT')
for obj in objects: obj.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.join()
obj=bpy.context.object
obj.name='PackingWorkbenchGeometry'
obj.data.name='PackingWorkbenchMesh'
bpy.context.scene.cursor.location=(0,0,0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
# Joining meshes keeps one shared material slot.
for polygon in obj.data.polygons: polygon.material_index=0
while len(obj.data.materials)>1: obj.data.materials.pop(index=len(obj.data.materials)-1)
obj.data.calc_loop_triangles()
triangles=len(obj.data.loop_triangles)
assert triangles<=500, triangles
assert len(obj.data.materials)==1
obj['asset_id']='flotra.packing_workbench.v1'
obj['license']='CC0-1.0; original geometry generated for FLOTRA'
obj['purpose']='Presentation-only replacement of the existing base packing table and monitor'
scene.world.color=(.05,.05,.05)
# A useful opening view for further manual editing, without exported cameras/lights.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=5.3
            area.spaces.active.region_3d.view_location=(0,0,.8)
            area.spaces.active.shading.type='MATERIAL'
OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/packing_workbench.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', use_selection=True,
    export_yup=True, export_animations=False, export_cameras=False, export_lights=False,
    export_texcoords=False, export_normals=True, export_materials='EXPORT',
    export_attributes=False, export_extras=True)
manifest={
  'asset':'flotra.packing_workbench.v1', 'blender_version':bpy.app.version_string,
  'triangles':triangles, 'mesh_objects':1, 'materials':1, 'textures':0,
  'lights':0,'animations':0,'collision_shapes':0,
  'source':'art/blender/packing_workbench.blend',
  'runtime':'godot/assets/models/packing_workbench.glb',
  'license':'CC0-1.0', 'units':'meters', 'godot_axes':'Y up, +Z front',
  'origin':'floor-center', 'worktop_height_m':1.032,
  'max_triangles':500, 'max_runtime_surfaces':1,
  'lod':'No additional LOD initially: single 304-triangle instance; validate on device.'
}
(ROOT/'art/blender/packing_workbench.spec.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('FLOTRA_ASSET_BUILD '+json.dumps(manifest))
