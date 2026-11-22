import 'package:flutter/foundation.dart';

enum DemoScreen {
  login,
  signup,
  home,
  scheduled,
  active,
  rest,
  note,
  endConfirm,
  ended,
  scheduleChange,
  waiting,
  correction,
  records,
  requests,
  answer,
  answered,
  sentRequests,
  profile,
  recordDetail,
  recordWithoutQuestion,
}

const frameIds = <DemoScreen, String>{
  DemoScreen.login: '1:77',
  DemoScreen.signup: '1:114',
  DemoScreen.home: '1:151',
  DemoScreen.scheduled: '1:247',
  DemoScreen.active: '1:307',
  DemoScreen.rest: '1:395',
  DemoScreen.note: '1:433',
  DemoScreen.endConfirm: '1:470',
  DemoScreen.ended: '1:498',
  DemoScreen.scheduleChange: '1:536',
  DemoScreen.waiting: '1:583',
  DemoScreen.correction: '1:606',
  DemoScreen.records: '1:653',
  DemoScreen.requests: '1:709',
  DemoScreen.answer: '1:765',
  DemoScreen.answered: '1:806',
  DemoScreen.sentRequests: '1:825',
  DemoScreen.profile: '1:876',
  DemoScreen.recordDetail: '1:999',
  DemoScreen.recordWithoutQuestion: '1:1100',
};

/// An in-memory presentation model: never performs authentication, tracking,
/// persistence or network requests. The clock values are Figma fixtures.
class DemoModel extends ChangeNotifier {
  DemoModel({this.screen = DemoScreen.login});
  DemoScreen screen;
  final List<DemoScreen> _history = [];
  String visitState = '예정';
  bool resumed = false, answerSent = false, correctionSent = false;
  String savedNote = '', changeKind = '일정 변경 요청';
  String requestedTime = '09:30 ~ 14:00', changeReason = '';
  String answerText = '', answerMemo = '';
  int dateOffset = 0;

  void go(DemoScreen next, {bool root = false}) {
    if (root) {
      _history.clear();
    } else {
      _history.add(screen);
    }
    screen = next;
    notifyListeners();
  }

  void back() {
    screen = _history.isEmpty ? DemoScreen.home : _history.removeLast();
    notifyListeners();
  }

  void start() {
    visitState = '돌봄 중';
    go(DemoScreen.active);
  }

  void pause() {
    visitState = '쉬는 중';
    go(DemoScreen.rest);
  }

  void resume() {
    visitState = '돌봄 중';
    resumed = true;
    go(DemoScreen.active, root: true);
  }

  void end() {
    visitState = '종료';
    go(DemoScreen.ended, root: true);
  }

  void openVisit() => go(switch (visitState) {
    '돌봄 중' => DemoScreen.active,
    '쉬는 중' => DemoScreen.rest,
    '종료' =>
      answerSent ? DemoScreen.recordWithoutQuestion : DemoScreen.recordDetail,
    _ => DemoScreen.scheduled,
  });
  void saveNote(String value) {
    savedNote = value;
    back();
  }

  void answer(String value, String memo) {
    answerSent = true;
    answerText = value;
    answerMemo = memo;
    go(DemoScreen.answered, root: true);
  }

  void requestChange({
    required bool correction,
    required String time,
    required String reason,
  }) {
    correctionSent = true;
    changeKind = correction ? '기록 정정 요청' : '일정 변경 요청';
    requestedTime = time;
    changeReason = reason;
    go(DemoScreen.waiting, root: true);
  }

  void changeDate(int delta) {
    dateOffset += delta;
    notifyListeners();
  }

  void logout() {
    visitState = '예정';
    resumed = false;
    answerSent = false;
    savedNote = '';
    correctionSent = false;
    dateOffset = 0;
    go(DemoScreen.login, root: true);
  }
}
