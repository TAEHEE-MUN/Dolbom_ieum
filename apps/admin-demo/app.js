'use strict';
// All actions below operate on this tab's memory only. No API/Auth/GPS calls.
const state={visits:structuredClone(initialVisits),cases:structuredClone(initialCases),changes:structuredClone(initialChanges),people:structuredClone(initialPeople),selectedCase:'C-0612-104',selectedChange:'R-0612-031',changeTab:'실제 기록 정정',peopleTab:'활동지원사',settingTab:'관리자 권한',caseFilters:{period:'최근 7일',source:'전체',status:'전체'},visitFilters:{},peopleSearch:'',scheduleDay:0,addedSchedules:[],menu:false,logs:[]};
const routes=Object.keys(frameRoutes),app=document.querySelector('#app'),dialog=document.querySelector('#dialog');
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const icon=(file,size=18)=>`<img class="icon" src="assets/${file}.svg" width="${size}" height="${size}" style="width:${size}px;height:${size}px" alt="">`;
const brand=()=>'<div class="brand"><span>돌봄</span>이음</div>';
const button=(label,action,cls='',extra='')=>`<button type="button" data-action="${action}" class="${cls}" ${extra}>${label}</button>`;
const link=(label,route)=>`<a class="text-link" href="#${route}">${label}</a>`;
const badge=value=>`<span class="badge ${['돌봄 중','규칙','AI 후보'].includes(value)?'green':['쉬는 중','승인 대기','기관 답변 대기','센서 시험','임시 방문','GPS 품질 부족'].includes(value)?'yellow':['검토 완료','연결됨','승인'].includes(value)?'completed':''}">${esc(value)}</span>`;
const select=(name,options,value='전체')=>`<select name="${name}">${options.map(s=>`<option${s===value?' selected':''}>${esc(s)}</option>`).join('')}</select>`;
const title=(text,description,action='',extra='')=>`<div class="page-title ${extra}"><div><h1>${text}</h1><p>${description}</p></div>${action}</div>`;
const table=(headers,rows,cls='')=>`<div class="table-wrap"><table class="${cls}"><thead><tr>${headers.map(h=>`<th scope="col">${h}</th>`).join('')}</tr></thead><tbody>${rows.length?rows.map(r=>`<tr ${r.attr||''}>${(r.cells||r).map(v=>`<td>${v}</td>`).join('')}</tr>`).join(''):`<tr><td class="empty" colspan="${headers.length}">조건에 맞는 기록이 없습니다.</td></tr>`}</tbody></table></div>`;
const panel=(heading,description,body,action='',cls='')=>`<section class="panel ${cls}"><div class="panel-head"><div><h2>${heading}</h2>${description?`<p>${description}</p>`:''}</div>${action}</div>${body}</section>`;
const tabs=(values,active,action)=>`<div class="tabs" role="tablist">${values.map(v=>button(esc(v),action,v===active?'active':'',`role="tab" aria-selected="${v===active}" data-value="${esc(v)}"`)).join('')}</div>`;
function currentRoute(){const r=location.hash.slice(1).split('?')[0];return routes.includes(r)?r:'login';}
function navigate(route){if(currentRoute()===route)render();else location.hash=route;}
function toast(text){document.querySelector('#toast').textContent=text;clearTimeout(toast.timer);toast.timer=setTimeout(()=>document.querySelector('#toast').textContent='',3800);}
function modal(heading,body){dialog.innerHTML=`<div class="dialog-head"><h2 id="dialog-title">${esc(heading)}</h2>${button('×','close-dialog','plain','aria-label="닫기"')}</div><div class="dialog-body">${body}</div>`;dialog.showModal();}
function info(heading,message){modal(heading,`<p>${esc(message)}</p><div class="end-actions">${button('확인','close-dialog','primary')}</div>`);}
function render(){
 const r=currentRoute();document.title=`돌봄이음 · ${r==='login'?'기관 관리자 로그인':'관리자 정적 데모'}`;
 document.body.classList.remove('mobile-menu-open');
 app.innerHTML=r==='login'?login():shell(r);
 document.querySelector('main')?.setAttribute('data-frame-id',frameRoutes[r]);
 window.scrollTo(0,0);
}
const navItems=[['overview','오늘의 현황'],['schedule','일정 관리'],['visits','방문 기록'],['cases','검토 항목'],['changes','변경 요청'],['people','지원사·이용자'],['quality','기록 품질'],['settings','기관 설정·이력']];
function shell(r){
 const active=r==='detail'?'cases':r==='comparison'?'changes':r;
 return `<a class="sidebar-brand" href="#overview" aria-label="돌봄이음 오늘의 현황">${brand()}</a><header class="topbar">${button(icon('bcb5f'),'toggle-menu','plain','aria-label="주 메뉴 열기 또는 닫기"')}<span class="current-menu">${esc(navItems.find(([path])=>path===active)?.[1]||'')}</span><div class="top-actions">${button(`${icon('fd280')}<span class="counter">3</span>`,'notifications','plain','aria-label="알림 3건"')}<div class="account">${button(icon('3697d')+icon('00011',12),'account','plain','aria-label="관리자 계정"')}</div></div></header>
 <aside class="sidebar"><nav class="nav-list" aria-label="주 메뉴">${navItems.map(([path,label],i)=>`<a href="#${path}" class="${active===path?'active':''}" ${active===path?'aria-current="page"':''}><small>${i+1}</small>${label}</a>`).join('')}</nav><div class="sidebar-bottom">${r==='people'?button(`${icon('22e51')}<span>시연 설정<small>외부 동작 가상 전환</small></span>`,'demo-settings','demo-settings'):''}<div class="sidebar-note">${icon('25341')}현재 기관의 자료만 표시됩니다.</div></div></aside>
 <main class="workspace" id="content" tabindex="-1">${({overview, schedule,visits,cases,changes,people,quality,settings,detail,comparison})[r]()}</main>`;
}
function login(){return `<header class="login-header">${brand()}<small>기관 관리자용</small></header><main id="content" class="login-main"><section class="login-card"><div class="login-brand">${brand()}<div class="mascot" aria-hidden="true">
 <img src="assets/acf66.svg" style="left:24.74px;top:63.14px;width:35.26px;height:15.03px" alt=""><img src="assets/dcc59.svg" style="left:59.28px;top:33.66px;width:18.85px;height:22.32px" alt=""><img src="assets/00da7.svg" style="left:29.66px;top:6.41px;width:24.4px;height:16.74px" alt=""><img src="assets/d9b2c.svg" style="left:13.48px;top:17.77px;width:52.84px;height:55.58px" alt=""><img src="assets/40aa9.svg" style="left:23.83px;top:41.85px;width:36.06px;height:12.68px" alt=""></div></div><h1>기관 관리자 로그인</h1><p>방문 기록을 확인하고 필요한 업무를 처리하세요.</p><form data-form="login"><label>계정<input name="account" type="email" value="manager@donghaeng.or.kr" autocomplete="off"></label><label>비밀번호<input name="password" type="password" autocomplete="off"></label><button class="primary">로그인</button></form>${button('계정 이용에 도움이 필요하신가요?','login-help','plain help')}</section></main>`;}
function overview(){
 const cards=['방문 예정','돌봄 중','쉬는 중','종료'].map((v,i)=>button(`<span>${v}</span><strong>${state.visits.filter(row=>row[5]===['예정','돌봄 중','쉬는 중','종료'][i]).length}<small>건</small></strong>`,'visit-metric','metric',`data-value="${v==='방문 예정'?'예정':v}"`)).join('');
 const counts=[state.cases.filter(c=>c.status!=='검토 완료').length,state.cases.filter(c=>c.status==='답변 대기').length,state.cases.filter(c=>c.status==='기관 답변 대기').length,state.changes.filter(c=>c.status==='승인 대기').length];
 const tasks=['확인이 필요한 항목','지원사 답변 대기','기관 답변 대기','정정 승인 대기'].map((v,i)=>button(`${v}<strong>${counts[i]}<small>건</small></strong><p>${['완료된 항목 제외','질문 요청 발송','기관의 답변 필요','기관의 변경 요청 검토'][i]}</p>`,'task-metric',`metric ${[0,2,3].includes(i)?'warning':''}`,`data-index="${i}"`)).join('');
 const rows=[...state.cases].reverse().map(c=>[
 `<small>${c.date||(['C-0612-104','C-0612-107'].includes(c.id)?'2026.03.12':'2026.03.11')}</small><br>${c.time}`,`<b>${c.worker}</b>`,`<div class="reason">${c.reason}</div>`,badge(c.source),`<span class="nowrap">${c.range}</span>`,badge(c.status),c.manager,caseLink(c.id,'상세 보기')]);
 return `<div class="eyebrow">2026.03.12</div>${title('오늘의 활동 기록','확인이 필요한 기록과 처리 대기 업무를 우선순위에 따라 확인합니다.',button(icon('7c8b7')+'새로고침','refresh','soft'),'overview-title')}
 <div class="metrics"><section class="visits-metrics"><h2>방문 상태 <small>단위: 방문</small></h2><div class="metric-stack">${cards}</div></section><section class="tasks-metrics"><h2>처리할 업무 <small>사건·요청 단위를 구분해 표시</small></h2><div class="metric-stack">${tasks}</div></section></div>
 ${panel('확인할 기록','확인 이유와 근거를 검토한 뒤 필요한 조치를 선택하세요.',table(['발생 시각','활동지원사','확인 이유','출처','해당 시간 구간','검토 상태','담당자','상세'],rows)+`<div class="pagination">${button(icon('f3bfe',14),'page-prev','','disabled aria-label="이전 페이지"')}<span>1</span>${button(icon('c7858',14),'page-next','','disabled aria-label="다음 페이지"')}<small>총 ${state.cases.length}건</small></div>`,link('전체 사건 보기 '+icon('1de22',14),'cases'))}
 ${panel('오늘 방문 목록',`전체 상태 · ${state.visits.length}건`,table(['방문 ID','지원사·이용자','예정','실제','방문 상태','검토 상태','상세'],state.visits.map(v=>[v[0],`<b>${v[1]}</b>`,v[2],v[3],badge(v[5]),v[8],visitLink(v[0])])),link('방문 기록 전체 보기 '+icon('1de22',14),'visits'))}`;
}
function caseLink(id,label='근거 확인'){return button(label,'case-detail','text-link',`data-id="${id}"`);}
function visitLink(id){return button('상세 보기','visit-detail','text-link',`data-id="${id}"`);}
function schedule(){
 const day=new Date(Date.UTC(2026,2,12+state.scheduleDay));
 const date=state.scheduleDay===0?'2026년 3월 12일 목요일':`${day.getUTCFullYear()}년 ${day.getUTCMonth()+1}월 ${day.getUTCDate()}일`;
 const blocks=state.scheduleDay===0?[
 {col:0,top:0,height:270,name:'김철수님 가정방문',time:'09:00~13:30',note:'11:00 휴게'},
 {col:1,top:300,height:60,name:'문태희님 가정방문',time:'14:00~15:00'},
 {col:1,top:346,height:76,name:'홍지우님 가정방문',time:'14:40~15:40',overlap:true},
 {col:2,top:60,height:270,name:'김고구마님 가정방문',time:'10:00~14:30'},
 ]:[];
 blocks.push(...state.addedSchedules.filter(s=>s.day===state.scheduleDay));
 return `${title('일정 관리','지원사별 예정 일정을 확인하고 등록·편집합니다.',button(icon('4388a')+'일정 등록','add-schedule','primary'))}<div class="calendar-toolbar">${button(icon('9ae76'),'prev-day','plain','aria-label="이전 날짜"')}<strong>${date}</strong>${button(icon('b519e'),'next-day','plain','aria-label="다음 날짜"')}</div><div class="calendar-scroll"><div class="calendar"><div class="col-head muted">시각</div>${['홍길동','박선영','오민수','이정은'].map(n=>`<div class="col-head">${n}</div>`).join('')}<div class="hours">${Array.from({length:9},(_,i)=>`<div>${String(9+i).padStart(2,'0')}:00</div>`).join('')}</div>${Array.from({length:4},(_,i)=>`<div class="calendar-column" style="grid-column:${i+2}">${blocks.filter(b=>b.col===i).map(b=>button(`<strong>${esc(b.name)}</strong>${esc(b.time)}${b.note?`<small>${b.note}</small>`:''}`,'schedule-view',`appointment ${b.overlap?'overlap':''}`,`style="top:${b.top}px;height:${b.height}px" data-name="${esc(b.name)}" data-time="${esc(b.time)}"`)).join('')}</div>`).join('')}</div></div>`;
}
function visits(){
 const f=state.visitFilters;
 const controls=[['날짜',`<input name="날짜" type="date" value="${esc(f['날짜']||'')}">`],['지원사',select('지원사',['전체',...new Set(state.visits.map(v=>v[1]))],f['지원사'])],['이용자',select('이용자',['전체','김철수','이용자 나','이용자 다'],f['이용자'])],['방문 상태',select('방문 상태',['전체','예정','돌봄 중','쉬는 중','종료'],f['방문 상태'])],['임시 방문 여부',select('임시 방문 여부',['전체','정규','임시 방문'],f['임시 방문 여부'])],['기록 수신 상태',select('기록 수신 상태',['전체','수신','미수신'],f['기록 수신 상태'])]];
 const rows=state.visits.filter(v=>(!f['지원사']||f['지원사']==='전체'||v[1]===f['지원사'])&&(!f['방문 상태']||f['방문 상태']==='전체'||v[5]===f['방문 상태'])&&(!f['임시 방문 여부']||f['임시 방문 여부']==='전체'||v[7]===f['임시 방문 여부'])&&(!f['날짜']||f['날짜']==='2026-03-12')&&(!f['기록 수신 상태']||f['기록 수신 상태']==='전체'||(f['기록 수신 상태']==='미수신'?v[6]==='—':v[6]!=='—'))&&(!f['이용자']||f['이용자']==='전체'||v[0]===(f['이용자']==='김철수'?'V-260312-08':f['이용자']==='이용자 나'?'V-240612-02':'V-240612-03')));
 return title('방문 기록·임시 방문','예정 정보와 실제 수신 기록을 함께 확인합니다.')+`<form class="panel filters" data-form="visit-filters">${controls.map(([l,c])=>`<label>${l}${c}</label>`).join('')}</form>`+panel('방문 기록',`검색 결과 ${rows.length}건`,table(['지원사','예정 시간','실제 시간','휴게','방문 상태','마지막 수신','임시 여부','검토 상태','상세'],rows.map(v=>[`<b>${v[1]}</b>`,v[2],v[3],v[4],badge(v[5]),v[6],v[7]==='임시 방문'?badge(v[7]):v[7],v[8],visitLink(v[0])])));
}
function cases(){
 const f=state.caseFilters;
 const filtered=state.cases.filter(c=>(f.source==='전체'||c.source===f.source)&&(f.status==='전체'||c.status===f.status)&&(f.period!=='오늘'));
 return title('검토 항목','규칙·AI 후보·센서 시험·데이터 품질 항목을 근거와 함께 검토합니다.')+`<form class="panel filters four" data-form="case-filters"><div class="filter-summary"><b>현재 적용 조건</b><small>오늘 포함 ${esc(f.period)} · ${f.source==='전체'?'전체 출처':esc(f.source)} · ${esc(f.status)}</small></div><label>기간${select('기간',['최근 7일','오늘','최근 30일'],f.period)}</label><label>출처${select('출처',['전체','규칙','AI 후보','센서 시험','데이터 품질'],f.source)}</label><label>검토 상태${select('검토 상태',['전체','답변 대기','분석 보류','기관 답변 대기','검토 완료'],f.status)}</label><button class="primary">${icon('151eb')}검색</button></form>`+
 panel('검토 목록','같은 방문·구간·원인의 후보는 하나의 사건으로 묶어 표시합니다.',table(['사건 ID','발생 시각','지원사','확인 이유','출처','상태','담당자','상세'],filtered.map(c=>[c.id,`<small>${c.date||'2026.03.11'}</small><br>${c.time}`,`<b>${c.worker}</b>`,`<div class="reason">${c.reason}</div>`,badge(c.source),c.status,c.manager,caseLink(c.id)])));
}
function changeTable(){return table(['요청 ID','신청자','대상 방문','요청 유형','신청 시각','처리 상태','상세'],state.changes.map(c=>({attr:currentRoute()==='comparison'&&state.selectedChange===c.id?'class="selected"':'',cells:[c.id,c.worker,c.visit,c.type,c.time,badge(c.status),button('비교 보기','compare','text-link',`data-id="${c.id}"`)]})));}
function changes(){return title('변경 요청·정정 승인','일정 변경과 실제 기록 정정을 구분해 원본과 요청 값을 검토합니다.')+tabs(['실제 기록 정정','일정 변경'],state.changeTab,'change-tab')+panel(state.changeTab==='실제 기록 정정'?'정정 요청':'일정 변경 요청','승인 전에는 실제 기록이 변경되지 않습니다.',state.changeTab==='실제 기록 정정'?changeTable():'<div class="empty">제공된 디자인에는 일정 변경 요청 예시 데이터가 없습니다.</div>');}
function comparison(){const c=state.changes.find(v=>v.id===state.selectedChange)||state.changes[0];return changes()+`<section class="panel comparison-panel" id="comparison"><div class="panel-head"><div><small><b>${c.id}</b></small><h2>${c.type}</h2></div>${button(icon('b06b3'),'close-compare','plain','aria-label="비교 닫기"')}</div><div class="panel-body"><div class="comparison-grid"><div class="value-box"><small>원래 값</small><strong>${esc(c.original||'원본 값 미제공')}</strong><small>원본 기록 · 보존</small></div>${'<span class="comparison-arrow">→</span>'}<div class="value-box"><small>요청 값</small><strong>${esc(c.requested||'요청 값 미제공')}</strong><small>${c.status==='승인'?'정정본 적용':c.status==='반려'?'반려 · 미적용':'아직 미적용'}</small></div></div><dl><div class="definition-row"><dt>변경 사유</dt><dd>${esc(c.reason||'상세 사유가 제공되지 않았습니다.')}</dd></div><div class="definition-row"><dt>관련 기록</dt><dd>${c.visit}의 자동 수신 기록</dd></div><div class="definition-row"><dt>영향받는 확인 사건</dt><dd>${esc(c.related||'관련 사건 정보 미제공')}</dd></div>${c.decision?`<div class="definition-row"><dt>처리 결과</dt><dd>${esc(c.status)} · ${esc(c.decision)}</dd></div>`:''}</dl><div class="end-actions">${button('사유를 적고 반려','reject-change','',c.status!=='승인 대기'?'disabled':'')}${button('승인','approve-change','primary',c.status!=='승인 대기'||!c.original?'disabled':'')}</div></div></section>`;}
function people(){const rows=state.people.filter(p=>p[0].includes(state.peopleSearch));return title('지원사·이용자','기관에 연결된 활동지원사와 이용자 기본 정보를 관리합니다.',button(icon('4388a')+'지원사 등록','add-person','primary'))+tabs(['활동지원사','이용자'],state.peopleTab,'people-tab')+panel(state.peopleTab==='활동지원사'?'활동지원사 목록':'이용자 목록','동행지원센터 소속 정보만 표시합니다.',state.peopleTab==='활동지원사'?`<div id="people-table">${peopleTable(rows)}</div>`:'<div class="empty">제공된 디자인에 이용자 목록의 상세 데이터가 없습니다.</div>',state.peopleTab==='활동지원사'?`<label class="search-field">${icon('1ece7')}<input aria-label="활동지원사 이름 검색" id="people-search" placeholder="활동지원사 이름 검색" value="${esc(state.peopleSearch)}"></label>`:'');}
function peopleTable(rows){return table(['이름','기관 연결 상태','담당 관리자','등록일','상세'],rows.map(p=>[`<b>${esc(p[0])}</b>`,badge('연결됨'),esc(p[1]),p[2],button('상세 보기','person-detail','text-link',`data-name="${esc(p[0])}"`)]));}
function quality(){return title('기록 품질·운영 상태','수신·권한·센서 품질 문제와 운영 개선 항목을 구분해 확인합니다.')+`<div class="banner green">${icon('d51a6')}<span><b>기록 품질은 부정 위험 점수가 아닙니다.</b>　위치 품질이 부족해도 가능한 시간 중복 점검은 계속 수행합니다.</span></div>`+panel('품질·운영 확인 목록','서버에서 확인 가능한 마지막 보고 상태만 표시합니다.',table(['지원사·대상 방문','문제 유형','마지막 수신','확인 가능한 기기 상태','권장 조치','상세'],qualityRows.map((r,i)=>[`<b>${r[0]}</b>`,badge(r[1]),r[2],r[3],r[4],button(r[5],'quality-detail','text-link',`data-index="${i}"`)])))+`<div class="banner">${icon('d51a6')}현재 휴대폰 상태는 서버가 알 수 없습니다. 마지막으로 수신된 보고 시각과 내용을 기준으로 표시합니다.</div>`;}
function settings(){const values=['관리자 권한','담당자·알림','열람·수정 이력','분석 기준 버전','보관·삭제 정책'];let body;
 if(state.settingTab==='관리자 권한')body=table(['관리자','역할','기록 열람','정정 승인','설정 변경'],[[`<b>정미라</b><br><small>mira@donghaeng.or.kr</small>`,'사무국장','허용','허용','승인된 항목만'],[`<b>김도윤</b><br><small>doyun@donghaeng.or.kr</small>`,'기록 담당자','허용','요청만 가능','불가']]);
 else if(state.settingTab==='열람·수정 이력')body=state.logs.length?table(['시연 동작','내용'],state.logs.map(l=>['현재 세션',esc(l)])):'<div class="empty">현재 시연 세션에서 남긴 처리 이력이 없습니다.</div>';
 else body='<div class="empty">제공된 Figma에 이 탭의 상세 내용이 없습니다. 실제 설정을 변경하지 않는 정적 데모입니다.</div>';
 return title('기관 설정·이력','기관 담당자 권한, 알림, 이력과 적용 중인 분석 기준 정보를 확인합니다.')+`<div class="settings-tabs">${values.map(v=>button(`${v}${icon('b519e',14)}`,'settings-tab',v===state.settingTab?'active':'',`data-value="${v}"`)).join('')}</div>`+panel(state.settingTab,'기관 내 관리자별 업무 권한을 확인합니다.',body,state.settingTab==='관리자 권한'?button('권한 변경 요청','permission-request'):'','settings-panel');}
function step(number,heading,description,content,extra=''){return `<section class="step"><div class="step-number">${number}</div><div class="step-body"><div class="section-title"><div><h2>${heading}</h2>${description?`<p>${description}</p>`:''}</div>${extra}</div>${content}</div></section>`;}
function detail(){const c=state.cases.find(v=>v.id===state.selectedCase)||state.cases[0],original=c.id==='C-0612-104';
 const why=`<p>${c.reason}</p><div class="fact-box"><div><small>확인 필요 시간</small><strong>${c.range}</strong></div><div><small>관측된 값</small><strong>${c.observed}</strong></div><div><small>기록 품질</small><strong>${c.quality}</strong></div></div><div class="banner green">${icon('da4a9')}<span><b>판단의 한계</b><br>${c.limit}</span></div>`;
 const time=(original||c.id==='C-0312-008')?`<div class="timeline"><div class="timeline-inner"><div class="axis">${['09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00'].map(t=>`<span>${t}</span>`).join('')}</div><div class="timeline-row"><b>예정 방문</b><div class="track"><div class="bar planned">예정</div></div></div><div class="timeline-row"><b>실제 기록</b><div class="track"><div class="bar">시작 → 종료</div><div class="bar warning">확인 구간</div></div></div><div class="event-chips">${['09:00 시작','11:00 휴게','11:30 복귀','13:30 종료'].map(v=>`<span><b>${v.split(' ')[0]}</b> ${v.split(' ')[1]} · 자동 기록</span>`).join('')}</div></div></div>`:`<div class="fact-box">확인 구간: <b>${c.range}</b><p>이 사건의 세부 시작·휴게·종료 타임라인은 원본에 제공되지 않았습니다.</p></div>`;
 const history=`<div class="history-item"><div class="history-tag">직접 작성</div><div><b>지원사가 남긴 현장 사유</b><p>${c.id==='C-0312-008'?'정정 요청 사유: 추가 내부 공간 정리 관리 업무 시행':'별도로 작성된 현장 사유가 없습니다.'}</p><small>지원사 작성 · 오늘 13:31</small></div></div><div class="history-item"><div class="history-tag yellow">기관 작성</div><div><b>기관 질문</b><p>${esc(c.question||'아직 등록한 기관 질문이 없습니다.')}</p><small>${c.question?'정미라 · 오늘 15:02 · 발송 완료':'설명 요청에서 질문을 남길 수 있습니다.'}</small></div></div><div class="history-item"><div class="history-tag">직접 작성</div><div><b>지원사 답변</b><p>${esc(c.answer||'아직 제출된 답변이 없습니다.')}</p>${badge(c.answer?'답변 완료':'답변 대기')}</div></div><div class="history-item"><div class="history-tag gray">자동 기록</div><div><b>방문 기록 수신</b><p>시작·휴게·복귀·종료 기록이 기관 서버에 수신되었습니다.</p><small>발생 13:30 · 수신 13:32</small></div></div>`;
 const route=`<section class="panel"><details open><summary class="route-summary"><span><b>${icon('b519e')} 경로 정보 펼쳐보기</b><br><span class="muted">지도는 판단을 돕는 보조 정보입니다.</span></span><b class="route-toggle">접기</b></summary><div class="panel-body">${original?`<div class="route-map" role="img" aria-label="시작과 종료 사이 관측되지 않은 구간을 표시한 시연용 모식도"><div class="road one"></div><div class="road two"></div><div class="map-pin">시작</div><div class="map-gap"></div><div class="map-pin end">종료</div><div class="map-label">측정되지 않은 구간<br><b>경로로 연결하지 않음</b></div></div>`:'<div class="empty">이 사건의 경로 데이터는 제공되지 않았습니다.</div>'}<div class="route-caption">${icon('d51a6')}휴게 중 경로는 표시하지 않습니다. 점선은 이동 경로가 아니라 관측되지 않은 구간의 구분입니다.</div></div></details></section>`;
 return button(icon('9ae76')+'목록으로','back-cases','plain')+title('방문·확인 사건 상세','확인 이유와 근거를 먼저 검토한 뒤 필요한 조치를 선택합니다.')+`<div class="metadata">${[['방문·사건 ID',`${c.visit} / ${c.id}`],['활동지원사·이용자',`${c.worker} · ${c.person}`],['날짜',c.id==='C-0312-008'?'2026년 3월 12일 목요일':original?'2025년 6월 12일':'2026년 3월 11일'],['담당자',c.manager],['방문 상태','종료'],['검토 상태',c.status]].map(([k,v])=>`<div><small>${k}</small><b>${v}</b></div>`).join('')}</div>`+
 step(1,'왜 확인하나요?','시스템이 제시한 확인 후보이며, 관리자의 근거 검토가 필요합니다.',why,badge(c.source))+
 step(2,'방문 시간','예정, 실제 기록, 휴게, 관측 공백을 구분해 표시합니다.',time,'<small>□ 예정　<span style="color:var(--green)">■ 실제 기록</span>　□ 휴게　▱ 관측 공백</small>')+
 step(3,'설명·요청·검토 이력','',history)+route+
 panel('검토 조치','설명과 관련 정정을 확인한 뒤 기관 답변과 검토 결과를 남기세요.',`<form class="panel-body review-form" data-form="review"><div class="two-actions">${button('설명 요청','request-explanation')}${button('관련 정정 요청 확인','related-changes')}</div><label>기관 답변<textarea name="기관 답변" placeholder="확인한 근거와 기관의 답변을 입력하세요." required>${esc(c.agencyAnswer||'')}</textarea></label><label>검토 결과${select('검토 결과',['선택하세요','정상 지원 확인','기록 정정 확인','추가 확인 필요'],c.result||'선택하세요')}</label><div class="banner ${c.answer?'green':'yellow'}">${icon('d51a6')}${c.status==='검토 완료'?'검토 결과가 저장되었습니다.':c.answer?'지원사 답변이 제출되었습니다. 기관 답변과 검토 결과를 작성해주세요.':'지원사 답변이 아직 제출되지 않았습니다.'}</div><div class="end-actions"><button class="primary" ${!c.answer||c.status==='검토 완료'?'disabled':''}>검토 완료</button></div></form>`,'','panel-topline');
}

document.addEventListener('click',event=>{
 const b=event.target.closest('[data-action]');if(!b||b.disabled)return;
 const a=b.dataset.action,v=b.dataset.value;
 if(a==='close-dialog'){dialog.close();return;}
 if(a==='toggle-menu'){document.body.classList.toggle(innerWidth<=760?'mobile-menu-open':'sidebar-closed');return;}
 if(a==='login-help'){info('정적 데모 안내','비밀번호 없이 로그인 버튼을 누르면 화면을 확인할 수 있습니다. 실제 인증·기관 연결·문자 발송·데이터 전송은 실행하지 않습니다.');return;}
 if(a==='refresh'){render();toast('시연 데이터를 새로 표시했습니다.');return;}
 if(a==='account'){modal('정미라 · 동행지원센터',`<p>기관 관리자 정적 데모입니다.</p><p>이 세션의 입력값은 새로고침하면 초기화됩니다.</p><div class="end-actions">${button('로그아웃','logout')}${button('닫기','close-dialog','primary')}</div>`);return;}
 if(a==='logout'){dialog.close();navigate('login');return;}
 if(a==='notifications'){navigate('cases');return;}
 if(a==='case-detail'){state.selectedCase=b.dataset.id;navigate('detail');return;}
 if(a==='back-cases'){navigate('cases');return;}
 if(a==='visit-metric'){state.visitFilters={'방문 상태':v};navigate('visits');return;}
 if(a==='task-metric'){const i=Number(b.dataset.index);if(i===3){state.changeTab='실제 기록 정정';navigate('changes');}else{state.caseFilters={period:'최근 7일',source:'전체',status:['전체','답변 대기','기관 답변 대기'][i]};navigate('cases');}return;}
 if(a==='visit-detail'){
  const found=state.cases.find(c=>c.visit.includes(b.dataset.id));if(found){state.selectedCase=found.id;navigate('detail');}
  else {const row=state.visits.find(v=>v[0]===b.dataset.id);modal('방문 기록 상세',`<p><b>${row[0]} · ${row[1]}</b></p><dl>${[['예정 시간',row[2]],['실제 시간',row[3]],['휴게',row[4]],['방문 상태',row[5]],['검토 상태',row[8]]].map(([k,v])=>`<div class="definition-row"><dt>${k}</dt><dd>${v}</dd></div>`).join('')}</dl><p class="muted">별도 사건 상세 화면은 제공되지 않은 방문입니다.</p>`);}return;
 }
 if(a==='compare'){state.selectedChange=b.dataset.id;state.changeTab='실제 기록 정정';navigate('comparison');setTimeout(()=>document.querySelector('#comparison')?.scrollIntoView({behavior:'smooth',block:'start'}),0);return;}
 if(a==='close-compare'){navigate('changes');return;}
 if(a==='change-tab'){state.changeTab=v;navigate('changes');return;}
 if(a==='people-tab'){state.peopleTab=v;render();return;}
 if(a==='settings-tab'){state.settingTab=v;render();return;}
 if(a==='prev-day'||a==='next-day'){state.scheduleDay+=a==='prev-day'?-1:1;render();return;}
 if(a==='schedule-view'){modal('예정 일정',`<p><b>${esc(b.dataset.name)}</b></p><p>${esc(b.dataset.time)}</p><p class="muted">일정 내용은 Figma 예시 데이터입니다. 편집은 현재 세션에서만 적용됩니다.</p><form data-form="schedule-edit"><label>예정 시간<input name="time" value="${esc(b.dataset.time)}" pattern="[0-2][0-9]:[0-5][0-9]~[0-2][0-9]:[0-5][0-9]" required></label><button class="primary">편집 요청 저장</button></form>`);return;}
 if(a==='add-schedule'){modal('일정 등록 · 시연',`<form data-form="add-schedule"><label>활동지원사${select('worker',['홍길동','박선영','오민수','이정은'],'홍길동')}</label><label>이용자${select('recipient',['김철수','문태희','홍지우','김고구마'],'김철수')}</label><div class="two-actions"><label>시작<input name="start" type="time" value="09:00" min="09:00" max="17:00" required></label><label>종료<input name="end" type="time" value="10:00" min="09:00" max="18:00" required></label></div><p class="muted">실제 기관에 전달되지 않는 시연용 등록입니다.</p><button class="primary">일정 저장</button></form>`);return;}
 if(a==='add-person'){modal('지원사 등록 · 시연',`<form data-form="add-person"><label>이름<input name="name" maxlength="30" required></label><label>담당 관리자${select('manager',['정미라','김도윤'],'정미라')}</label><p class="muted">실제 계정이나 기관 연결을 생성하지 않습니다.</p><button class="primary">시연 목록에 추가</button></form>`);return;}
 if(a==='person-detail'){const p=state.people.find(p=>p[0]===b.dataset.name);info(`${p[0]} · 활동지원사`,`동행지원센터 · 연결됨 / 담당 관리자: ${p[1]} / 등록일: ${p[2]}`);return;}
 if(a==='quality-detail'){const q=qualityRows[Number(b.dataset.index)];if(q[6]){state.selectedCase=q[6];navigate('detail');}else info(q[1],`${q[0]} / ${q[2]} / ${q[3]} / 권장 조치: ${q[4]}. 실제 기기 조회나 알림 전송은 수행하지 않습니다.`);return;}
 if(a==='permission-request'){modal('권한 변경 요청 · 시연',`<form data-form="permission"><label>요청 내용<textarea name="reason" required></textarea></label><p>실제 관리자 권한은 변경되지 않습니다.</p><button class="primary">요청 기록</button></form>`);return;}
 if(a==='approve-change'||a==='reject-change'){
  const c=state.changes.find(v=>v.id===state.selectedChange);
  if(a==='approve-change')modal('정정 요청 승인',`<p>${c.id} · ${c.original} → ${c.requested}</p><p>원본을 보존하고 이 시연 세션의 정정본에 승인 결과를 기록합니다.</p><div class="end-actions">${button('취소','close-dialog')}${button('승인 확정','confirm-approve','primary')}</div>`);
  else modal('반려 사유',`<form data-form="reject"><label>반려 사유<textarea name="reason" required></textarea></label><button class="primary">반려 확정</button></form>`);return;
 }
 if(a==='confirm-approve'){const c=state.changes.find(v=>v.id===state.selectedChange);c.status='승인';c.decision='정정본 승인 (시연)';state.logs.push(`${c.id} 승인 · ${c.original} 원본 보존`);dialog.close();render();toast('정정본에 승인 결과를 기록했습니다. 원본은 유지됩니다.');return;}
 if(a==='request-explanation'){const c=state.cases.find(v=>v.id===state.selectedCase);modal('설명 요청',`<form data-form="explanation"><label>지원사에게 확인할 내용<textarea name="question" required>${esc(c.question)}</textarea></label><p class="muted">정적 데모입니다. 앱이나 문자로 실제 전송하지 않습니다.</p><button class="primary">설명 요청 기록</button></form>`);return;}
 if(a==='related-changes'&&state.selectedCase==='C-0312-008'){state.selectedChange='R-0312-008';navigate('comparison');return;}
 if(a==='related-changes'){state.changeTab='실제 기록 정정';navigate('changes');toast('제공된 정정 요청 목록입니다. 해당 사건과의 연결 여부를 확인해주세요.');return;}
 if(a==='demo-settings'){modal('시연 설정',`<p>관리자 웹은 실제 지원사 앱과 연결되어 있지 않습니다. 검토 완료 흐름을 확인하려면 아래에서 가상 답변을 입력하세요.</p><form data-form="simulate"><label>사건${select('case',state.cases.map(c=>c.id),state.selectedCase)}</label><label>가상 지원사 답변<textarea name="answer" placeholder="시연할 답변을 직접 입력하세요." required></textarea></label><button class="primary">가상 답변 반영</button></form>`);return;}
});
document.addEventListener('submit',event=>{
 const form=event.target.closest('form[data-form]');if(!form)return;event.preventDefault();if(!form.reportValidity())return;
 const data=Object.fromEntries(new FormData(form)),kind=form.dataset.form;
 if(kind==='login'){navigate('overview');return;}
 if(kind==='case-filters'){state.caseFilters={period:data['기간'],source:data['출처'],status:data['검토 상태']};render();return;}
 if(kind==='reject'){if(!data.reason.trim())return;const c=state.changes.find(c=>c.id===state.selectedChange);c.status='반려';c.decision=data.reason.trim();state.logs.push(`${c.id} 반려: ${c.decision}`);dialog.close();render();toast('반려 사유를 시연 기록에 남겼습니다.');return;}
 if(kind==='explanation'){if(!data.question.trim())return;const c=state.cases.find(c=>c.id===state.selectedCase);c.question=data.question.trim();c.status='답변 대기';state.logs.push(`${c.id} 설명 요청 기록`);dialog.close();render();toast('설명 요청을 시연 기록에 남겼습니다. 실제 발송은 하지 않습니다.');return;}
 if(kind==='review'){const c=state.cases.find(c=>c.id===state.selectedCase);if(!c.answer||!data['기관 답변'].trim()||data['검토 결과']==='선택하세요'){toast('지원사 답변·기관 답변·검토 결과가 모두 필요합니다.');return;}c.agencyAnswer=data['기관 답변'].trim();c.result=data['검토 결과'];c.status=c.result==='추가 확인 필요'?'기관 답변 대기':'검토 완료';state.logs.push(`${c.id} ${c.status}: ${c.result}`);render();toast('검토 결과를 현재 세션에 저장했습니다.');return;}
 if(kind==='simulate'){const c=state.cases.find(c=>c.id===data.case);if(!data.answer.trim())return;c.answer=data.answer.trim();c.status='기관 답변 대기';state.selectedCase=c.id;dialog.close();navigate('detail');toast('가상 지원사 답변을 반영했습니다.');return;}
 if(kind==='add-person'){if(!data.name.trim())return;state.people.push([data.name.trim(),data.manager,'2026-03-12']);state.peopleTab='활동지원사';state.logs.push(`시연 지원사 ${data.name.trim()} 등록`);dialog.close();render();toast('시연 목록에 추가했습니다.');return;}
 if(kind==='add-schedule'){const minutes=s=>Number(s.split(':')[0])*60+Number(s.split(':')[1]);if(minutes(data.end)<=minutes(data.start)){toast('종료 시간은 시작 시간보다 늦어야 합니다.');return;}state.addedSchedules.push({day:state.scheduleDay,col:['홍길동','박선영','오민수','이정은'].indexOf(data.worker),top:minutes(data.start)-540,height:minutes(data.end)-minutes(data.start),name:`${data.recipient}님 가정방문`,time:`${data.start}~${data.end}`});state.logs.push('시연 일정 등록');dialog.close();render();toast('일정을 현재 세션에 추가했습니다.');return;}
 if(kind==='schedule-edit'){state.logs.push(`일정 편집 요청: ${data.time}`);dialog.close();toast('시연 편집 요청을 기록했습니다. 원본 일정은 유지됩니다.');return;}
 if(kind==='permission'){if(!data.reason.trim())return;state.logs.push(`권한 변경 요청: ${data.reason.trim()}`);dialog.close();toast('시연 요청을 기록했습니다. 실제 권한은 변경되지 않습니다.');return;}
});
document.addEventListener('change',event=>{const form=event.target.closest('[data-form="visit-filters"]');if(form){state.visitFilters=Object.fromEntries(new FormData(form));render();}});
document.addEventListener('input',event=>{if(event.target.id==='people-search'){state.peopleSearch=event.target.value;document.querySelector('#people-table').innerHTML=peopleTable(state.people.filter(p=>p[0].includes(state.peopleSearch)));}});
document.addEventListener('toggle',event=>{if(event.target.matches('details')){event.target.querySelector('.route-toggle').textContent=event.target.open?'접기':'펼치기';}},true);
window.addEventListener('hashchange',render);
render();
