"""Original authored geometry for Sillons d'Empire. Blender 4.3+, no add-on.
Run: blender -b --factory-startup --python build_realism.py -- OUTPUT
Textures are shared by the Godot runtime, never embedded into every mesh.
"""
import bpy, math, random, sys, json
from pathlib import Path
from mathutils import Vector
from mathutils import noise
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
MATS={};RECORDS=[]
PALETTE={'stone':(.35,.33,.28,1),'wall':(.65,.61,.5,1),'brick':(.48,.22,.13,1),'wood':(.28,.20,.12,1),'roof':(.22,.21,.19,1),'metal':(.19,.22,.23,1),'glass':(.075,.15,.18,1),'team':(.1,.26,.52,1),'leaf':(.19,.29,.07,1),'berry':(.45,.045,.035,1),'bark':(.22,.17,.10,1),'rock':(.38,.36,.32,1),'cloth':(.31,.30,.23,1),'skin':(.56,.36,.23,1),'hair':(.12,.085,.055,1),'leather':(.19,.12,.07,1)}
for name,color in PALETTE.items():
 m=bpy.data.materials.new('gfx_'+name);m.diffuse_color=color;m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=color;p.inputs['Roughness'].default_value=.8
 if name=='metal':p.inputs['Metallic'].default_value=.8;p.inputs['Roughness'].default_value=.35
 if name=='glass':p.inputs['Metallic'].default_value=.6;p.inputs['Roughness'].default_value=.16
 MATS[name]=m

def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)

def assign(o,mat,bone=None):
 o.data.materials.append(MATS[mat])
 if bone:o['bone']=bone
 return o

def box(pos,size,mat='wood',rot=0,bevel=.018,bone=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.dimensions=size;o.rotation_euler.z=rot
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Small edge bevel','BEVEL');mod.width=min(bevel,min(size)*.18);mod.segments=1
  bpy.ops.object.modifier_apply(modifier=mod.name)
 return assign(o,mat,bone)

def ellipsoid(pos,size,mat='skin',segments=12,rings=8,bone=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=pos)
 o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 return assign(o,mat,bone)

def rod(a,b,r,mat='wood',vertices=10,bone=None,taper=.85):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r*taper,depth=d.length,location=(a+b)*.5)
 o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
 return assign(o,mat,bone)

def custom(name,verts,faces,mat,bone=None,colors=None):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);assign(ob,mat,bone)
 if colors:
  attr=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
  for i,c in enumerate(colors):attr.data[i].color=c
 return ob

def roof(cx,cy,z,w,d,h,material='roof'):
 # Gable ridge runs along Y; structural thickness and eaves are geometry.
 verts=[(cx-w/2,cy-d/2,z),(cx+w/2,cy-d/2,z),(cx,cy-d/2,z+h),(cx-w/2,cy+d/2,z),(cx+w/2,cy+d/2,z),(cx,cy+d/2,z+h)]
 custom('Gable roof',verts,[(0,1,2),(3,5,4),(0,2,5,3),(2,1,4,5),(0,3,4,1)],material)
 rod((cx,cy-d/2-.03,z+h),(cx,cy+d/2+.03,z+h),.035,'metal',6)

def window(x,y,z,w=.4,h=.48,modern=False):
 box((x,y,z),(w+.08,.06,h+.08),'stone' if modern else 'wood',bevel=.008)
 box((x,y-.037,z),(w,.016,h),'glass',bevel=0)
 box((x,y-.05,z),(.028,.025,h),'metal' if modern else 'wood',bevel=0)
 box((x,y-.05,z),(w,.025,.028),'metal' if modern else 'wood',bevel=0)
 box((x,y-.06,z-h/2-.045),(w+.12,.15,.06),'stone',bevel=.008)

def door(x,y,z,h=1.1):
 box((x,y,z+h/2),(.6,.1,h),'wood')
 for sx in [-.34,.34]:box((x+sx,y-.02,z+h*.5),(.08,.14,h+.08),'stone')
 box((x,y-.02,z+h+.03),(.76,.14,.12),'stone')
 rod((x+.2,y-.075,z+h*.52),(x+.2,y-.075,z+h*.59),.018,'metal',6)

def barrel(x,y,z=.12,scale=1):
 rod((x,y,z),(x,y,z+.55*scale),.20*scale,'wood',12,taper=1)
 for height in [.07,.42]:
  bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=4,location=(x,y,z+height*scale),major_radius=.20*scale,minor_radius=.018*scale)
  assign(bpy.context.object,'metal')

def flag(x,y,z):
 rod((x,y,z),(x,y,z+.9),.018,'wood',8)
 custom('Banner',[(x,y,z+.87),(x+.42,y+.03,z+.82),(x+.40,y-.02,z+.48),(x,y,z+.50)],[(0,1,2,3)],'team')

def building(kind,age):
 reset();late=age>=6;modern=age>=9
 w=3.4;d=2.8;z=.20
 box((0,0,.10),(w+.4,d+.4,.20),'stone')
 for step in range(3):box((0,-d/2-.2-step*.13,.08-step*.015),(.95,.3,.12),'stone')
 if kind=='palissade':
  for i in range(13):rod((i*.26-1.6,0,.1),(i*.26-1.6,0,1.7+math.sin(i)*.04),.13,'wood',8,taper=.65)
  for h in [.5,1.25]:box((0,.12,h),(3.7,.12,.14),'wood')
 elif kind=='fort':
  box((0,0,1.5),(2.4,2.4,2.7),'stone')
  for x in [-1.22,1.22]:
   for y in [-1.22,1.22]:
    rod((x,y,.1),(x,y,3.2),.38,'stone',12,taper=1)
    for j in range(6):box((x+math.cos(j*math.tau/6)*.32,y+math.sin(j*math.tau/6)*.32,3.25),(.2,.2,.36),'stone')
  door(0,-1.25,.2,1.35);flag(.8,.8,3.05)
 elif kind=='marche':
  box((0,.4,.9),(2.6,1.8,1.5),'wall');roof(0,.4,1.7,3.0,2.2,.8)
  for x in [-1.0,0,1.0]:
   for y in [-1.25,-.25]:rod((x,y,.2),(x,y,1.45),.045,'wood')
   box((x,-.8,.65),(.85,.75,.12),'wood');box((x,-.8,1.44),(.92,1.1,.05),'cloth')
   for j in range(3):ellipsoid((x-.25+j*.23,-.8,.76),(.12,.13,.1),'leaf',8,5)
  barrel(1.4,1.3);door(0,-.52,.2)
 else:
  industrial=kind in ['usine','depot','entrepot','atelier']
  height=1.55 if kind=='maison' else (1.8 if industrial else 2.25)
  floors=2 if age>=3 and kind not in ['entrepot','depot','atelier'] else 1
  if modern:height=2.8 if kind in ['centre','academie'] else 1.9;floors=3 if kind=='centre' else 2
  surface='wall' if age<6 else ('brick' if age<9 else 'wall')
  box((0,0,z+height/2),(w,d,height),surface)
  if age<6:
   roof(0,0,z+height,w+.48,d+.48,.92 if age<3 else 1.12)
   for x in [-w/2-.025,w/2+.025]:
    for y in [-d/2-.025,d/2+.025]:box((x,y,z+height/2),(.12,.12,height+.08),'wood')
   for h in [.3,height*.65,height]:
    box((0,-d/2-.035,z+h),(w+.12,.09,.10),'wood')
   if age>=3:
    for x in [-1.15,1.15]:
     rod((x,-d/2-.08,z+.4),(x+.45,-d/2-.08,z+height-.1),.04,'wood',6)
  else:
   if not modern:
    roof(0,0,z+height,w+.28,d+.28,.55 if industrial else .8)
   box((0,0,z+height+.07),(w+.2,d+.2,.14),'roof')
   for x in [-1.28,1.28]:box((x,.4,z+height+.28),(.5,.65,.42),'metal')
   if modern:
    for i in range(4):
     box((-.75+i*.48,.55,z+height+.14),(.38,1.1,.035),'glass',bevel=0)
   rod((1.35,.85,z+height),(1.35,.85,z+height+1.2),.025,'metal',8)
   if modern:
    box((0,-d/2-.45,z+height*.65),(2.3,.9,.1),'metal')
    for x in [-1.4,1.4]:box((x,-d/2-.1,z+height*.5),(.2,.22,height),'metal')
  door(0,-d/2-.08,z,1.15)
  for floor in range(floors):
   wz=z+.83+floor*(height-.5)/max(floors,1)
   for x in [-1.1,1.1]:window(x,-d/2-.05,wz,.5,.48,modern)
   for x in [-1.1,0,1.1]:window(x,d/2+.06,wz,.45,.45,modern)
  # Side windows and gutters are modelled; all geometry remains inside the footprint envelope.
  for sx in [-1,1]:
   for y in [-.8,.4]:
    panel=box((sx*(w/2+.025),y,z+.95),(.028,.48,.52),'glass',bevel=0)
   rod((sx*(w/2+.08),-d/2,z+.1),(sx*(w/2+.08),-d/2,z+height),.026,'metal',8)
  if kind=='centre' and not modern:
   box((0,.55,z+height+.62),(.72,.75,.85),'wall')
   roof(0,.55,z+height+1.05,.92,.95,.48)
   flag(.0,.55,z+height+1.5)
  if kind in ['entrepot','depot']:
   box((0,-d/2-.09,z+.75),(1.25,.13,1.45),'wood')
   for sx in [-1,1]:box((sx*.67,-d/2-.12,z+.78),(.12,.15,1.55),'metal')
  if industrial:
   rod((1.15,.8,.2),(1.15,.8,height+1.5),.22,'stone' if age<9 else 'metal',14,taper=.86)
   for i in range(4):box((-.9+i*.55,-.1,z+height+.22),(.4,.7,.16),'metal')
   barrel(-1.1,-1.7);barrel(-.6,-1.7)
  elif kind in ['caserne','centre']:
   flag(-1.5,-1.6,1.45)
   for i in range(3):rod((.7+i*.2,-1.63,.2),(.7+i*.2,-1.63,1.2),.025,'wood',7)
  elif kind=='maison':
   box((1.1,-1.68,.3),(.6,.32,.22),'wood');ellipsoid((1.1,-1.68,.5),(.3,.18,.15),'leaf',8,5)
 export('bld_'+kind+'_a%02d'%age,'building',kind,age)

def export(name,category,family,age=1):
 # Collapse static geometry to one mesh with shared material slots.
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 if category!='unit':
  bpy.ops.object.select_all(action='DESELECT')
  for o in meshes:o.select_set(True)
  if meshes:
   bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();bpy.context.object.name=name
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_nla_strips=True,export_yup=True,export_cameras=False,export_lights=False)
 tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
 RECORDS.append({'id':name,'category':category,'family':family,'age':age,'file':name+'.glb','triangles':tri})
 print('MODEL_READY',name,tri,flush=True)

def tree(seed):
 reset();rng=random.Random(seed);leafv=[];leaff=[];leafc=[]
 rod((0,0,0),(.10,-.03,2.5),.20,'bark',12,taper=.24)
 def leaf(center,direction,width=.12):
  c=Vector(center);axis=Vector(direction).normalized();side=axis.cross(Vector((.2,.3,1))).normalized()*width
  start=len(leafv);mid=c+axis*.105;tip=c+axis*.235
  leafv.extend([tuple(c),tuple(mid+side),tuple(mid+Vector((0,0,.035))),tuple(mid-side),tuple(tip)])
  leaff.extend([(start,start+1,start+2),(start,start+2,start+3),(start+1,start+4,start+2),(start+2,start+4,start+3)])
  hue=rng.uniform(.78,1.16);leafc.extend([(hue*.9,hue,hue*.77,1)]*5)
 for branch in range(14):
  angle=branch*2.399+seed*.31;level=1.05+branch*.095;length=1.0+rng.random()*.65
  end=Vector((math.cos(angle)*length,math.sin(angle)*length,level+.8+rng.random()*.65))
  base=Vector((.05,0,level));bend=base.lerp(end,.50)+Vector((.12,-.08,-.13));rod(base,bend,.065,'bark',8,taper=.66);rod(bend,end,.040,'bark',7,taper=.25)
  for twig in range(4):
   a=angle+(twig-1.5)*.55
   tip=end+Vector((math.cos(a)*.42,math.sin(a)*.42,.22+rng.random()*.36))
   rod(end,tip,.015,'bark',5,taper=.3)
   for j in range(36):
    pos=end.lerp(tip,rng.random())+Vector((rng.uniform(-.24,.24),rng.uniform(-.24,.24),rng.uniform(-.2,.25)))
    leaf(pos,(math.cos(a+j*.7),math.sin(a+j*.7),rng.uniform(-.35,.6)),rng.uniform(.045,.075))
 custom('Individual foliage',leafv,leaff,'leaf',colors=leafc)
 export('oak_%d'%seed,'resource','tree')

def bush():
 reset();rng=random.Random(19)
 for i in range(220):
  a=rng.random()*math.tau;r=rng.random()*.55;z=.2+rng.random()*.5
  leaf=ellipsoid((math.cos(a)*r,math.sin(a)*r,z),(.10,.045,.018),'leaf',8,4)
  leaf.rotation_euler=(rng.uniform(-.7,.7),rng.uniform(-.7,.7),a)
 for i in range(14):
  a=i*2.399;ellipsoid((math.cos(a)*.4,math.sin(a)*.4,.5+(i%3)*.06),(.035,.035,.035),'berry',8,4)
 export('berry_bush','resource','berries')

def rock(seed):
 reset();bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(0,0,.25));o=bpy.context.object
 for v in o.data.vertices:
  p=v.co;n=noise.noise_vector(p*3+Vector((seed,0,0)));p.x*=1+n.x*.21;p.y*=.78+n.y*.14;p.z*=.62+n.z*.18
 assign(o,'rock');export('boulder_%d'%seed,'resource','ore')

def human(kind):
 reset();arm_data=bpy.data.armatures.new('AnatomicalSkeleton');arm=bpy.data.objects.new('Armature',arm_data);bpy.context.collection.objects.link(arm)
 bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 bones=[('pelvis',(0,0,.89),(0,0,1.02),None),('spine',(0,0,1.02),(0,0,1.23),'pelvis'),('chest',(0,0,1.23),(0,0,1.46),'spine'),('neck',(0,0,1.46),(0,0,1.54),'chest'),('head',(0,0,1.54),(0,0,1.8),'neck')]
 for side,sign in [('L',-1),('R',1)]:
  x=sign*.23
  bones.extend([('upper_arm.'+side,(x,0,1.40),(x+sign*.025,0,1.12),'chest'),('forearm.'+side,(x+sign*.025,0,1.12),(x+sign*.04,-.02,.88),'upper_arm.'+side),('hand.'+side,(x+sign*.04,-.02,.88),(x+sign*.04,-.04,.76),'forearm.'+side),('thigh.'+side,(sign*.105,0,.91),(sign*.105,-.015,.53),'pelvis'),('shin.'+side,(sign*.105,-.015,.53),(sign*.105,0,.14),'thigh.'+side),('foot.'+side,(sign*.105,0,.14),(sign*.105,-.17,.08),'shin.'+side)])
 for name,head,tail,parent in bones:
  b=arm_data.edit_bones.new(name);b.head=head;b.tail=tail
  if parent:b.parent=arm_data.edit_bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT')
 ellipsoid((0,0,1.2),(.205,.125,.27),'cloth',16,10,'spine');ellipsoid((0,0,.94),(.17,.12,.14),'cloth',14,8,'pelvis')
 rod((0,0,1.43),(0,0,1.57),.055,'skin',12,'neck')
 ellipsoid((0,-.003,1.66),(.093,.09,.125),'skin',20,12,'head')
 ellipsoid((0,-.083,1.65),(.023,.028,.034),'skin',10,6,'head')
 ellipsoid((0,.009,1.729),(.095,.088,.065),'hair',16,8,'head')
 for sign in [-1,1]:
  ellipsoid((sign*.033,-.080,1.68),(.012,.009,.006),'hair',8,4,'head')
  ellipsoid((sign*.094,0,1.65),(.016,.025,.036),'skin',8,5,'head')
 box((0,-.127,1.02),(.32,.025,.065),'leather',bone='pelvis')
 box((-.135,-.13,1.27),(.1,.03,.16),'team',bone='chest')
 for side,sign in [('L',-1),('R',1)]:
  x=sign*.23
  rod((x,0,1.4),(x+sign*.025,0,1.12),.067,'cloth',12,'upper_arm.'+side,.82)
  ellipsoid((x,0,1.39),(.078,.078,.08),'cloth',12,7,'upper_arm.'+side)
  rod((x+sign*.025,0,1.13),(x+sign*.04,-.02,.9),.050,'skin' if kind=='ouvrier' else 'cloth',12,'forearm.'+side,.74)
  ellipsoid((x+sign*.04,-.025,.86),(.038,.028,.065),'skin',12,6,'hand.'+side)
  rod((sign*.105,0,.92),(sign*.105,-.015,.53),.085,'cloth',12,'thigh.'+side,.78)
  ellipsoid((sign*.105,-.01,.54),(.065,.066,.07),'cloth',12,6,'shin.'+side)
  rod((sign*.105,-.015,.53),(sign*.105,0,.16),.059,'cloth',12,'shin.'+side,.71)
  ellipsoid((sign*.105,-.065,.085),(.067,.135,.075),'leather',12,7,'foot.'+side)
  if kind in ['fusilier','grenadier','lancier']:ellipsoid((x,0,1.40),(.09,.09,.065),'metal',12,6,'upper_arm.'+side)
 if kind in ['fusilier','grenadier']:
  ellipsoid((0,.008,1.737),(.108,.1,.067),'metal',16,8,'head')
  box((.265,-.10,.97),(.055,.08,.45),'wood',bone='hand.R')
  rod((.265,-.11,1.02),(.265,-.11,1.53),.015,'metal',10,'hand.R',1)
 elif kind=='lancier':
  rod((.27,-.04,.35),(.27,-.04,2.15),.018,'wood',8,'hand.R')
  ellipsoid((.27,-.04,2.18),(.035,.018,.12),'metal',8,5,'hand.R')
  ellipsoid((-.28,-.105,1.06),(.16,.035,.24),'team',16,8,'forearm.L')
 elif kind=='tireur':
  for i in range(10):
   a0=-1.2+i*.24;a1=a0+.24
   rod((.27,-.1+math.cos(a0)*.18,1.05+math.sin(a0)*.45),(.27,-.1+math.cos(a1)*.18,1.05+math.sin(a1)*.45),.014,'wood',6,'hand.R')
  rod((.27,-.1+math.cos(-1.2)*.18,1.05+math.sin(-1.2)*.45),(.27,-.1+math.cos(1.2)*.18,1.05+math.sin(1.2)*.45),.003,'cloth',5,'hand.R')
 elif kind=='ouvrier':
  rod((.27,-.025,.69),(.27,-.025,1.2),.024,'wood',8,'hand.R')
  box((.27,-.025,1.18),(.22,.09,.11),'metal',bone='hand.R')
  box((-.19,.035,.95),(.11,.10,.15),'leather',bone='pelvis')
 # Assign rigid segment weights, join to one skinned mesh (few materials, no per-finger scene nodes).
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for o in meshes:
  group=o.vertex_groups.new(name=o.get('bone','spine'));group.add(list(range(len(o.data.vertices))),1,'REPLACE')
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();body=bpy.context.object;body.name='ClothedFigure'
 mod=body.modifiers.new('Skeleton deformation','ARMATURE');mod.object=arm;body.parent=arm
 arm.animation_data_create()
 for action_name in ['idle','walk','work','attack']:
  action=bpy.data.actions.new(action_name);arm.animation_data.action=action
  for f in range(1,26,3):
   t=(f-1)/24*math.tau
   for b in arm.pose.bones:b.rotation_mode='XYZ';b.rotation_euler=(0,0,0)
   for side,sign in [('L',1),('R',-1)]:
    if action_name=='walk':
     arm.pose.bones['thigh.'+side].rotation_euler.x=math.sin(t)*.43*sign
     arm.pose.bones['shin.'+side].rotation_euler.x=max(0,-math.sin(t)*sign)*.62
     arm.pose.bones['upper_arm.'+side].rotation_euler.x=-math.sin(t)*.28*sign
    elif action_name in ['work','attack']:
     arm.pose.bones['upper_arm.'+side].rotation_euler.x=.35+math.sin(t)*.65 if side=='R' else .22
     arm.pose.bones['forearm.'+side].rotation_euler.x=.25+max(0,math.sin(t))*.35
   arm.pose.bones['chest'].rotation_euler.x=math.sin(t)*(.025 if action_name=='idle' else .055)
   for b in arm.pose.bones:b.keyframe_insert(data_path='rotation_euler',frame=f,group=b.name)
  arm.animation_data.action=None
  track=arm.animation_data.nla_tracks.new();track.name=action_name;track.strips.new(action_name,1,action);track.mute=True
 for b in arm.pose.bones:b.rotation_euler=(0,0,0)
 export('human_'+kind,'unit',kind)

for age in [1,3,6,10]:
 for kind in ['centre','maison','caserne','entrepot','atelier','marche','usine','academie','depot','fort','palissade']:building(kind,age)
for seed in [3,11,21]:tree(seed)
bush()
for seed in [4,9,17]:rock(seed)
for kind in ['ouvrier','colon','lancier','tireur','fusilier','grenadier']:human(kind)
(OUT/'manifest.json').write_text(json.dumps({'schema':1,'authored_for':'Sillons d’Empire 0.13.5','generator':'Blender '+bpy.app.version_string,'geometry_license':'Original project geometry','models':RECORDS},ensure_ascii=False,indent=2)+'\n')
print('REALISM_GEOMETRY=PASS models='+str(len(RECORDS)),flush=True)
