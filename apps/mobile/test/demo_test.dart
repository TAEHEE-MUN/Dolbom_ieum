import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolbom_ieum/demo/app.dart';
import 'package:dolbom_ieum/demo/model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansKR');
    font.addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'));
    await font.load();
  });

  Future<void> open(
    WidgetTester tester,
    DemoModel model, {
    Size size = const Size(402, 874),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    await tester.pumpWidget(DemoApp(model: model));
    await tester.pumpAndSettle();
  }

  tearDown(() {});

  testWidgets(
    'all 20 Figma screens render; long content scrolls; no overflow at narrow width and large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final size in [const Size(402, 874), const Size(320, 640)]) {
        for (final screen in DemoScreen.values) {
          final model = DemoModel(screen: screen);
          await open(
            tester,
            model,
            size: size,
            scale: size.width == 320 ? 1.5 : 1,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.name} at $size',
          );
          final scroll = find.byType(SingleChildScrollView).first;
          await tester.drag(scroll, const Offset(0, -1800));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Scrolled ${screen.name} at $size',
          );
          await tester.pumpWidget(const SizedBox());
          model.dispose();
        }
      }
    },
  );

  testWidgets('visit actions, note, break/resume and end are navigable', (
    tester,
  ) async {
    final model = DemoModel();
    await open(tester, model);
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();
    expect(model.screen, DemoScreen.home);
    await tester.tap(find.text('방문 상세 보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('서비스 시작하기'));
    await tester.tap(find.text('서비스 시작하기'));
    await tester.pumpAndSettle();
    expect(model.visitState, '돌봄 중');
    await tester.ensureVisible(find.text('현장 사유 남기기'));
    await tester.tap(find.text('현장 사유 남기기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('장보기 동행'));
    await tester.enterText(find.byType(TextField), '필요 물품 구매');
    await tester.ensureVisible(find.text('현장 사유 저장'));
    await tester.tap(find.text('현장 사유 저장'));
    await tester.pumpAndSettle();
    expect(model.savedNote, '장보기 동행 · 필요 물품 구매');
    await tester.ensureVisible(find.text('쉬기 시작'));
    await tester.tap(find.text('쉬기 시작'));
    await tester.pumpAndSettle();
    expect(model.visitState, '쉬는 중');
    await tester.ensureVisible(find.text('다시 시작'));
    await tester.tap(find.text('다시 시작'));
    await tester.pumpAndSettle();
    expect(model.resumed, isTrue);
    await tester.ensureVisible(find.text('방문 종료'));
    await tester.tap(find.text('방문 종료'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('방문 종료'));
    await tester.tap(find.text('방문 종료'));
    await tester.pumpAndSettle();
    expect(model.screen, DemoScreen.ended);
    expect(model.visitState, '종료');
  });

  testWidgets(
    'correction requires reason and preserves original; answer clears badge',
    (tester) async {
      final model = DemoModel(screen: DemoScreen.correction);
      await open(tester, model);
      await tester.tap(find.text('요청 보내기'));
      await tester.pumpAndSettle();
      expect(model.correctionSent, isFalse);
      expect(find.text('요청할 시간과 사유를 입력해주세요.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '종료 버튼을 늦게 눌렀어요.');
      await tester.ensureVisible(find.text('요청 보내기'));
      await tester.tap(find.text('요청 보내기'));
      await tester.pumpAndSettle();
      expect(model.correctionSent, isTrue);
      expect(model.requestedTime, '종료 13:20');
      model.go(DemoScreen.recordDetail);
      await tester.pumpAndSettle();
      expect(find.text('13:30'), findsOneWidget);
      model.go(DemoScreen.answer);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('답변 보내기'));
      await tester.tap(find.text('답변 보내기'));
      await tester.pumpAndSettle();
      expect(model.answerSent, isTrue);
      expect(model.screen, DemoScreen.answered);
    },
  );

  testWidgets('capture each screen for design comparison', (tester) async {
    const capture = bool.fromEnvironment('CAPTURE_DEMO');
    if (!capture) return;
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    final output = Directory('build/demo-review')..createSync(recursive: true);
    for (final screen in DemoScreen.values) {
      final model = DemoModel(screen: screen);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: DemoApp(model: model),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/${screen.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2400),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('${output.path}/${screen.name}_bottom.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    }
  });
}
