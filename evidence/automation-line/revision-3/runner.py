import os,time,json,subprocess,pathlib,hashlib
root=pathlib.Path('/workspace/Logistics-Boss');out=root/'evidence/automation-line/revision-3'
def read(p):
 try:return pathlib.Path(p).read_text()
 except OSError:return None
def sample():
 return {'epoch':time.time()*1000,'cpu_stat':read('/sys/fs/cgroup/cpu.stat'),'cpu_pressure':read('/sys/fs/cgroup/cpu.pressure'),'proc_stat':read('/proc/stat'),'loadavg':read('/proc/loadavg')}
report=[]
for label in ['A1','B1','B2','A2']:
 variant='control' if label.startswith('A') else 'candidate';directory=f'/tmp/flotra-line-web/{variant}'
 target=out/label;target.mkdir(exist_ok=True)
 env={**os.environ,'NODE_PATH':'/workspace/.flotra-tools/browser/node_modules','CHROMIUM_EXECUTABLE':'/usr/bin/chromium','FLOTRA_JOURNEY_CASES':'mature-performance','FLOTRA_EXPORTED_DIRECTORY':directory}
 samples=[sample()]
 with (target/'run.log').open('w') as log:
  proc=subprocess.Popen(['node','/tmp/flotra-performance-diagnosis/browser_growth_journey.cjs',f'http://127.0.0.1:8765/{variant}/',str(target),'/tmp/flotra-campaign-test.chp96q/growth-fixtures'],env=env,stdout=log,stderr=subprocess.STDOUT)
  deadline=time.monotonic()+240
  while proc.poll() is None and time.monotonic()<deadline:
   time.sleep(1);samples.append(sample())
  if proc.poll() is None:proc.terminate();proc.wait();status='timeout'
  else:status=proc.returncode
 (target/'host-samples.json').write_text(json.dumps(samples))
 result=json.loads((target/'growth-journey.json').read_text()) if (target/'growth-journey.json').exists() else None
 report.append({'label':label,'exitCode':status,'test':result['tests'][0] if result else None})
 (out/'comparison.json').write_text(json.dumps(report,indent=2))
 print(label,status,json.dumps(report[-1]['test'].get('performance') if result else None),flush=True)
