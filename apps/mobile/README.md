# 돌봄이음 활동지원사 앱

Figma 정적 데모 실행 (백엔드/인증/GPS 연결 없음):

```powershell
flutter pub get
flutter run -d chrome -t lib/main_demo.dart --web-port 5174
```

`run-demo.ps1`로도 실행할 수 있습니다. 입력 없이 로그인 버튼을 누르면 시연을 시작합니다.
화면 직접 열기: `http://localhost:5174/?screen=recordDetail`

- [실행 안내](../../docs/앱_정적데모_실행안내.txt)
- [20개 프레임 대응 및 검토](../../docs/앱_Figma_프레임검토.txt)

기존 `lib/main.dart`는 백엔드 연동 진입점이며 그대로 유지합니다.

# dolbom_ieum

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
