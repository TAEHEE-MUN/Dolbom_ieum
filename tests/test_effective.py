from backend.main import effective_events
from ai.detector import cross_visit_patterns
from datetime import datetime, timezone

def test_approved_changes_only_preserve_original():
    original=[{'id':'e','occurred_at':'2026-01-01T09:00:00Z'}]
    changes=[{'event_id':'e','target':'event','status':'approved','decided_at':'1','proposed':{'occurred_at':'2026-01-01T09:10:00Z'}},
             {'event_id':'e','target':'event','status':'pending','decided_at':None,'proposed':{'occurred_at':'bad'}}]
    assert effective_events(original,changes)[0]['occurred_at']=='2026-01-01T09:10:00Z'
    assert original[0]['occurred_at']=='2026-01-01T09:00:00Z'

def test_overlap_works_without_gps():
    visits=[{'id':id,'worker_id':'w','state':'ended'} for id in ['a','b']]
    events=[{'visit_id':id,'seq':seq,'kind':kind,'occurred_at':f'2026-01-01T{hour}:00Z'} for id,times in [('a',['09:00','10:00']),('b',['09:40','10:40'])] for seq,kind,hour in zip([1,2],['start','end'],times)]
    result=cross_visit_patterns(visits,events,[],[],[],datetime(2026,1,2,tzinfo=timezone.utc))
    assert result[0]['code']=='overlap_b'
    assert result[0]['evidence']['overlap_seconds']==1200
