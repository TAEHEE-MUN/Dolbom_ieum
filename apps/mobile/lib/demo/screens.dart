import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';
import 'model.dart';

class DemoScreenBody extends StatefulWidget {
  const DemoScreenBody({required this.model, super.key});
  final DemoModel model;
  @override
  State<DemoScreenBody> createState() => _DemoScreenBodyState();
}

class _DemoScreenBodyState extends State<DemoScreenBody> {
  DemoModel get m => widget.model;
  String get frame => frameIds[m.screen]!;
  final phone = TextEditingController(), password = TextEditingController();
  final memo = TextEditingController();
  final reason = TextEditingController(text: '추가 내부 공간 정리 관리 업무 시행');
  final startHour = TextEditingController(text: '09'),
      startMinute = TextEditingController(text: '00');
  final endHour = TextEditingController(text: '13'),
      endMinute = TextEditingController(text: '20');
  late final time = TextEditingController(
    text: m.screen == DemoScreen.correction ? '종료 13:20' : '09:30 ~ 14:00',
  );
  String activity = '병원 동행', answer = '장보기를 원해 하나로마트에 함께 갔습니다.';
  String? error;
  @override
  void dispose() {
    for (final c in [
      phone,
      password,
      memo,
      reason,
      time,
      startHour,
      startMinute,
      endHour,
      endMinute,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget icon(String name, [double size = 22]) =>
      FigmaIcon(frame, name, size: size);
  Widget col(List<Widget> children, {bool center = false}) => Column(
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.stretch,
    children: children,
  );
  Widget userName() => Text.rich(
    const TextSpan(
      children: [
        TextSpan(
          text: '홍길동 ',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        TextSpan(
          text: '사용자님',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    ),
    style: const TextStyle(height: 1.4, color: AppColors.ink),
  );
  Widget link(
    String label,
    VoidCallback onTap, {
    Widget? trailing,
    Color color = AppColors.deep,
  }) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: txt(label, weight: FontWeight.w800, color: color),
          ),
          ?trailing,
        ],
      ),
    ),
  );
  Widget pair(String label, String value, {String? subtitle}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 4, child: txt(label, color: AppColors.muted)),
      Expanded(
        flex: 7,
        child: col([
          txt(value, size: 18, weight: FontWeight.w700),
          if (subtitle != null) txt(subtitle, size: 14, color: AppColors.muted),
        ]),
      ),
    ],
  );
  Future<void> help(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => switch (m.screen) {
    DemoScreen.login || DemoScreen.signup => auth(),
    DemoScreen.home => home(),
    DemoScreen.scheduled => scheduled(),
    DemoScreen.active => active(),
    DemoScreen.rest => rest(),
    DemoScreen.note => note(),
    DemoScreen.endConfirm => endConfirm(),
    DemoScreen.ended => ended(),
    DemoScreen.scheduleChange || DemoScreen.correction => change(),
    DemoScreen.waiting => waiting(),
    DemoScreen.records => records(),
    DemoScreen.requests || DemoScreen.sentRequests => requests(),
    DemoScreen.answer => answerForm(),
    DemoScreen.answered => answered(),
    DemoScreen.profile => profile(),
    DemoScreen.recordDetail ||
    DemoScreen.recordWithoutQuestion => recordDetail(),
  };

  Widget auth() {
    final signup = m.screen == DemoScreen.signup;
    return col([
      Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: icon('imgIcon', 30)),
          ),
          const SizedBox(width: 12),
          txt('돌봄이음', size: 32, weight: FontWeight.w800, color: Colors.black),
        ],
      ),
      gap(24),
      Text.rich(
        const TextSpan(
          children: [
            TextSpan(text: '방문 시간은 쉽고 정확하게,\n'),
            TextSpan(
              text: '돌봄',
              style: TextStyle(color: AppColors.green),
            ),
            TextSpan(text: '에 더 집중하세요.'),
          ],
        ),
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          height: 1.55,
          color: Colors.black,
        ),
      ),
      gap(24),
      tabSwitch(
        ['로그인', '회원가입'],
        signup ? 1 : 0,
        (i) => m.go(i == 0 ? DemoScreen.login : DemoScreen.signup, root: true),
      ),
      gap(24),
      AppCard(
        shadow: true,
        child: col([
          AppField(
            label: '휴대폰 번호',
            controller: phone,
            hint: '010-0000-0000',
            keyboard: TextInputType.phone,
          ),
          gap(27),
          AppField(
            label: '비밀번호',
            controller: password,
            hint: '비밀번호 입력',
            obscure: true,
          ),
          gap(27),
          AppButton(
            signup ? '가입 안내 계속하기' : '로그인',
            () => signup
                ? help(
                    '회원가입 안내',
                    '정적 데모입니다. 실제 계정은 생성하지 않아요. 로그인 화면에서 오늘 방문을 확인할 수 있어요.',
                  )
                : m.go(DemoScreen.home, root: true),
          ),
        ]),
      ),
      gap(24),
      TextButton(
        onPressed: () => help(
          '로그인 도움',
          '이 화면은 정적 시연용입니다. 번호나 비밀번호 없이 로그인 버튼을 눌러 화면을 둘러보세요. 실제 문자 발송·로그인·위치 수집은 실행하지 않아요.',
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon('imgIcon1'),
            const SizedBox(width: 9),
            Flexible(
              child: txt(
                '로그인이 어려우신가요? 도움받기',
                size: 14,
                weight: FontWeight.w800,
                color: AppColors.deep,
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget tabSwitch(
    List<String> labels,
    int selected,
    ValueChanged<int> onChanged,
  ) => Row(
    children: List.generate(
      labels.length,
      (i) => Expanded(
        child: Semantics(
          selected: selected == i,
          child: InkWell(
            onTap: () => onChanged(i),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: i == selected ? AppColors.ink : AppColors.line,
                    width: i == selected ? 3 : 1,
                  ),
                ),
              ),
              child: txt(
                labels[i],
                size: labels.length == 2 && labels[0] == '로그인' ? 18 : 15,
                weight: FontWeight.w700,
                color: i == selected ? AppColors.ink : AppColors.muted,
                align: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget home() => col([
    Row(
      children: [
        Expanded(
          child: col([
            txt(
              '동행지원센터',
              size: 15,
              weight: FontWeight.w800,
              color: AppColors.deep,
            ),
            userName(),
            txt('2026년 3월 12일 목요일', size: 15, color: AppColors.muted),
          ]),
        ),
        const Mascot(),
      ],
    ),
    gap(20),
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 8,
      children: [
        txt('오늘 일정', size: 21, weight: FontWeight.w800),
        txt('1건', size: 15, color: AppColors.muted),
      ],
    ),
    gap(20),
    AppCard(
      shadow: true,
      child: col([
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            StatusPill(m.visitState),
            txt('오전 방문', size: 14, color: AppColors.muted),
          ],
        ),
        gap(17),
        txt('김철수님 가정방문', size: 27, weight: FontWeight.w800),
        gap(12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            icon('imgIcon'),
            txt('09:00 ~ 13:30', size: 18, weight: FontWeight.w700),
            txt('4시간 30분', size: 14, color: AppColors.muted),
          ],
        ),
        gap(18),
        const Divider(),
        link(
          '방문 상세 보기',
          m.openVisit,
          trailing: icon('imgIcon1'),
          color: AppColors.green,
        ),
      ]),
    ),
    gap(20),
    InkWell(
      onTap: () => m.go(DemoScreen.requests, root: true),
      child: AppNotice(
        icon: icon('imgIcon2'),
        child: Row(
          children: [
            Expanded(
              child: col([
                txt(
                  m.answerSent ? '기관에서 답변을 확인할 예정이에요' : '기관에서 확인을 요청했어요',
                  weight: FontWeight.w700,
                ),
                txt(
                  m.answerSent ? '답변을 보냈어요' : '답변이 필요한 요청 1건',
                  size: 13,
                  color: AppColors.muted,
                ),
              ]),
            ),
            icon('imgIcon1'),
          ],
        ),
      ),
    ),
  ]);

  Widget scheduled() => col([
    const Align(alignment: Alignment.centerLeft, child: StatusPill('예정 방문')),
    gap(18),
    userName(),
    gap(8),
    txt('오늘 오전 방문 일정이에요.', size: 15, color: AppColors.muted),
    gap(24),
    AppCard(
      border: AppColors.mintBorder,
      child: col([
        pair('활동 시간', '09:00 ~ 13:30', subtitle: '전체 4시간 30분'),
        gap(18),
        const Divider(color: AppColors.mintBorder),
        gap(18),
        pair('예정 휴게시간', '11:00 ~ 11:30'),
        gap(18),
        const Divider(color: AppColors.mintBorder),
        gap(18),
        pair('활동 장소', '서울시 강서구 화곡동'),
        gap(18),
        const Divider(color: AppColors.mintBorder),
        gap(18),
        pair('기관 메모', '외출 시 보행 보조기 확인'),
      ]),
    ),
    gap(18),
    AppNotice(
      icon: icon('imgIcon1'),
      child: col([
        txt('위치 기록 가능', weight: FontWeight.w800),
        txt('서비스 중에만 허용된 위치를 기록해요.'),
      ]),
    ),
    gap(46),
    txt('김철수님의 댁에 도착하셨나요?', size: 18, weight: FontWeight.w700),
    gap(10),
    AppButton('서비스 시작하기', m.start),
    gap(38),
    Row(
      children: [
        Expanded(
          child: AppButton(
            '방문일정 변경하기',
            () => m.go(DemoScreen.scheduleChange),
            primary: false,
            small: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppButton(
            '기관에 문의하기',
            () =>
                help('동행지원센터', '실제 기관 연락처가 등록되면 전화로 연결할 수 있어요. 현재는 정적 데모입니다.'),
            primary: false,
            small: true,
            icon: icon('imgIcon2'),
          ),
        ),
      ],
    ),
  ]);

  Widget active() => col([
    Row(
      children: [
        Expanded(
          child: col([
            userName(),
            gap(4),
            Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: AppColors.deep,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.mintBorder, width: 2),
                  ),
                ),
                txt(
                  '돌봄 중',
                  size: 18,
                  weight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ],
            ),
          ]),
        ),
        icon('imgIcon1', 36),
      ],
    ),
    gap(18),
    AppCard(
      color: AppColors.pale,
      border: AppColors.pale,
      radius: 20,
      child: col([
        Row(
          children: [
            Expanded(
              child: col([
                txt('시작 시각', size: 14, color: AppColors.muted),
                txt('09:00', size: 20, weight: FontWeight.w700),
              ]),
            ),
            Expanded(
              child: col([
                txt('휴게 누적시간', size: 14, color: AppColors.muted),
                txt(
                  m.resumed ? '30분' : '0분',
                  size: 20,
                  weight: FontWeight.w700,
                ),
              ]),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: col([
                txt('돌봄 누적시간', size: 14, color: AppColors.muted),
                txt(
                  '2시간 32분',
                  size: 24,
                  weight: FontWeight.w700,
                  color: AppColors.deep,
                ),
              ]),
            ),
            const Mascot(active: true),
          ],
        ),
      ]),
    ),
    gap(18),
    AppCard(
      border: AppColors.mintBorder,
      padding: 0,
      radius: 14,
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 13,
                  ),
                  child: col([
                    icon(['imgIcon2', 'imgIcon3', 'imgIcon4'][i]),
                    gap(4),
                    txt(
                      ['기록 상태', '전송 상태', '위치 상태'][i],
                      size: 12,
                      color: AppColors.muted,
                      align: TextAlign.center,
                    ),
                    txt(
                      ['휴대폰에 저장', '기관에 전달 완료', '기록 중'][i],
                      size: 12,
                      weight: FontWeight.w700,
                      align: TextAlign.center,
                    ),
                  ], center: true),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    gap(18),
    txt(
      '움직임 시험 기능 · 사용 가능 여부를 확인하는 중',
      size: 12,
      color: AppColors.muted,
      align: TextAlign.center,
    ),
    gap(18),
    AppButton('쉬기 시작', m.pause, icon: icon('imgIcon5')),
    gap(18),
    AppButton('현장 사유 남기기', () => m.go(DemoScreen.note), primary: false),
    gap(40),
    const Divider(),
    gap(26),
    txt('서비스를 모두 마쳤을 때만 눌러주세요.', size: 14, color: AppColors.muted),
    gap(10),
    AppButton('방문 종료', () => m.go(DemoScreen.endConfirm), primary: false),
  ]);

  Widget roundSymbol(Widget child, {bool pale = false, double size = 78}) =>
      Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pale ? AppColors.pale : AppColors.green,
          ),
          child: Center(child: child),
        ),
      );
  Widget rest() => col([
    Center(child: userName()),
    gap(32),
    roundSymbol(icon('imgIcon1', 36)),
    gap(18),
    txt('휴게시간', size: 30, weight: FontWeight.w800, align: TextAlign.center),
    txt(
      '휴게 시작 11:00',
      size: 15,
      color: AppColors.muted,
      align: TextAlign.center,
    ),
    gap(16),
    txt('30분', size: 42, weight: FontWeight.w800, align: TextAlign.center),
    gap(32),
    AppNotice(
      icon: icon('imgIcon2'),
      child: col([
        txt('지금은 위치를 기록하지 않아요', weight: FontWeight.w800),
        txt('‘다시 시작’을 누르면 시간과 허용된 위치 기록을 다시 시작해요.'),
      ]),
    ),
    gap(18),
    AppButton('다시 시작', m.resume, icon: icon('imgIcon3')),
    gap(18),
    AppButton('방문 종료', () => m.go(DemoScreen.endConfirm), primary: false),
  ]);

  Widget note() => col([
    heading('어떤 활동을 하셨나요?'),
    gap(24),
    Row(
      children: [
        icon('imgIcon1'),
        const SizedBox(width: 8),
        txt('09:00 ~ 현재', size: 18, weight: FontWeight.w700),
      ],
    ),
    gap(24),
    for (var row = 0; row < 2; row++) ...[
      Row(
        children: List.generate(2, (i) {
          final value = ['병원 동행', '장보기 동행', '가사 지원', '기타'][row * 2 + i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 1 ? 5 : 0,
                right: i == 0 ? 5 : 0,
              ),
              child: Semantics(
                selected: activity == value,
                child: OutlinedButton(
                  onPressed: () => setState(() => activity = value),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 68),
                    padding: const EdgeInsets.all(10),
                    backgroundColor: activity == value
                        ? AppColors.pale
                        : Colors.white,
                    side: BorderSide(
                      color: activity == value
                          ? AppColors.mintBorder
                          : AppColors.line,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: txt(
                    value,
                    weight: FontWeight.w700,
                    color: activity == value ? AppColors.deep : AppColors.ink,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
      gap(10),
    ],
    AppField(
      label: '짧은 메모  선택사항',
      controller: memo,
      hint: '필요한 내용만 간단히 적어주세요.',
      lines: 3,
    ),
    gap(12),
    AppButton(
      '현장 사유 저장',
      () => m.saveNote(
        '$activity${memo.text.trim().isEmpty ? '' : ' · ${memo.text.trim()}'}',
      ),
      icon: icon('imgIcon2'),
    ),
  ]);

  Widget endConfirm() => col([
    gap(18),
    roundSymbol(icon('imgIcon1', 38), pale: true),
    gap(18),
    txt(
      '활동을 종료할까요?',
      size: 28,
      weight: FontWeight.w800,
      align: TextAlign.center,
    ),
    gap(18),
    txt(
      '종료하면 시간과 위치 기록이 멈춰요.\n종료 후에는 기록 정정을 요청할 수 있어요.',
      size: 17,
      color: AppColors.muted,
      align: TextAlign.center,
    ),
    gap(32),
    AppCard(
      color: AppColors.pale,
      border: AppColors.pale,
      radius: 14,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          txt(
            '예상 종료 시각',
            size: 18,
            weight: FontWeight.w700,
            color: AppColors.deep,
          ),
          txt(
            '13:30',
            size: 18,
            weight: FontWeight.w700,
            color: AppColors.deep,
          ),
        ],
      ),
    ),
    gap(32),
    AppButton('계속 활동하기', m.back, primary: false),
    gap(18),
    AppButton('방문 종료', m.end),
  ]);

  Widget ended() => col([
    gap(18),
    roundSymbol(icon('imgIcon1', 38)),
    gap(18),
    txt(
      '방문을 종료했어요',
      size: 28,
      weight: FontWeight.w800,
      align: TextAlign.center,
    ),
    gap(18),
    txt('활동사님의 기록을 안전하게 저장하고\n기관에 보냈어요.', align: TextAlign.center),
    gap(22),
    AppCard(
      border: AppColors.mintBorder,
      child: col([
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            txt('전체 방문 시간', size: 18, color: AppColors.muted),
            txt('4시간 30분', size: 18, weight: FontWeight.w700),
          ],
        ),
        txt('09:00 ~ 13:30', size: 14, color: AppColors.muted),
        gap(20),
        const Divider(),
        gap(16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            txt('돌봄 기록 시간', size: 18, color: AppColors.muted),
            txt('4시간', size: 18, weight: FontWeight.w700),
          ],
        ),
        gap(16),
        const Divider(),
        gap(16),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            txt('휴게 시간', size: 18, color: AppColors.muted),
            txt('30분', size: 18, weight: FontWeight.w700),
          ],
        ),
      ]),
    ),
    gap(18),
    txt(
      '시간과 위치 기록을 모두 중단했어요.',
      size: 13,
      color: AppColors.muted,
      align: TextAlign.center,
    ),
    gap(18),
    AppButton('기록 보러가기', () => m.go(DemoScreen.records, root: true)),
  ]);

  Widget correctionTime(
    String label,
    String original,
    TextEditingController hour,
    TextEditingController minute,
    String key,
  ) {
    Widget number(TextEditingController controller, String unit) => SizedBox(
      width: 64,
      child: TextField(
        key: ValueKey('$key-$unit'),
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: unit,
          semanticCounterText: '$label $unit',
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return AppCard(
      padding: 16,
      radius: 14,
      child: col([
        txt(label, size: 18, weight: FontWeight.w800),
        gap(6),
        txt('원래 값 $original · 승인 전까지 유지', size: 13, color: AppColors.muted),
        gap(16),
        Row(
          children: [
            number(hour, '시'),
            const SizedBox(width: 10),
            txt(':', size: 24),
            const SizedBox(width: 10),
            number(minute, '분'),
          ],
        ),
      ]),
    );
  }

  Widget change() {
    final correction = m.screen == DemoScreen.correction;
    return col([
      txt(
        correction ? '이미 기록한 시간에 대한 요청' : '예정 일정에 대한 요청',
        weight: FontWeight.w800,
        color: AppColors.deep,
      ),
      gap(18),
      heading(correction ? '기록 정정 요청' : '일정 변경 요청'),
      gap(18),
      txt('요청할 시간  필수', weight: FontWeight.w700),
      gap(12),
      if (correction) ...[
        correctionTime('시작 시간', '09:00', startHour, startMinute, 'start'),
        gap(12),
        correctionTime('종료 시간', '13:30', endHour, endMinute, 'end'),
      ] else
        AppCard(
          padding: 16,
          radius: 14,
          child: Row(
            children: [
              Expanded(
                child: col([
                  txt('원래 값 · 변경되지 않음', size: 12, color: AppColors.muted),
                  txt(
                    correction ? '종료 13:30' : '09:00 ~ 13:30',
                    weight: FontWeight.w700,
                  ),
                ]),
              ),
              icon('imgIcon1'),
              const SizedBox(width: 10),
              Expanded(
                child: col([
                  txt('요청할 값', size: 12, color: AppColors.muted),
                  TextField(
                    controller: time,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      gap(18),
      AppField(
        label: '요청 사유  필수',
        controller: reason,
        hint: '시간을 바꾸려는 이유를 적어주세요.',
        error: error,
      ),
      gap(18),
      AppNotice(
        neutral: true,
        icon: icon('imgIcon2'),
        child: txt('기관이 승인하기 전에는 원본 기록이 바뀌지 않아요.'),
      ),
      gap(18),
      AppButton('요청 보내기', () {
        if (reason.text.trim().isEmpty ||
            (!correction && time.text.trim().isEmpty)) {
          setState(() => error = '요청할 시간과 사유를 입력해주세요.');
          return;
        }
        if (correction) {
          final parts = [
            startHour,
            startMinute,
            endHour,
            endMinute,
          ].map((c) => int.tryParse(c.text)).toList();
          if (parts.any((n) => n == null) ||
              parts[0]! > 23 ||
              parts[2]! > 23 ||
              parts[1]! > 59 ||
              parts[3]! > 59 ||
              parts[0]! * 60 + parts[1]! >= parts[2]! * 60 + parts[3]!) {
            setState(() => error = '시작·종료 시간을 확인해주세요. 종료는 시작 이후여야 해요.');
            return;
          }
          final values = parts
              .map((n) => n.toString().padLeft(2, '0'))
              .toList();
          m.requestChange(
            correction: true,
            time: '시작 ${values[0]}:${values[1]} · 종료 ${values[2]}:${values[3]}',
            reason: reason.text.trim(),
          );
          return;
        }
        final pattern = RegExp(
          r'^(종료\s*)?([01]\d|2[0-3]):[0-5]\d(\s*~\s*([01]\d|2[0-3]):[0-5]\d)?$',
        );
        if (!pattern.hasMatch(time.text.trim())) {
          setState(() => error = '시간 형식을 확인해주세요. 예: 13:20 또는 09:30 ~ 14:00');
          return;
        }
        m.requestChange(
          correction: correction,
          time: time.text.trim(),
          reason: reason.text.trim(),
        );
      }, icon: icon('imgIcon3')),
    ]);
  }

  Widget waiting() => col([
    heading(m.changeKind),
    gap(42),
    roundSymbol(icon('imgIcon1', 32), size: 64),
    gap(24),
    txt(
      '승인을 기다리고 있어요',
      size: 24,
      weight: FontWeight.w800,
      align: TextAlign.center,
    ),
    gap(18),
    txt(
      '동행지원센터에서 요청을 확인할 예정이에요.\n승인 전에는 원본 기록이 유지돼요.',
      size: 17,
      color: AppColors.muted,
      align: TextAlign.center,
    ),
    gap(32),
    AppButton('기록 보러가기', () => m.go(DemoScreen.records, root: true)),
  ]);

  Widget records() {
    final day = DateTime(2026, 3, 12).add(Duration(days: m.dateOffset));
    return col([
      heading('방문 기록'),
      gap(18),
      AppCard(
        padding: 4,
        radius: 14,
        child: Row(
          children: [
            IconButton(
              tooltip: '이전 날짜',
              onPressed: () => m.changeDate(-1),
              icon: icon('imgIcon'),
            ),
            Expanded(
              child: txt(
                '${day.year}년 ${day.month}월 ${day.day}일',
                size: 18,
                weight: FontWeight.w700,
                align: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: '다음 날짜',
              onPressed: () => m.changeDate(1),
              icon: icon('imgIcon1'),
            ),
          ],
        ),
      ),
      gap(18),
      if (m.dateOffset == 0)
        AppCard(
          shadow: true,
          child: col([
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusPill('종료'),
            ),
            gap(18),
            txt('김철수님 가정방문', size: 24, weight: FontWeight.w800),
            txt('09:00 ~ 13:30', size: 14, color: AppColors.muted),
            link(
              '상세 보기',
              () => m.go(
                m.answerSent
                    ? DemoScreen.recordWithoutQuestion
                    : DemoScreen.recordDetail,
              ),
              trailing: icon('imgIcon2'),
            ),
          ]),
        )
      else
        AppCard(child: txt('이 날짜에는 방문 기록이 없어요.', align: TextAlign.center)),
      gap(20),
      txt(
        '이 화면에는 홍길동 님의 방문 기록만 보여요.',
        size: 13,
        color: AppColors.muted,
        align: TextAlign.center,
      ),
    ]);
  }

  Widget requests() {
    final sent = m.screen == DemoScreen.sentRequests;
    return col([
      heading('요청함'),
      gap(24),
      tabSwitch(
        ['기관 확인 요청${m.answerSent ? '' : ' ❶'}', '내가 보낸 변경 요청'],
        sent ? 1 : 0,
        (i) => m.go(
          i == 0 ? DemoScreen.requests : DemoScreen.sentRequests,
          root: true,
        ),
      ),
      gap(18),
      AppCard(
        shadow: true,
        child: col([
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              StatusPill(
                sent
                    ? '승인 대기'
                    : m.answerSent
                    ? '답변 완료'
                    : '답변 필요',
              ),
              txt(
                sent ? '어제 오후 2:10' : '오늘 오전 8:42',
                size: 13,
                color: AppColors.muted,
              ),
            ],
          ),
          gap(18),
          txt(
            sent
                ? (m.correctionSent ? m.changeKind : '종료 시간 정정 요청')
                : '11시 30분 이후 지원 내용을 알려주세요',
            size: 20,
            weight: FontWeight.w800,
          ),
          gap(10),
          txt(
            sent
                ? (m.correctionSent
                      ? '홍길동님 · ${m.requestedTime}'
                      : '홍길동님 · 시작 09:00 · 종료 13:30 → 13:20')
                : '홍길동님 · 3월 12일 11:30~13:30',
            size: 15,
            color: AppColors.muted,
          ),
          gap(18),
          const Divider(),
          link(
            sent
                ? '처리 상태 보기'
                : m.answerSent
                ? '보낸 답변 보기'
                : '질문 확인하고 답변하기',
            () {
              if (sent) {
                if (!m.correctionSent) m.changeKind = '기록 정정 요청';
                m.go(DemoScreen.waiting);
              } else if (m.answerSent) {
                help('보낸 답변', '${m.answerText}\n${m.answerMemo}');
              } else {
                m.go(DemoScreen.answer);
              }
            },
            trailing: icon('imgIcon'),
            color: sent ? AppColors.green : AppColors.deep,
          ),
        ]),
      ),
    ]);
  }

  Widget answerForm() => col([
    txt('동행지원센터에서 보낸 질문입니다.', weight: FontWeight.w800, color: AppColors.deep),
    gap(18),
    heading('해당 시간에 어떤 활동을\n진행했는지 작성해주세요.'),
    gap(24),
    Container(
      color: AppColors.pale,
      padding: const EdgeInsets.all(22),
      child: col([
        txt('확인 요청 항목', size: 13, color: AppColors.muted),
        txt('김철수님 가정 방문', size: 20, weight: FontWeight.w800),
        txt('3월 12일 11:30 ~ 13:30', size: 15, color: AppColors.muted),
        gap(18),
        const Divider(color: AppColors.mintBorder),
        gap(18),
        txt('“11시 30분 이후 지원 내용을 알려주세요.”', weight: FontWeight.w700),
      ]),
    ),
    gap(18),
    txt('답변 선택  필수', weight: FontWeight.w700),
    gap(9),
    DropdownButtonFormField<String>(
      initialValue: answer,
      itemHeight: null,
      isExpanded: true,
      icon: SizedBox(
        width: 20,
        child: Center(child: FigmaIcon(frame, 'imgIcon1', size: 10)),
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items:
          [
                '장보기를 원해 하나로마트에 함께 갔습니다.',
                '병원 진료를 위해 함께 이동했어요',
                '장보기를 함께 했어요',
                '가사 지원을 했어요',
                '기타 활동을 했어요',
              ]
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: txt(s, weight: FontWeight.w700),
                  ),
                ),
              )
              .toList(),
      onChanged: (s) => setState(() => answer = s!),
    ),
    gap(18),
    AppField(
      label: '추가 메모  선택',
      controller: memo,
      hint: '필요한 내용만 간단히 적어주세요.',
      lines: 3,
    ),
    gap(18),
    AppButton(
      '답변 보내기',
      () => m.answer(answer, memo.text.trim()),
      icon: icon('imgIcon2'),
    ),
  ]);

  Widget answered() => col([
    gap(42),
    roundSymbol(icon('imgIcon1', 38)),
    gap(18),
    txt('답변을 보냈어요', size: 28, weight: FontWeight.w800, align: TextAlign.center),
    gap(18),
    txt(
      '기관에서 확인할 예정이에요.',
      size: 18,
      color: AppColors.muted,
      align: TextAlign.center,
    ),
    gap(46),
    AppButton('요청함으로 돌아가기', () => m.go(DemoScreen.requests, root: true)),
  ]);

  Widget profile() => col([
    Row(
      children: [
        Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
          child: txt(
            '홍',
            size: 24,
            weight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: col([
            heading('홍길동님'),
            txt('동행지원센터 · 활동지원사', size: 14, color: AppColors.muted),
          ]),
        ),
      ],
    ),
    gap(26),
    txt('권한과 기록', size: 18, weight: FontWeight.w800),
    gap(18),
    AppCard(
      padding: 0,
      child: col([
        profileRow('imgIcon', '위치 권한', '서비스 중에만 허용', const StatusPill('허용')),
        const Divider(),
        profileRow('imgIcon1', '알림 권한', '기관 요청과 일정 알림', const StatusPill('허용')),
        const Divider(),
        profileRow(
          'imgIcon2',
          '움직임 시험 기능',
          '미지원이어도 방문 기록 가능',
          const StatusPill('확인 중'),
        ),
        const Divider(),
        profileRow(
          'imgIcon3',
          '미전송 기록',
          '인터넷 연결 시 자동 전송',
          txt('0건', weight: FontWeight.w700),
        ),
      ]),
    ),
    gap(26),
    txt('도움과 안내', size: 18, weight: FontWeight.w800),
    gap(18),
    AppCard(
      padding: 0,
      child: col([
        InkWell(
          onTap: () => help('기관에 전화', '동행지원센터의 실제 전화번호는 아직 등록되지 않았어요.'),
          child: profileRow('imgIcon4', '기관에 전화', '동행지원센터', icon('imgIcon5')),
        ),
        const Divider(),
        InkWell(
          onTap: () => help(
            '개인정보 안내',
            '현재는 정적 화면 데모이며 위치·계정 정보를 수집하거나 기관에 전송하지 않아요. 입력 내용은 화면을 새로 실행하면 초기화돼요.',
          ),
          child: profileRow('imgIcon6', '개인정보 안내', '', icon('imgIcon5')),
        ),
        const Divider(),
        InkWell(
          onTap: () => help(
            '계정·기관 이동 도움',
            '한 활동지원사는 한 기관에 소속돼요. 실제 기관 이동은 담당 관리자에게 요청해주세요. 이 데모에서는 기관을 변경하지 않아요.',
          ),
          child: profileRow('imgIcon7', '계정·기관 이동 도움', '', icon('imgIcon5')),
        ),
      ]),
    ),
    gap(18),
    AppNotice(
      icon: icon('imgIcon8'),
      child: txt('진행 중인 방문이나 미전송 기록이 있으면 로그아웃 전에 알려드려요.'),
    ),
    gap(18),
    AppButton('로그아웃', () async {
      if (m.visitState == '돌봄 중' || m.visitState == '쉬는 중') {
        await help('진행 중인 방문이 있어요', '방문을 종료한 뒤 로그아웃해주세요.');
        return;
      }
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('로그아웃할까요?'),
          content: const Text('정적 데모에서 입력한 내용은 초기화돼요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      );
      if (yes == true) m.logout();
    }, primary: false),
  ]);
  Widget profileRow(String asset, String title, String subtitle, Widget end) =>
      Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            icon(asset),
            const SizedBox(width: 14),
            Expanded(
              child: col([
                txt(title, size: 18, weight: FontWeight.w700),
                if (subtitle.isNotEmpty)
                  txt(subtitle, size: 12, color: AppColors.muted),
              ]),
            ),
            const SizedBox(width: 8),
            end,
          ],
        ),
      );

  Widget recordDetail() => col([
    const Align(alignment: Alignment.centerLeft, child: StatusPill('종료')),
    gap(8),
    heading('2026년 3월 12일'),
    gap(22),
    for (var i = 0; i < 4; i++)
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.pale,
                    ),
                    child: Center(
                      child: icon(
                        ['imgIcon1', 'imgIcon2', 'imgIcon3', 'imgIcon1'][i],
                      ),
                    ),
                  ),
                  if (i < 3)
                    Expanded(
                      child: Container(width: 2, color: AppColors.green),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: col([
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      txt(
                        ['시작', '휴게', '복귀', '종료'][i],
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                      txt(
                        ['09:00', '11:00', '11:30', '13:30'][i],
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ],
                  ),
                  gap(22),
                  txt(
                    [
                      '아리역로 37 위치 확인',
                      '위치 기록 중단',
                      '아리역로 37 위치 재 확인',
                      '모든 기록 중단',
                    ][i],
                    size: 14,
                    color: AppColors.muted,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    gap(10),
    AppCard(
      border: AppColors.mintBorder,
      radius: 14,
      padding: 16,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: col([
                txt(
                  ['전체', '돌봄', '휴게'][i],
                  size: 13,
                  color: AppColors.green,
                  align: TextAlign.center,
                ),
                txt(
                  ['4시간 30분', '4시간', '30분'][i],
                  size: 15,
                  weight: FontWeight.w700,
                  color: AppColors.deep,
                  align: TextAlign.center,
                ),
              ]),
            ),
        ],
      ),
    ),
    gap(18),
    AppCard(
      child: col([
        txt('현장 사유', size: 19, weight: FontWeight.w800),
        gap(7),
        txt(
          m.savedNote.isEmpty ? '작성한 현장 사유가 없어요.' : m.savedNote,
          size: 15,
          color: AppColors.muted,
        ),
        link(
          '현장 사유 추가',
          () => m.go(DemoScreen.note),
          trailing: icon('imgIcon4'),
        ),
      ]),
    ),
    gap(18),
    if (m.screen == DemoScreen.recordDetail && !m.answerSent) ...[
      AppCard(
        child: col([
          txt('기관 질문', size: 19, weight: FontWeight.w800),
          gap(7),
          txt('11시 30분 이후 지원 내용을 알려주세요.', size: 15, color: AppColors.muted),
          link(
            '기관 요청 보기',
            () => m.go(DemoScreen.answer),
            trailing: icon('imgIcon5'),
          ),
        ]),
      ),
      gap(18),
    ],
    AppCard(
      child: col([
        txt('정정 내역', size: 19, weight: FontWeight.w800),
        gap(7),
        txt(
          m.correctionSent ? '승인 대기 · 원본 기록을 사용하고 있어요.' : '원본 기록을 사용하고 있어요.',
          size: 15,
          color: AppColors.muted,
        ),
      ]),
    ),
    gap(18),
    AppButton('기록 정정 요청', () => m.go(DemoScreen.correction)),
  ]);
}
