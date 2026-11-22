import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'components.dart';
import 'model.dart';
import 'screens.dart';

class DemoApp extends StatefulWidget {
  const DemoApp({this.initialScreen = DemoScreen.login, this.model, super.key});
  final DemoScreen initialScreen;
  final DemoModel? model;
  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final DemoModel model =
      widget.model ?? DemoModel(screen: widget.initialScreen);
  @override
  void dispose() {
    if (widget.model == null) model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '돌봄이음 · 정적 화면 데모',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deep,
          minimumSize: const Size(48, 48),
        ),
      ),
    ),
    builder: (context, child) => ColoredBox(
      color: const Color(0xffecece8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 402),
          child: child!,
        ),
      ),
    ),
    home: ListenableBuilder(
      listenable: model,
      builder: (context, _) => DemoShell(model: model),
    ),
  );
}

class DemoShell extends StatelessWidget {
  const DemoShell({required this.model, super.key});
  final DemoModel model;
  static const tabs = [
    DemoScreen.home,
    DemoScreen.records,
    DemoScreen.requests,
    DemoScreen.profile,
  ];
  bool get isTab =>
      tabs.contains(model.screen) || model.screen == DemoScreen.sentRequests;
  bool get isAuth =>
      model.screen == DemoScreen.login || model.screen == DemoScreen.signup;
  @override
  Widget build(BuildContext context) {
    final frame = frameIds[model.screen]!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !isAuth) model.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: isTab || isAuth ? 68 : 76,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                alignment: Alignment.centerLeft,
                child: isTab || isAuth
                    ? const Brand()
                    : TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: model.back,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FigmaIcon(frame, 'imgIcon'),
                            const SizedBox(width: 4),
                            txt(
                              '뒤로',
                              size: 17,
                              weight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(model.screen),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, isAuth ? 46 : 26, 20, 42),
                  child: DemoScreenBody(
                    key: ValueKey('body-${model.screen.name}'),
                    model: model,
                  ),
                ),
              ),
              if (isTab) _nav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav() {
    final selected = model.screen == DemoScreen.sentRequests
        ? 2
        : tabs.indexOf(model.screen);
    final frame = frameIds[model.screen]!;
    final names = switch (model.screen) {
      DemoScreen.home => ['imgIcon3', 'imgIcon4', 'imgIcon5', 'imgIcon6'],
      DemoScreen.records => ['imgIcon3', 'imgIcon4', 'imgIcon5', 'imgIcon6'],
      DemoScreen.profile => ['imgIcon9', 'imgIcon10', 'imgIcon11', 'imgIcon12'],
      _ => ['imgIcon1', 'imgIcon2', 'imgIcon3', 'imgIcon4'],
    };
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: List.generate(
          4,
          (i) => Expanded(
            child: Semantics(
              selected: selected == i,
              button: true,
              child: InkWell(
                onTap: () => model.go(tabs[i], root: true),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            FigmaIcon(
                              frame,
                              names[i],
                              size: selected == i ? 28 : 22,
                            ),
                            if (i == 2 && !model.answerSent)
                              Positioned(
                                right: -8,
                                top: -7,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.mintBorder,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.deep),
                                  ),
                                  child: txt(
                                    '1',
                                    size: 12,
                                    color: AppColors.deep,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        gap(3),
                        txt(
                          ['오늘 방문', '기록', '요청', '내 정보'][i],
                          size: selected == i ? 15 : 13,
                          weight: FontWeight.w700,
                          color: selected == i
                              ? AppColors.green
                              : AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
