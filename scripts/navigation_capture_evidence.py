#!/usr/bin/env python3
"""Read-only CI evidence reporting; no game controls, save writes or publication."""
import hashlib,json,pathlib,sys,zipfile

def report(out):
    reuse=json.loads((out/'baseline-reuse.json').read_text()) if (out/'baseline-reuse.json').exists() else None
    if reuse:print('NAVIGATION_BASELINE_REUSE',json.dumps(reuse),flush=True)
    for variant in ['candidate'] if reuse else ['baseline','candidate']:
        p=out/variant/'navigation-space.json'
        if not p.exists():
            print('NAVIGATION_STAGE',json.dumps({'variant':variant,'state':'no browser report; inspect preceding build/native stage'}),flush=True);continue
        d=json.loads(p.read_text())
        for c in d.get('cases',[]):
            states=c.get('states',{});last=next(reversed(states.values()),{}) if states else {}
            print('NAVIGATION_CASE',json.dumps({'variant':variant,'case':c['name'],'status':c.get('status'),'completedScreens':list(states),'error':c.get('error'),'viewport':c.get('viewport'),'last':{'sheet':last.get('sheet'),'worldRect':last.get('worldRect'),'status':last.get('status'),'wallet':last.get('wallet'),'progress':last.get('progress'),'saveLabels':[l['text'] for l in last.get('labels',[]) if '保存' in l.get('text','')],'visibleButtons':[{k:b.get(k) for k in ['name','text','x','y','width','height','disabled','fontSize']} for b in last.get('buttons',[]) if b.get('visible')]}},ensure_ascii=False),flush=True)
        if d.get('error'):print('NAVIGATION_FIRST_FAILURE',variant,d['error'],flush=True)

    p=out/'headers/navigation-headers.json'
    if p.exists():
        d=json.loads(p.read_text())
        for c in d.get('cases',[]):print('NAVIGATION_HEADER_CASE',json.dumps({'case':c['name'],'status':c.get('status'),'states':list(c.get('states',{})),'measurements':c.get('measurements'),'error':c.get('error')},ensure_ascii=False),flush=True)
        if d.get('error'):print('NAVIGATION_HEADER_FIRST_FAILURE',d['error'],flush=True)

def package(out):
    out.mkdir(parents=True,exist_ok=True);dest=out/'review';dest.mkdir(exist_ok=True)
    report(out)
    sizes=['1280x720-dpr1','1920x1080-dpr1','375x667-dpr2','390x844-dpr3'];images=[];reports=[]
    for v in ['baseline','candidate']:
        reports += [p for p in [out/v/'navigation-space.json'] if p.exists()]
        for size in sizes:
            for screen in ['warehouse','jobs','equipment']:
                p=out/v/(size+'-mature-'+screen+'.jpg')
                if p.exists():images.append(p)
    # Preserve an actual failure screen if the planned matrix stopped early.
    if len(images)!=24:
        images+=list(out.glob('*/*failure.jpg'))
    primary_count=len([p for p in images if not p.name.endswith('-failure.jpg')])
    reuse=json.loads((out/'baseline-reuse.json').read_text()) if (out/'baseline-reuse.json').exists() else None
    images+=list((out/'headers').glob('*.jpg'))
    reports+=[p for p in [out/'headers/navigation-headers.json',out/'baseline-reuse.json'] if p.exists()]
    summary={'requiredPrimaryImages':12 if reuse else 24,'actualPrimaryImages':primary_count,'baselinePrimaryImagesReused':12 if reuse else 0,'baselineProvenance':reuse,'capturedFiles':[str(p.relative_to(out)) for p in images],'qualification':'pixels require human review; source geometry is not visual acceptance'}
    (dest/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    batches=[('navigation-review-images.zip',images)]
    def write(name,files):
        target=dest/name
        with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
            for p in files+reports:z.write(p,str(p.relative_to(out)))
        return target
    target=write(batches[0][0],images)
    if target.stat().st_size>=5_000_000:
        target.unlink()
        for label,prefixes in [('desktop',['1000x720-dpr1']+sizes[:2]),('phone',sizes[2:])]:
            target=write('navigation-review-'+label+'.zip',[p for p in images if any(p.name.startswith(pre) for pre in prefixes)])
            assert target.stat().st_size<5_000_000,'Review artifact unexpectedly exceeds5MB'
    print('NAVIGATION_REVIEW_ARTIFACT',json.dumps(summary),flush=True)
    for p in dest.glob('*.zip'):print('NAVIGATION_REVIEW_ZIP',p.name,p.stat().st_size,flush=True)

if sys.argv[1]=='verify':
    m=json.loads(pathlib.Path('scripts/navigation_capture_sources.json').read_text())
    for name,expected in m['sourceSHA256'].items():
        assert hashlib.sha256(pathlib.Path(name).read_bytes()).hexdigest()==expected,name
    actual={str(p) for p in pathlib.Path('flotra-campaign').rglob('*') if p.is_file() and '.godot' not in p.parts}
    assert actual==set(m['sourceSHA256']),'Complete frozen project source key set'
    print('NAVIGATION_FROZEN_SOURCE_OK',len(actual),'files',flush=True)
elif sys.argv[1]=='report':report(pathlib.Path(sys.argv[2]))
elif sys.argv[1]=='package':package(pathlib.Path(sys.argv[2]))
else:raise SystemExit('Unknown action')
