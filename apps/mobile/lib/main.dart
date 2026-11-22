import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty || key.isEmpty || Api.base.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '개발 설정이 필요합니다.\n실행 안내의 dart-define-from-file 설정을 확인해주세요.',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(
    url: url,
    publishableKey: key,
    authOptions: FlutterAuthClientOptions(localStorage: SecureSession()),
  );
  runApp(const DolbomApp());
}

class DolbomApp extends StatelessWidget {
  const DolbomApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '동행이음',
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff4ca771)),
      scaffoldBackgroundColor: const Color(0xfff7f9f7),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 19, height: 1.5),
        bodyMedium: TextStyle(fontSize: 18, height: 1.45),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xffffd34e),
          foregroundColor: const Color(0xff182b22),
          minimumSize: const Size.fromHeight(58),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? listener;
  @override
  void initState() {
    super.initState();
    listener = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    listener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Supabase.instance.client.auth.currentSession == null
      ? const PhoneLogin()
      : const WorkerHome();
}

class PhoneLogin extends StatefulWidget {
  const PhoneLogin({super.key});
  @override
  State<PhoneLogin> createState() => _PhoneLoginState();
}

class _PhoneLoginState extends State<PhoneLogin> {
  final phone = TextEditingController(), code = TextEditingController();
  bool sent = false, busy = false;
  String? error;
  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (sent) {
        await auth.verifyOTP(
          phone: phone.text.trim(),
          token: code.text.trim(),
          type: OtpType.sms,
        );
      } else {
        await auth.signInWithOtp(phone: phone.text.trim());
        if (mounted) setState(() => sent = true);
      }
    } catch (e) {
      if (mounted) setState(() => error = '인증하지 못했어요. $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('동행이음')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          '돌봄의 시작과 끝을\n간편하게 기록해요',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: phone,
          enabled: !sent,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '휴대전화 번호',
            helperText: '국가번호 포함: +821012345678',
          ),
        ),
        if (sent) ...[
          const SizedBox(height: 18),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '문자로 받은 인증번호'),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? '확인 중…'
                : sent
                ? '확인하고 시작'
                : '인증번호 받기',
          ),
        ),
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: Text(error!)),
        const SizedBox(height: 24),
        const Text(
          '시험용 서비스입니다. 문자 발송 제공업체 설정 전에는 인증 문자를 받을 수 없습니다.',
          style: TextStyle(fontSize: 15, color: Colors.black54),
        ),
      ],
    ),
  );
}

class WorkerHome extends StatefulWidget {
  const WorkerHome({super.key});
  @override
  State<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<WorkerHome> {
  final store = VisitStore();
  bool ready = false, busy = false;
  int tab = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    store.addListener(changed);
    store
        .open(Supabase.instance.client.auth.currentUser!.id)
        .then((_) {
          if (mounted) setState(() => ready = true);
        })
        .catchError((Object e) {
          if (mounted) setState(() => error = '휴대폰 저장소를 열지 못했어요. $e');
        });
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(changed);
    store.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> ask(
    String title, {
    String initial = '',
    String hint = '짧게 입력해주세요',
  }) async {
    final text = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, text.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    text.dispose();
    return value;
  }

  Future<DateTime?> pickMoment(String title, DateTime initial) async {
    final day = await showDatePicker(
      context: context,
      helpText: title,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      cancelText: '취소',
      confirmText: '다음',
    );
    if (day == null || !mounted) return null;
    final clock = await showTimePicker(
      context: context,
      helpText: title,
      initialTime: TimeOfDay.fromDateTime(initial),
      cancelText: '취소',
      confirmText: '확인',
    );
    return clock == null
        ? null
        : DateTime(day.year, day.month, day.day, clock.hour, clock.minute);
  }

  Future<void> requestSchedule(Map<String, dynamic> s) async {
    final start = await pickMoment(
      '변경할 시작 시각',
      DateTime.parse(s['starts_at']).toLocal(),
    );
    if (start == null) return;
    final end = await pickMoment(
      '변경할 종료 시각',
      DateTime.parse(s['ends_at']).toLocal(),
    );
    if (end == null) return;
    if (!end.isAfter(start)) throw Exception('종료 시각은 시작보다 늦어야 해요.');
    final reason = await ask('일정 변경이 필요한 이유');
    if (reason == null || reason.isEmpty) return;
    await store.queue('schedule_request', {
      'id': ids.v4(),
      'schedule_id': s['id'],
      'reason': reason,
      'proposed': {
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': end.toUtc().toIso8601String(),
      },
    });
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('계속 기록'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('종료'),
            ),
          ],
        ),
      ) ??
      false;
  Widget card(List<Widget> children) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget button(String title, VoidCallback action, {bool primary = true}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: primary
            ? FilledButton(onPressed: busy ? null : action, child: Text(title))
            : OutlinedButton(
                onPressed: busy ? null : action,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(title, style: const TextStyle(fontSize: 18)),
              ),
      );
  String recipientName(dynamic id) {
    for (final r in store.bootstrap['recipients'] ?? []) {
      if (r['id'] == id) return r['name'];
    }
    return '등록 이용자';
  }

  String date(dynamic s) =>
      s == null ? '—' : DateTime.parse(s).toLocal().toString().substring(0, 16);
  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('동행이음')),
        body: Center(
          child: error != null
              ? Text(error!)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final profile = store.bootstrap['profile'],
        membership = store.bootstrap['membership'];
    List<Widget> body = [];
    if (profile == null || profile['consent_at'] == null) {
      body = [
        card([
          const Text(
            '기록 안내',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Text(
            '방문 시작 후 위치·시간을 기록하고 기관 담당자가 확인합니다. 휴게·종료하면 위치 기록을 중단합니다. 위치를 허용하지 않아도 시간은 기록할 수 있어요.\n\n현재 동의한 테스트 참여자용 시제품입니다. 실제 이용자 정보를 입력하지 마세요.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('방문 중 위치 기록에 동의'),
            value: store.consentLocation,
            onChanged: (v) => run(() => store.setLocationConsent(v)),
          ),
          button(
            '안내 확인하고 이름 등록',
            () => run(() async {
              final name = await ask('이름을 입력해주세요');
              if (name == null || name.isEmpty) return;
              await store.api.command('profile', {
                'name': name,
                'consent': true,
              });
              await store.refresh();
            }),
          ),
        ]),
      ];
    } else if (membership == null) {
      body = [
        card([
          const Text(
            '기관 등록을 기다리고 있어요',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const Text('아래 연결 코드를 기관 담당자에게 보여주세요.'),
          SelectableText(
            profile['link_code'],
            style: const TextStyle(fontSize: 18),
          ),
          button('기관 연결 확인', () => run(store.refresh)),
        ]),
        for (final inv in store.bootstrap['invitations'] ?? [])
          card([
            Text(
              '기관: ${(store.bootstrap['agencies'] as List).firstWhere((a) => a['id'] == inv['agency_id'], orElse: () => {'name': '기관 확인 필요'})['name']}',
            ),
            button(
              '이 기관에 연결',
              () => run(() async {
                await store.api.command('accept_invitation', {'id': inv['id']});
                await store.refresh();
              }),
            ),
          ]),
      ];
    } else if (membership['role'] != 'worker') {
      body = [
        card([const Text('기관 관리자는 웹에서 이용해주세요.')]),
      ];
    } else if (tab == 0) {
      if (store.active != null) body.add(activeCard(store.active!));
      body.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '배정된 방문',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      );
      final schedules = (store.bootstrap['schedules'] as List? ?? []).where(
        (s) =>
            DateTime.parse(s['starts_at'])
                .toLocal()
                .toString()
                .substring(0, 10) ==
            DateTime.now().toString().substring(0, 10),
      );
      if (schedules.isEmpty) body.add(card([const Text('오늘 배정된 방문이 없어요.')]));
      for (final s in schedules) {
        final existing = store.visits
            .where((v) => v['schedule_id'] == s['id'])
            .toList();
        body.add(
          card([
            Text(
              '${recipientName(s['recipient_id'])} 님',
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),
            Text('${date(s['starts_at'])}\n~ ${date(s['ends_at'])}'),
            Text('휴게 예정 ${s['break_minutes']}분 · 실제 쉬기 버튼으로 기록'),
            if ((s['memo'] ?? '').isNotEmpty) Text(s['memo']),
            button(
              existing.isEmpty ? '방문 상세·시작' : '방문 기록 보기',
              () => existing.isEmpty
                  ? showSchedule(s)
                  : showRecord(existing.first),
            ),
          ]),
        );
      }
      body.add(button('임시 방문 등록', temporary, primary: false));
    } else if (tab == 1) {
      body = [
        for (final v in store.visits.reversed)
          card([
            Text(
              '${v['recipient_name']} 님',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              '${date(v['created_at'])} · ${v['state'] == 'ended' ? '종료' : '진행'}',
            ),
            Text(v['dirty'] == true ? '휴대폰 저장 · 전송 대기' : '서버 전달 완료'),
            button('기록·정정 요청', () => showRecord(v), primary: false),
          ]),
        if (store.visits.isEmpty) card([const Text('아직 기록이 없어요.')]),
      ];
    } else if (tab == 2) {
      final cases = store.bootstrap['cases'] as List? ?? [];
      body = [
        for (final c in cases)
          card([
            const Text(
              '기관에서 확인을 요청했어요',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            Text(c['question'] ?? '기관 검토 중'),
            Text('내 답변: ${c['worker_answer'] ?? '아직 제출하지 않았어요'}'),
            if (c['status'] == 'worker_pending')
              button(
                '짧게 답변하기',
                () => run(() async {
                  final answer = await ask(
                    '어떤 지원을 하셨나요?',
                    hint: '예: 이용자와 병원에 다녀왔어요',
                  );
                  if (answer == null || answer.isEmpty) return;
                  await store.queue('answer', {
                    'id': c['id'],
                    'version': c['version'],
                    'body': answer,
                  });
                  await store.refresh();
                }),
              ),
          ]),
        if (cases.isEmpty) card([const Text('답변할 요청이 없어요.')]),
        for (final q in store.bootstrap['schedule_requests'] ?? [])
          card([
            Text('일정 변경 요청: ${q['status']}'),
            Text(q['reason']),
            if (q['decision_reason'] != null) Text(q['decision_reason']),
          ]),
        for (final q in store.bootstrap['corrections'] ?? [])
          card([
            Text('변경 요청: ${q['status']}'),
            Text(q['reason']),
            if (q['decision_reason'] != null) Text(q['decision_reason']),
          ]),
      ];
    } else {
      body = [
        card([
          Text(
            profile['name'],
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          Text(
            '기관: ${(store.bootstrap['agencies'] as List?)?.firstOrNull?['name'] ?? '연결 대기'}',
          ),
          Text('위치: ${store.locationState}'),
          const Text('움직임 센서: 실기기 검증 전 · 판단하지 않음'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('방문 중 위치 기록 동의'),
            value: store.consentLocation,
            onChanged: (v) => run(() => store.setLocationConsent(v)),
          ),
          button('저장한 기록 다시 전송', () => run(store.refresh)),
          button(
            '로그아웃',
            () => run(() async {
              if (store.active != null || await store.pending() > 0) {
                throw Exception('진행 방문을 종료하고 미전송 기록을 먼저 보내주세요.');
              }
              await Supabase.instance.client.auth.signOut();
            }),
            primary: false,
          ),
        ]),
      ];
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('동행이음'),
        actions: [
          IconButton(
            onPressed: busy ? null : () => run(store.refresh),
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null)
              card([
                Text(error!, style: const TextStyle(color: Color(0xff8b3c10))),
              ]),
            if (store.error != null)
              card([Text(store.error!, style: const TextStyle(fontSize: 16))]),
            ...body,
          ],
        ),
      ),
      bottomNavigationBar: membership == null
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.today), label: '오늘 방문'),
                NavigationDestination(icon: Icon(Icons.history), label: '기록'),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: '요청',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: '내 정보',
                ),
              ],
            ),
    );
  }

  Widget activeCard(Map<String, dynamic> v) => card([
    Text(
      '${v['recipient_name']} 님',
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    ),
    Text(
      v['state'] == 'paused' ? '쉬는 중' : '돌봄 중',
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    ),
    FutureBuilder(
      future: store.events(v['id']),
      builder: (c, s) {
        if (!s.hasData) return const Text('시간 확인 중');
        final t = durations(s.data!);
        return Text('돌봄 ${t['care']! ~/ 60}분 · 휴게 ${t['pause']! ~/ 60}분');
      },
    ),
    Text(store.locationState),
    Text(v['dirty'] == true ? '휴대폰 저장 · 전송 대기' : '서버 전달 완료'),
    button(
      v['state'] == 'paused' ? '다시 시작' : '쉬기 시작',
      () => run(
        () => store.event(v['id'], v['state'] == 'paused' ? 'resume' : 'pause'),
      ),
    ),
    button('현장 사유 남기기', () => note(v), primary: false),
    const Divider(height: 32),
    button(
      '방문 종료',
      () => run(() async {
        if (await confirm(
          '방문을 종료할까요?',
          '${v['recipient_name']} 님 방문의 위치 기록도 중단합니다.',
        )) {
          await store.event(v['id'], 'end');
          if (mounted) {
            showRecord(store.visits.firstWhere((x) => x['id'] == v['id']));
          }
        }
      }),
      primary: false,
    ),
    if (v['state'] == 'active' && store.gps == null)
      button(
        '위치 기록 다시 시작',
        () => run(() => store.startTracking(v['id'])),
        primary: false,
      ),
  ]);
  void showSchedule(Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${recipientName(s['recipient_id'])} 님',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('${date(s['starts_at'])} ~ ${date(s['ends_at'])}'),
              const Text('시작을 누르면 시간을 기록합니다. 위치 권한이 없어도 시작할 수 있어요.'),
              button('서비스 시작', () {
                Navigator.pop(c);
                run(() async {
                  final recipient = (store.bootstrap['recipients'] as List)
                      .firstWhere((r) => r['id'] == s['recipient_id']);
                  await store.start(
                    Map<String, dynamic>.from(recipient),
                    schedule: s,
                  );
                });
              }),
              button('일정 변경 요청', () {
                Navigator.pop(c);
                run(() => requestSchedule(s));
              }, primary: false),
            ],
          ),
        ),
      ),
    );
  }

  void temporary() {
    final recipients = store.bootstrap['recipients'] as List? ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              '배정 이용자 선택',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            if (recipients.isEmpty) const Text('내려받은 배정 이용자가 없어요. 기관에 문의해주세요.'),
            for (final r in recipients)
              button('${r['name']} 님', () {
                Navigator.pop(c);
                run(() async {
                  final reason = await ask('임시 방문 사유');
                  if (reason == null || reason.isEmpty) return;
                  await store.start(
                    Map<String, dynamic>.from(r),
                    reason: reason,
                  );
                });
              }),
          ],
        ),
      ),
    );
  }

  void note(Map<String, dynamic> v) => run(() async {
    final reason = await ask(
      '현장에서 어떤 지원을 하셨나요?',
      hint: '병원 동행 / 장보기 / 가사 지원 / 기타',
    );
    if (reason != null && reason.isNotEmpty) {
      await store.queue('note', {
        'id': ids.v4(),
        'visit_id': v['id'],
        'body': reason,
      });
    }
  });
  Future<void> showRecord(Map<String, dynamic> v) async {
    final events = await store.events(v['id']);
    if (!mounted) return;
    final t = durations(events);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${v['recipient_name']} 님 방문 기록',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(
              '전체 ${t['total']! ~/ 60}분\n돌봄 ${t['care']! ~/ 60}분 / 휴게 ${t['pause']! ~/ 60}분',
            ),
            Text(
              v['dirty'] == true ? '휴대폰에 저장했어요. 연결되면 자동으로 보낼게요.' : '기관에 전달했어요.',
            ),
            for (final e in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${{'start': '시작', 'pause': '휴게', 'resume': '복귀', 'end': '종료'}[e['kind']]} · ${date(e['occurred_at'])}',
                ),
                subtitle: const Text('시간 정정 요청'),
                onTap: () {
                  Navigator.pop(c);
                  run(() async {
                    final parsed = await pickMoment(
                      '변경할 시각',
                      DateTime.parse(e['occurred_at']).toLocal(),
                    );
                    if (parsed == null) return;
                    final reason = await ask('정정이 필요한 이유');
                    if (reason == null || reason.isEmpty) return;
                    await store.queue('correction', {
                      'id': ids.v4(),
                      'visit_id': v['id'],
                      'target': 'event',
                      'event_id': e['id'],
                      'proposed': {
                        'occurred_at': parsed.toUtc().toIso8601String(),
                      },
                      'reason': reason,
                    });
                  });
                },
              ),
            button('현장 사유 추가', () {
              Navigator.pop(c);
              note(v);
            }, primary: false),
          ],
        ),
      ),
    );
  }
}
