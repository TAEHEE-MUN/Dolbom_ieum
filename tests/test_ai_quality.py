from ai.detector import analyze

def test_gap_marks_quality_and_does_not_accumulate_stationary_time():
    events=[{'seq':1,'kind':'start','occurred_at':'2026-11-23T00:00:00Z'},
            {'seq':2,'kind':'end','occurred_at':'2026-11-23T04:00:00Z'}]
    points=[{'lat':37,'lon':127,'accuracy':5,'observed_at':t} for t in
            ['2026-11-23T00:01:00Z','2026-11-23T03:31:00Z']]
    codes={x['code'] for x in analyze({},events,points)}
    assert 'collection_gap' in codes and 'dwell' not in codes

def test_break_gap_is_not_collection_failure():
    events=[{'seq':i,'kind':k,'occurred_at':t} for i,k,t in
            [(1,'start','2026-11-23T00:00:00Z'),(2,'pause','2026-11-23T00:02:00Z'),
             (3,'resume','2026-11-23T03:30:00Z'),(4,'end','2026-11-23T04:00:00Z')]]
    points=[{'lat':37,'lon':127,'accuracy':5,'observed_at':t} for t in
            ['2026-11-23T00:01:00Z','2026-11-23T03:31:00Z']]
    assert 'collection_gap' not in {x['code'] for x in analyze({},events,points)}
