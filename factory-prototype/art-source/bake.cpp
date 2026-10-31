// Offline orthographic miniature baker. Input is a material list followed by oriented solids.
// A small BVH bounds the rounded solids; soft key shadows and ambient occlusion are ray traced.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <numeric>
#include <vector>
using std::max; using std::min;
struct V {float x=0,y=0,z=0; float operator[](int i)const{return i==0?x:i==1?y:z;}};
V operator+(V a,V b){return {a.x+b.x,a.y+b.y,a.z+b.z};}
V operator-(V a,V b){return {a.x-b.x,a.y-b.y,a.z-b.z};}
V operator*(V a,float b){return {a.x*b,a.y*b,a.z*b};}
V operator*(V a,V b){return {a.x*b.x,a.y*b.y,a.z*b.z};}
float dot(V a,V b){return a.x*b.x+a.y*b.y+a.z*b.z;}
V cross(V a,V b){return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
float length(V a){return sqrtf(dot(a,a));} V unit(V a){return a*(1/max(.000001f,length(a)));}
V low(V a,V b){return {min(a.x,b.x),min(a.y,b.y),min(a.z,b.z)};}
V high(V a,V b){return {max(a.x,b.x),max(a.y,b.y),max(a.z,b.z)};}
V absV(V a){return {fabsf(a.x),fabsf(a.y),fabsf(a.z)};}
float sat(float x){return std::clamp(x,0.f,1.f);}
struct Bounds {V lo{1e6,1e6,1e6},hi{-1e6,-1e6,-1e6};void add(Bounds b){lo=low(lo,b.lo);hi=high(hi,b.hi);}};
bool slab(Bounds box,V o,V inv,float limit,float& near,float& far){
  V a=(box.lo-o)*inv,b=(box.hi-o)*inv,l=low(a,b),h=high(a,b);
  near=max(0.f,max(l.x,max(l.y,l.z)));far=min(limit,min(h.x,min(h.y,h.z)));return far>=near;
}
V invDir(V d){auto inv=[](float x){return 1/(fabsf(x)>.0000001f?x:copysignf(.0000001f,x));};return {inv(d.x),inv(d.y),inv(d.z)};}
struct Material{V rgb;float metal,rough;int texture;};
struct Solid{
  int kind,mat,layer;V c,h,ax[3];float bevel;Bounds world;
  V local(V v)const{return {dot(v,ax[0]),dot(v,ax[1]),dot(v,ax[2])};}
  V global(V v)const{return ax[0]*v.x+ax[1]*v.y+ax[2]*v.z;}
  float distance(V p)const{
    if(kind==3)return length(p)-h.x;
    if(kind==6||kind==7){
      float d=(length({p.x/h.x,p.y/h.y,p.z/h.z})-1)*min(h.x,min(h.y,h.z));
      return kind==7?max(d,-p.z-h.z*.12f):d;
    }
    if(kind==4)return hypotf(hypotf(p.x,p.y)-h.x,p.z)-bevel;
    if(kind==2||kind==5){
      float r=hypotf(p.x,p.y),a=r-h.x+bevel,b=fabsf(p.z)-h.z+bevel;
      float d=min(max(a,b),0.f)+hypotf(max(a,0.f),max(b,0.f))-bevel;
      if(kind==5)d=max(d,max(h.y-r,-p.y)); // upper half of a wheel guard
      return d;
    }
    V half=h;
    if(kind==8){
      float height=sat(.5f+.5f*p.z/h.z);
      V q=absV({p.x/(h.x*(.77f+.23f*height)),p.y/h.y,p.z/h.z});
      return (cbrtf(q.x*q.x*q.x+q.y*q.y*q.y+q.z*q.z*q.z)-1)*min(h.y,h.z)*.72f;
    }
    V q=absV(p)-half+V{bevel,bevel,bevel};
    return length(high(q,V{}))+min(max(q.x,max(q.y,q.z)),0.f)-bevel;
  }
  bool hit(V o,V d,float limit,float& t)const{
    V p=local(o-c),v=local(d),extent=h;
    if(kind==4)extent={h.x+bevel,h.x+bevel,bevel};
    if(kind==2||kind==5)extent.y=h.x;
    float a,b;if(!slab({extent*-1,extent},p,invDir(v),limit,a,b))return false;
    for(int i=0;i<52&&a<=b+.00018f;i++){
      float dist=distance(p+v*a);
      if(dist<.00016f){t=a;return a<limit;}
      a+=max(.00012f,dist);
    }return false;
  }
  V normal(V p)const{p=local(p-c);constexpr float e=.00025f;
    V x{e,0,0},y{0,e,0},z{0,0,e};
    return unit(global({distance(p+x)-distance(p-x),distance(p+y)-distance(p-y),distance(p+z)-distance(p-z)}));
  }
};
struct Node{Bounds box;int start,end,left=-1,right=-1;};
std::vector<Material> materials;std::vector<Solid> shapes;std::vector<int> order;std::vector<Node> nodes;
int build(int start,int end){
  Bounds b;for(int i=start;i<end;i++)b.add(shapes[order[i]].world);
  int id=nodes.size();nodes.push_back({b,start,end});
  if(end-start>5){V size=b.hi-b.lo;int axis=size.x>size.y&&size.x>size.z?0:size.y>size.z?1:2,mid=(start+end)/2;
    std::nth_element(order.begin()+start,order.begin()+mid,order.begin()+end,[axis](int a,int b){return shapes[a].c[axis]<shapes[b].c[axis];});
    int l=build(start,mid),r=build(mid,end);nodes[id].left=l;nodes[id].right=r;
  }return id;
}
int trace(V origin,V dir,float& far,bool shadow=false){
  V inv=invDir(dir);int stack[128],size=1,hit=-1;stack[0]=0;
  while(size){const Node& n=nodes[stack[--size]];float a,b;
    if(!slab(n.box,origin,inv,far,a,b))continue;
    if(n.left>=0){stack[size++]=n.left;stack[size++]=n.right;continue;}
    for(int i=n.start;i<n.end;i++){int j=order[i];const Solid& s=shapes[j];
      if(shadow&&materials[s.mat].texture==5)continue;
      if(!slab(s.world,origin,inv,far,a,b))continue;
      float t;if(s.hit(origin,dir,far,t)){far=t;hit=j;if(shadow)return j;}
    }
  }return hit;
}
uint32_t hash(uint32_t x){x^=x>>16;x*=0x7feb352d;x^=x>>15;x*=0x846ca68b;return x^(x>>16);}
float rand01(uint32_t& x){x=hash(x+0x9e3779b9);return (x>>8)*(1.f/16777216);}
float noise(V p,float s){int x=floorf(p.x*s),y=floorf(p.y*s),z=floorf(p.z*s);
  return (hash(uint32_t(x)*1973u+uint32_t(y)*9277u+uint32_t(z)*26699u)>>8)*(1.f/16777216);}
float smoothNoise(V p,float scale){
  V g=p*scale,cell{floorf(g.x),floorf(g.y),floorf(g.z)},f=g-cell;
  f={f.x*f.x*(3-2*f.x),f.y*f.y*(3-2*f.y),f.z*f.z*(3-2*f.z)};
  float value=0;
  for(int i=0;i<8;i++){int x=i&1,y=(i>>1)&1,z=(i>>2)&1;
    value+=noise(cell+V{float(x),float(y),float(z)},1)*(x?f.x:1-f.x)*(y?f.y:1-f.y)*(z?f.z:1-f.z);
  }return value;
}
const V sunlight=unit({-1.85f,-1.55f,1.60f});
V tangent(V n){return unit(cross(n,fabsf(n.z)>.85?V{0,1,0}:V{0,0,1}));}
V shade(int id,V p,V eye,uint32_t& seed,int rays){
  const Solid& obj=shapes[id];const Material& m=materials[obj.mat];
  V n=obj.normal(p),t=tangent(n),v=cross(n,t),surface=p+n*.0015f;
  V key=sunlight,lightT=tangent(key),lightV=cross(key,lightT);
  float ao=0,vis=0;
  for(int i=0;i<rays;i++){
    float ang=6.2831853f*(i+rand01(seed))/rays,f=sqrtf(rand01(seed)),cx=cosf(ang)*f,cy=sinf(ang)*f;
    float reach=.65f;if(trace(surface,unit(t*cx+v*cy+n*sqrtf(1-f*f)),reach,true)>=0)ao+=1-sat(reach/.65f);
    float horizon=60;V toward=unit(key+lightT*(cx*.043f)+lightV*(cy*.043f));
    if(dot(n,toward)>0&&trace(surface,toward,horizon,true)<0)vis+=1;
  }
  ao=1-.66f*ao/rays;vis/=rays;
  V rgb=m.rgb;float micro=noise(p,195)-.5f;
  if(m.texture==1)rgb=rgb*(1+.13f*micro+.035f*sinf(p.x*12+p.y*7)); // cast enamel
  if(m.texture==2)rgb=rgb*(1+.12f*noise(p,440)-.06f+.045f*sinf((p.x+p.z)*390)); // brushed steel
  if(m.texture==3){float grain=sinf(p.y*128+1.9f*sinf(p.x*4.1f)+.5f*sinf(p.z*125));rgb=rgb*(.94f+.16f*grain+.10f*micro);}
  if(m.texture==4){
    float grain=smoothNoise(p,1.9f)*.22f+smoothNoise(p,12)*.11f+.12f*micro;
    rgb=rgb*(.84f+grain);
  }
  if(m.texture==5){
    float warm=sat(.28f+.39f*p.z+.28f*sinf(p.x*1.7f+p.y*2.1f));
    float flutes=.025f*sinf((p.x+p.y)*165.f);
    return rgb*(.64f+.56f*warm+flutes)+V{.51f,.27f,.05f}*warm;
  }
  float nl=max(0.f,dot(n,key)),up=sat(n.z*.50+.50);
  V fill=V{.24f,.30f,.37f}*ao+V{.26f,.26f,.23f}*(ao*up);
  fill=fill+V{.38f,.32f,.24f}*(ao*max(0.f,dot(n,unit({-.4f,1.f,.38f}))));
  V sun=V{2.05f,1.62f,1.11f}*(nl*vis);
  V reflection=n*(2*dot(n,eye))-eye;
  float rough=m.rough,band=powf(max(0.f,dot(reflection,unit({-.50f,.72f,.56f}))),3.5f/(rough+.055f));
  float rim=powf(max(0.f,dot(reflection,unit({.83f,-.42f,.35f}))),5.f/(rough+.08f));
  float sky=sat(.5f+.5f*reflection.z);
  float strip=expf(-powf((reflection.y+.55f*reflection.x-.24f)/(.075f+rough*.24f),2));
  V env=V{.08f,.105f,.125f}+V{.47f,.53f,.55f}*(sky*sky)+V{2.3f,2.05f,1.56f}*band+V{1.2f,1.52f,1.67f}*rim+V{1.28f,1.41f,1.50f}*strip;
  float fres=powf(1-sat(dot(n,eye)),5);
  V f0=V{.045f,.045f,.045f}*(1-m.metal)+rgb*m.metal;
  V spec=f0+ (V{1,1,1}-f0)*fres;
  if(m.metal<.08f&&rough>.60f)spec=spec*.31f;
  float direct=powf(max(0.f,dot(n,unit(key+eye))),3+100/(rough+.15f))*vis;
  return rgb*(fill+sun)*(1-.75f*m.metal)+spec*(env*(.55f+.45f*ao)+V{2.5f,2.15f,1.75f}*direct);
}
float groundShadow(V point,uint32_t& seed,int rays){
  V a=tangent(sunlight),b=cross(sunlight,a);float dark=0;
  for(int i=0;i<rays;i++){
    float th=6.2831853f*(i+rand01(seed))/rays,r=sqrtf(rand01(seed)),x=r*cosf(th),y=r*sinf(th);
    float distance=4.f;
    if(trace(point,unit(sunlight+a*(x*.20f)+b*(y*.20f)),distance,true)>=0)dark+=.40f*(1-.17f*min(2.f,distance));
    distance=.52f;
    if(trace(point,{x,y,sqrtf(max(0.f,1-r*r))},distance,true)>=0)dark+=.52f*(1-distance/.52f);
  }return min(.78f,dark/rays);
}
int main(int argc,char** argv){
  if(argc!=3)return 2;
  std::ifstream in(argv[1]);int W,H,mode,samples,rays,nm,ns;float u,ox,oy;
  in>>W>>H>>u>>ox>>oy>>mode>>samples>>rays>>nm>>ns;
  auto vec=[&](){V v;in>>v.x>>v.y>>v.z;return v;};
  for(int i=0;i<nm;i++){Material m;m.rgb=vec();in>>m.metal>>m.rough>>m.texture;materials.push_back(m);}
  for(int i=0;i<ns;i++){Solid s;in>>s.kind>>s.mat>>s.layer;s.c=vec();s.h=vec();in>>s.bevel;
    for(auto& a:s.ax)a=vec();
    if(mode==0&&s.layer==2)continue;
    V ext=s.h;if(s.kind==4)ext={s.h.x+s.bevel,s.h.x+s.bevel,s.bevel};if(s.kind==2||s.kind==5)ext.y=s.h.x;
    V h=absV(s.ax[0])*ext.x+absV(s.ax[1])*ext.y+absV(s.ax[2])*ext.z+V{.0004f,.0004f,.0004f};
    s.world={s.c-h,s.c+h};shapes.push_back(s);
  }
  if(!in||shapes.empty())return 3;
  order.resize(shapes.size());std::iota(order.begin(),order.end(),0);build(0,order.size());
  V eye=unit({1,1,1});std::vector<unsigned char> pixels(W*H*4);
  #pragma omp parallel for schedule(dynamic,3)
  for(int y=0;y<H;y++)for(int x=0;x<W;x++){
    V sum{};int coverage=0;uint32_t seed=hash(x+8191*y);
    for(int k=0;k<samples;k++){float sx=(x+(k%samples+rand01(seed))/samples-ox)/u,sy=(y+((k*3)%samples+rand01(seed))/samples-oy)/u;
      if(mode==2){
        sum.x+=groundShadow({sy+sx*.5f,sy-sx*.5f,.002f},seed,rays);
        continue;
      }
      V origin=V{sy+sx*.5f,sy-sx*.5f,0}+eye*65;float far=150;int id=trace(origin,eye*-1,far);
      if(id<0||(mode==1&&shapes[id].layer==0))continue;
      sum=sum+shade(id,origin-eye*far,eye,seed,rays);coverage++;
    }
    int pos=(y*W+x)*4;
    if(mode==2){pixels[pos]=41;pixels[pos+1]=51;pixels[pos+2]=60;pixels[pos+3]=lroundf(255*sum.x/samples);continue;}
    if(coverage){sum=sum*(1.f/coverage);for(int ch=0;ch<3;ch++){
      float a=max(0.f,sum[ch]);a=a*(1+a/7)/(1+.64f*a);pixels[pos+ch]=lroundf(sat(powf(a,1/2.2f))*255);
    }}pixels[pos+3]=lroundf(255.f*coverage/samples);
  }
  std::ofstream out(argv[2],std::ios::binary);out.write(reinterpret_cast<char*>(pixels.data()),pixels.size());return out?0:4;
}
