# 동행이음 — 방문 기록 및 이상 징후 검토 시제품

활동지원사 Flutter 앱, 기관 관리자 웹, Python API, Supabase DB 설계와 검증 코드를 포함합니다. **원격 DB 구축 완료(2026-11-21). 실제 SMS 발송 설정은 보류 중입니다.** 실행 안내와 시험 범위를 먼저 확인하세요.

## 구성

- `apps/mobile`: Android/iOS Flutter 앱. 시작·휴게·복귀·종료, 위치 동의, SQLite 오프라인 기록, 재전송, 현장 설명·정정 요청.
- `backend`: FastAPI API와 Jinja2 관리자 웹. SMS 연동, 기관 범위 조회, 일정·배정, 확인 요청·답변·승인.
- `ai`: GPS 품질 점검, 설명 가능한 시험 규칙, 과거 기록 시간 IsolationForest 후보 분석.
- `db/schema.sql`: 빈 Supabase 프로젝트용 초기 테이블·RLS·RPC. 운영 데이터 삭제 명령 없음.
- `db/operator_setup.sql`: 운영자 전용 기관·최초 관리자 등록 함수.
- `tests`: Python, PostgreSQL(PGlite), 브라우저 검증.
- `docs/specs`: 구현의 기준이 된 기획·명세 원문.

## 시작

PowerShell에서 `C:\Project\Dolbom_ieum`을 엽니다.

```powershell
uv sync --locked
uv run uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

관리자 웹: http://127.0.0.1:8000 / API 명세: http://127.0.0.1:8000/docs

실물 휴대폰 연결, DB 적용, 문자 인증 설정은 **[실행 및 DB 적용 안내](docs/실행_DB_안내.txt)**를 따라 진행합니다. 로그인 화면이 열린다는 사실과 Supabase 통합 동작 검증은 다릅니다.

## 구현·검증 범위

**[구현 상태 및 남은 검증](docs/구현상태_검증.txt)**에서 코드 구현, 시험 통과, 외부 설정 대기를 구분했습니다. **[기능·데이터 흐름](docs/기능_데이터흐름.txt)**은 디자이너와 개발자가 같이 읽을 수 있는 현재 구현 설명입니다.

시험용 APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk` (개발 설정용, 배포용 아님).

AI는 확인 후보를 제공하며 부정수급·동행·실제 돌봄을 확정하지 않습니다. 위치 수집 안정성과 배터리 절감률은 실물 기기 검증 전입니다.
