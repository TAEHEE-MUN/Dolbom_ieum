"""Generate clearly labelled, deterministic examples; never real beneficiary records."""
import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path
from ai.detector import analyze

def generate():
    random.seed(42)
    start=datetime(2026,1,1,0,tzinfo=timezone.utc)
    home={'lat':36.64,'lon':127.49}
    scenarios=[]
    for name,outside,hours,quality in [('normal',False,1,10),('outside',True,2.5,10),('dwell',False,3.2,10),('gps_poor',False,3.2,500)]:
        end=start+timedelta(hours=hours)
        events=[{'seq':1,'kind':'start','occurred_at':start.isoformat()},{'seq':2,'kind':'end','occurred_at':end.isoformat()}]
        points=[{'observed_at':(start+timedelta(minutes=i)).isoformat(),'lat':home['lat']+(.05 if outside else 0)+random.uniform(-.00001,.00001),'lon':home['lon'],'accuracy':quality} for i in range(int(hours*60))]
        visit={'home_snapshot':home,'duration':hours*3600}
        scenarios.append({'synthetic':True,'scenario':name,'visit':visit,'events':events,'locations':points,'candidates':analyze(visit,events,points)})
    return scenarios

if __name__=='__main__':
    dest=Path('data/synthetic/examples.json');dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps({'warning':'합성 시나리오. 실제 AI 성능·적발률이 아님.','examples':generate()},ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'Synthetic examples written: {dest}')
