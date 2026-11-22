import 'package:flutter_test/flutter_test.dart';
import 'package:dolbom_ieum/services.dart';

void main() {
  test('actual breaks are excluded from recorded care time', () {
    final events = <Map<String, dynamic>>[
      {'kind': 'start', 'occurred_at': '2026-11-20T09:00:00Z'},
      {'kind': 'pause', 'occurred_at': '2026-11-20T11:00:00Z'},
      {'kind': 'resume', 'occurred_at': '2026-11-20T11:30:00Z'},
      {'kind': 'end', 'occurred_at': '2026-11-20T13:30:00Z'},
    ];
    expect(durations(events), {'care': 14400, 'pause': 1800, 'total': 16200});
  });
  test('ending while paused closes break without artificial resume', () {
    expect(
      durations([
        {'kind': 'start', 'occurred_at': '2026-11-20T09:00:00Z'},
        {'kind': 'pause', 'occurred_at': '2026-11-20T10:00:00Z'},
        {'kind': 'end', 'occurred_at': '2026-11-20T10:30:00Z'},
      ]),
      {'care': 3600, 'pause': 1800, 'total': 5400},
    );
  });
}
