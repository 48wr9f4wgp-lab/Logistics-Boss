import json,pathlib,statistics,hashlib
root=pathlib.Path('/workspace/Logistics-Boss');base=root/'evidence/automation-line';out=base/'revision-3'
def load(p):return json.loads(p.read_text())
def cpu(s):return {k:int(v) for k,v in [line.split() for line in s.splitlines()]}
def q(values,p):
 values=sorted(values);return values[min(len(values)-1,int(len(values)*p))]
analysis={'additional_runs':{},'fixed_state':{}}
for run in load(out/'comparison.json'):
 n=run['label'];t=run['test'];raw=load(out/n/'raw-samples.json');host=load(out/n/'host-samples.json');v={}
 for phase,data in raw.items():
  rows=data['timeline'][5:];h=[x for x in host if rows[0]['epoch']<=x['epoch']<=rows[-1]['epoch']]
  a,b=cpu(h[0]['cpu_stat']),cpu(h[-1]['cpu_stat']);wall=(h[-1]['epoch']-h[0]['epoch'])/1000
  v[phase]={'sampled_wall_seconds':wall,'cpu_seconds':(b['usage_usec']-a['usage_usec'])/1e6,'throttled_seconds':(b['throttled_usec']-a['throttled_usec'])/1e6,'periods':b['nr_periods']-a['nr_periods'],'throttled_periods':b['nr_throttled']-a['nr_throttled'],'first_sim_time':rows[0]['simTime'],'last_sim_time':rows[-1]['simTime'],'first_shipped':rows[0]['shipped'],'last_shipped':rows[-1]['shipped'],'sampled_save_phase_counts':{str(p):sum(x['autosave']['phase']==p for x in rows) for p in range(4)},'unique_cpu_values':len(set(x['performance']['processMs'] for x in rows)),'samples':len(rows)}
 p=t['performance'];v['gate']={'median_actual':p['active']['rafMedianMs'],'median_limit':max(75,p['uiOnly']['rafMedianMs']*1.75),'p95_actual':p['active']['rafP95Ms'],'p95_limit':max(120,p['uiOnly']['rafP95Ms']*2),'status':t['status']}
 analysis['additional_runs'][n]=v
rows={n:load(base/f'revision-2/same-state-main/{n}.json')['rows'] for n in ['A1','B1','B2','A2']}
for n,rs in rows.items():
 analysis['fixed_state'][n]={'phase_cpu_ms':{str(p):{'n':len(v:=[x['main_usec']/1000 for x in rs if x['save_phase']==p]),'median':statistics.median(v),'p95':q(v,.95)} for p in range(4)}}
analysis['fixed_state']['paired']={a+'_'+b:{'draw_mismatches':sum(x['draw_calls']!=y['draw_calls'] for x,y in zip(rows[a],rows[b])),'cpu_mean_delta_ms':statistics.mean((y['main_usec']-x['main_usec'])/1000 for x,y in zip(rows[a],rows[b]))} for a,b in [('A1','B1'),('A2','B2')]}
plan=load(out/'predeclared-plan.json');analysis['production_source_unchanged']=all(hashlib.sha256((root/p).read_bytes()).hexdigest()==digest for p,digest in plan['production_source_sha256'].items())
(out/'analysis.json').write_text(json.dumps(analysis,indent=2))
lines=['| 比較 | run | CPU中央値/p95 ms | RAF中央値/p95 ms | draw最大 | 結果 |','|---|---|---:|---:|---:|---|']
def add(group,label,p,status):
 lines.append(f"| {group} | {label} | {p['processMedianMs']:.1f}/{p['processP95Ms']:.1f} | {p['rafMedianMs']:.1f}/{p['rafP95Ms']:.1f} | {p['drawCallsMax']} | {status} |")
for group,runs in [('初案通常',load(base/'performance-abba.json')['runs']),('改訂通常',load(base/'revision-2/normal-abba/comparison.json')['runs'])]:
 for x in runs:add(group,x['label'],x['test']['performance']['active'],x['test']['status'])
for kind,group,key in [('same-state-view','固定view','view_usec'),('same-state-main','固定Main保存','main_usec')]:
 for x in load(base/f'revision-2/{kind}/summary.json')['runs']:
  p=x['summary'];raf=p.get('raf_ms');raftext=f"{raf['p50']:.1f}/{raf['p95']:.1f}" if raf else '未取得'
  lines.append(f"| {group} | {x['label']} | {p[key]['p50']/1000:.1f}/{p[key]['p95']/1000:.1f} | {raftext} | {p['draw_calls']['max']} | 診断 |")
for x in load(out/'comparison.json'):add('追加通常診断',x['label'],x['test']['performance']['active'],x['test']['status'])
(out/'all-abba-table.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines));print(json.dumps(analysis['additional_runs'],indent=2))
