from datetime import datetime, timezone, timedelta
import pytest
from backend.domain import summarize, can_close
from ai.detector import analyze

def event(seq,kind,h,m=0):
    return dict(seq=seq,kind=kind,occurred_at=f'2026-11-20T{h:02}:{m:02}:00+00:00')

def test_normal_visit_excludes_break():
    r=summarize([event(1,'start',9),event(2,'pause',11),event(3,'resume',11,30),event(4,'end',13,30)])
    assert r==dict(state='ended',care_seconds=14400,break_seconds=1800,total_seconds=16200)

def test_end_during_break():
    r=summarize([event(1,'start',9),event(2,'pause',10),event(3,'end',10,30)])
    assert r['care_seconds']==3600 and r['break_seconds']==1800

def test_duplicate_state_rejected():
    with pytest.raises(ValueError): summarize([event(1,'start',9),event(2,'start',10)])

def test_missing_reply_blocks_closure():
    assert not can_close('', '기관 설명','explained',False)
    assert not can_close('지원사 설명','기관 설명','explained',True)
    assert can_close('지원사 설명','기관 설명','explained',False)

def test_missing_gps_not_stationary():
    r=analyze({},[event(1,'start',9),event(2,'end',13)],[])
    assert [x['code'] for x in r]==['quality']

def samples(start,minutes):
    return [dict(lat=37,lon=127,accuracy=5,observed_at=(start+timedelta(minutes=i)).isoformat()) for i in range(minutes)]

def test_pause_breaks_continuous_dwell():
    r=analyze({},[event(1,'start',9),event(2,'pause',10),event(3,'resume',12),event(4,'end',14)],samples(datetime(2026,11,20,9,tzinfo=timezone.utc),300))
    assert 'dwell' not in [x['code'] for x in r]

def test_valid_dwell_is_only_candidate():
    r=analyze({},[event(1,'start',9),event(2,'end',13)],samples(datetime(2026,11,20,9,tzinfo=timezone.utc),240))
    assert any(x['code']=='dwell' and '정상' in x['reason'] for x in r)
