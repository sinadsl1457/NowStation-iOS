# NowStation iOS

지하철에서 지금 무슨 역인지 잠금화면에 보여 주는 앱의 iOS 클라이언트. 판단(탄 열차 찾기)은 서버가 한다 → NowStation-Server.
지금은 **개인 테스트용**(무료 Apple 계정, 내 폰에만 설치). 화면·문구·판단 규칙은 NowStation-Android와 같게 둔다.

## 스택
- Swift 5 모드, SwiftUI, Observation(`@Observable`), iOS 17+. 외부 라이브러리 없음
- 프로젝트 파일은 XcodeGen이 만든다: `project.yml`을 고치고 `xcodegen generate`(`.xcodeproj`도 커밋)
- 서버 주소: `Config/Local.xcconfig`의 `API_BASE_URL`(저장소에 안 올림, EC2 IP). 없으면 `http://localhost:8080/`(시뮬레이터에서 이 컴퓨터의 재생 서버)
- 서명: 무료 개인 팀 `ZCAU623N43`. 다른 개인 팀(83P9XUMFCW)은 기기 등록 한도가 차서 이 폰을 못 넣는다
- 무료 서명 한계: 7일마다 다시 설치, 한 폰에 무료 서명 앱 3개까지, APNs·시간 민감 알림 없음

## APNs 없이 탑승을 따라가는 방법
- 탑승하는 동안 위치 갱신을 켜 둔다(`UIBackgroundModes: location`). `CLBackgroundActivitySession`은 쓰지 않는다: 앱이 죽어도 운영체제에 남아 파란 화살표가 꺼지지 않았다(실기기). 앱이 잠들지 않게 하려는 것이고 위치 값은 쓰지 않는다(지하라 부정확)
- 깨어 있는 동안 가속도(20Hz) → `MotionDetector`(Android와 같은 규칙) → 서버, 5초마다 상태 갱신
- 잠금화면·다이나믹 아일랜드는 Live Activity를 **앱이 직접** 갱신. 내릴 역 직전에는 `AlertConfiguration`으로 화면을 켜고 소리, 그리고 로컬 알림 + 진동
- 사용자가 앱을 위로 밀어 강제 종료하면 멈춘다(iOS는 다시 띄워 주지 않음)

## 구조 — Android와 같은 나눔
```
NowStation/
├ App/       진입점. 탑승 중이면 탑승 화면, 아니면 홈(화면이 둘뿐이라 이동 라이브러리 없음)
├ Core/      서버 API(연결 실패·404·400·서버 오류 구분), 색·노선 칩(위젯과 같이 씀)
├ Station/   홈·역 검색·최근 경로. 상태는 HomeViewModel
├ Settings/  설정. 모두 앱 안에서: 알림 스위치(AlertSettings: 갈아타기·내릴 역·진동, RideRunner가 따름), 사용법 다시 보기, 문의하기(서버 POST /api/feedback), 개인정보처리방침(WKWebView, 서버 /privacy, 메일 링크는 문의하기로), 라이선스, 버전
├ Guide/     처음 실행 가이드 4장(+ 봤는지 저장). 홈과 따로 생기고 사라져서(처음 한 번·다시 보기) 따로 둠. 알림·위치 권한은 마지막 장 버튼에서 묻는다
└ Ride/      진행 중인 탑승. 화면이 사라져도 계속돼야 해서 앱에 하나인 RideTracker가 갖는다
   ├ Motion/      가속도 → 출발·도착 사건(순수 Swift, 합성 신호로 테스트)
   └ Background/  RideRunner: 깨어 있기, 센서, 5초 갱신, Live Activity, 내릴 역 알림(Android 포그라운드 서비스 자리)
Shared/          Live Activity 데이터 모양(앱 + 위젯)
NowStationWidget/ 잠금화면·다이나믹 아일랜드 그리기만
```
- 탑승 화면은 이번정거장처럼: 경로 구간 칩(태평 ▶ 선릉, 선릉 ▶ 강남) + 가로 노선도(`StripCard`, 15초마다)에서 서버가 골라 둔 다음 열차를 칠하고, 다른 열차를 누르면 바꾼다. 고른 열차는 그대로 따라간다(폰 움직임으로 바꾸지 않음). 환승역에서는 "갈아탈 준비하세요" 알림 → 안내 띠로 다음 구간 열차 고르기
- 앱을 새로 켜면 런치 애니메이션(`LaunchIntro`/`LaunchOverlay`, HomeView.swift: 시작 화면 아이콘 → 홈 머리의 노선 그림) 뒤 처음 한 번 가이드. 시작 화면 설정은 `project.yml`의 `UILaunchScreen`(Info.plist를 직접 고치면 xcodegen이 지운다). UI 테스트는 `-skipLaunchIntro`로 둘 다 끈다
- 시간은 주입(`RideTracker(now:)`). 문구는 `RideTexts` 한곳(화면·잠금화면이 같이 씀)

## 확인
- 단위: `xcodebuild test -scheme NowStation -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:NowStationTests`
- 화면 흐름(실제 서버): `-only-testing:NowStationUITests`. 단계별 스크린숏은 결과 번들 첨부
- 폰 설치: `xcodebuild ... -destination 'id=<폰 UDID>' -allowProvisioningUpdates build` → `xcrun devicectl device install app`

## 작업 방식
- 커밋은 기능 하나씩. squash·amend·force push 금지. 주석은 결정과 이유만.
- 버그를 고치면 고치기 전에 실패하는 테스트로 고정한다.
