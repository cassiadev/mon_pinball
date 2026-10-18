# Mon Pinball

[English](README.md) | [한국어](README.ko.md)

Flutter, Flame, Forge2D로 만든 작은 핀볼 게임입니다. Flutter는 앱의 기본 화면,
터치 입력, 헤드업 디스플레이(Head-Up Display, HUD: 점수·남은 공·상태·발사 충전
계기판)를 담당합니다. Flame/Forge2D는 게임 루프와 물리 월드를 담당합니다.

## 실행

```sh
flutter pub get
flutter run
```

## 조작

- 화면 왼쪽 터치: 왼쪽 플리퍼
- 발사 레인을 제외한 화면 오른쪽 터치: 오른쪽 플리퍼
- 오른쪽 발사 레인을 아래로 끌었다 놓기: 공 발사
- 키보드: `A`/왼쪽 방향키는 왼쪽 플리퍼, `D`/오른쪽 방향키는 오른쪽 플리퍼,
  `Space`/아래 방향키는 발사, `W`/위 방향키는 흔들기, `R`은 다시 시작
- 발사 레인으로 다시 굴러 내려온 공은 공을 잃지 않고 발사대 위에 멈추며
  다시 발사할 수 있습니다.

## 화면 디자인

달빛 정원 디자인은 남색 연못 배경, 등꽃, 금색 레일, 청록·분홍·금색 보석
범퍼와 아이보리 공을 사용합니다. 정적 배경과 투명한 보스 부위 이미지는
앱에 포함하며 [그림 제작 기록](assets/images/moonlit/ARTWORK.md)에 출처를
남겼습니다. 28 x 56 게임판은 승인된 세로 시안을 따르고, 정원 배경이 게임판
바깥 화면도 감쌉니다. 보스는 물리 장애물 아래의 독립 레이어에 떠 있어 보석
범퍼·타깃·공이 보스 위에서 잘 보이며, 꽃잎 탄은 장애물 위에 그립니다. 청록
범퍼·달 문양·플리퍼 사이 틈은 같은 가로 중심을 사용하고, 플리퍼의 실제 충돌
영역과 보이는 면을 일치시켰습니다. 달 문양 자체가 범퍼이고 금색 기둥 두 개가
가운데 빈 공간을 나누어 공이 빈 곳을 오래 가로지르지 않습니다. 위쪽 보석
범퍼 사이는 공 하나가 겨우 지나는 폭입니다.

휴대폰 GPU에서 매 프레임 별도 렌더링이 필요한 블러 마스크, 셰이더 마스크,
흐린 글자 그림자는 쓰지 않습니다. 빛 번짐은 겹친 선이나 미리 만든 그라데이션으로
그리고, 움직이지 않는 게임판 그림은 화면 해상도로 한 번 그려 둔 이미지를
다시 씁니다.

왼쪽 안내 레일, 둥근 천장, 오른쪽 벽과 발사 레인 바닥은 끊김 없는 하나의
벽으로 이어지며, 레인 안쪽 벽은 오른쪽 인레인 레일과 바로 연결됩니다. 인레인
레일은 각 플리퍼 바로 위에서 끝나고, 슬링샷과 짝을 이룬 타깃은 공 하나가
지날 폭을 남기며, 오른쪽 모서리는 레인 벽에 맞붙어 있습니다. 게임판 전체에
공을 놓아 보는 검사가 발사대 외의 곳에서 공이 멈추면 실패합니다.

세로 화면은 시안의 상단 계기판을 따릅니다. 제목·점수·다시 시작, 남은 공·상태
문구·발사 충전·콤보, 보스 체력 막대를 합쳐 휴대폰 높이의 약 13%만 사용합니다.
폭이 350 px보다 좁으면 상태 문구를 계기판의 별도 줄에 둡니다. 플리퍼와 발사
안내는 게임판에 직접 표시합니다. 넓은 창이나 휴대폰 가로 화면에서는 계기판을 오른쪽에
배치합니다. 배치가 바뀌어도 게임 인스턴스를 유지하고, 터치 좌표는 게임판
내부 좌표를 사용합니다. 화면 높이가 짧거나 글자를 크게 설정한 경우 계기판만
할당된 공간 안에서 스크롤하므로 게임판이 계속 보이고 조작할 수 있습니다.
상태 문구는 줄바꿈하며, 점수는 최소 8자리를 유지하고 더 긴 숫자는 폭에 맞춰
축소합니다. 다시 시작 버튼에는 동작을 명시한 문구를 사용합니다.

이전 `_GlassPanel`은 상단의 점수, 남은 공·상태·충전, 다시 시작 패널과 하단
조작 안내를 감쌌습니다. 반투명한 어두운 배경, 둥근 모서리, 옅은 흰색 테두리,
그림자로 유리 느낌을 냈으며, 뒤쪽 화면을 흐리는 효과는 없었습니다.
현재 `_InstrumentPanel`은 넓은 화면의 계기판에 불투명한 어두운 배경과 얇은
테두리를 사용합니다. 세로 화면은 `_MoonlitHeader`로 계기판을 줄여
게임판 공간을 확보합니다.

### 보스전

츠키비나는 위쪽 보석 범퍼 위를 날아다닙니다. 몸통·날개·소매·치맛자락을 따로
움직여 호흡, 이동의 지연, 공격 준비와 복귀, 피격 반동을 표현하며, 각 부위는
그려진 원래 비율을 유지합니다.
공이 금색 가슴 장식(명치)을 통과하면 1,280의 치명타를, 머리나 몸통에 맞으면
320의 피해를 줍니다. 치마와 소매는 판정에 들어가지 않아 그 아래 범퍼에서 공이
튀어도 체력이 깎이지 않습니다. 두 판정 모두 공의 속도를 바꾸지 않습니다. 시작 체력은 16,000입니다. 체력은 퍼센트
숫자 없이 바로 표시하고, 화면 읽기에는 수치를 제공합니다. 득점하면 콤보가
증가하고 공을 잃으면 콤보는 초기화되지만 보스에게 준 피해는 유지됩니다.
다시 시작하면 보스와 게임 상태가 모두 초기화됩니다.

첫 탄 패턴은 곡선을 그리는 보라색 꽃잎 두 갈래입니다. 현재 꽃잎은 물리
효과가 없는 방해용 연출입니다. 발사 뒤에만 공격을 시작하며, 공 소실·재시작·
격파 시 탄을 정리합니다. 보스를 격파하면 남은 공을 보존하고 재도전할 수
있습니다. 격파하면 1.4초 동안 가슴 장식이 빛난 뒤 떠오르며 사라지는 퇴장
연출을 마치고, 다시 시작할 때까지 게임판에서 제거됩니다. 고난도 물리 탄과
등장 연출은 후속 범위입니다.

### 폰트와 라이선스 출처

| 용도 | 폰트와 원본 출처 | 포함한 라이선스 |
| --- | --- | --- |
| 제목 | [Rajdhani SemiBold](https://github.com/google/fonts/tree/main/ofl/rajdhani) | [Rajdhani-OFL.txt](assets/fonts/Rajdhani-OFL.txt) |
| 화면 문구와 보조 숫자 | [IBM Plex Mono Medium](https://github.com/IBM/plex) | [IBMPlexMono-LICENSE.txt](assets/fonts/IBMPlexMono-LICENSE.txt) |
| 컴퓨터에서 실행하는 테스트 전용 | [Nanum Gothic](https://github.com/google/fonts/tree/main/ofl/nanumgothic) | [NanumGothic-OFL.txt](test/fonts/NanumGothic-OFL.txt) |

제품 폰트와 라이선스 파일은 `design/fonts/`의 원본을 수정 없이
`assets/fonts/`로 복사했습니다. 라이선스 파일은 폰트 제작자가 제공한 고지입니다.
동봉한 SIL Open Font License(OFL) 1.1의 제2항은 폰트를 재배포할 때 저작권
고지와 라이선스를 함께 포함하도록 규정합니다. 제품 폰트의 라이선스는
`pubspec.yaml`에도 앱 자산으로 등록했습니다.

한글은 시스템의 산세리프 대체 폰트를 사용합니다. 골든 테스트는 시스템 폰트가
없어도 한글을 읽을 수 있도록 `test/fonts/`의 나눔고딕을 로드합니다. 이 테스트용
폰트는 앱에 포함하지 않습니다. Git 추적에서 제외한 `design/` 폴더는 참고 자료이며
게임을 빌드하거나 실행하는 데 필요하지 않습니다.

## 개발 브랜치

작업 성격에 따라 `feature/`, `redesign/`, `refactor/`, `workflow/` 뒤에 구체적인
작업명을 붙입니다. 예: `feature/add-moonlit-garden-boss`. 기존 커밋 형식
(`feat:`, `fix:`, `test:`, `docs:`)을 유지하고, 검증한 단계마다 나눠 커밋합니다.
본문에는 변경 이유·동작·실제 검증 결과를 남깁니다. 병합과 푸시는 명시적인
요청이 있을 때 진행합니다.

## 검증

정적 분석, 테스트, 디버그 Android Application Package(APK, 안드로이드 설치 파일)
빌드를 실행합니다.

```sh
flutter analyze
flutter test
flutter build apk --debug
```

### 테스트 구성

Android Studio의 실행 설정에서 `Pinball - All Tests`,
`Pinball - Controls Tests`, `Pinball - Golden Tests`를 선택하면
컴퓨터의 Flutter 테스트 러너로 실행됩니다. 게임을 직접 플레이할 때는
기존 `main.dart` 실행 설정을 사용하세요.

테스트 파일을 기기 대상으로 실행하면 테스트가 실행되는 동안만 게임 화면이
표시됩니다. 실행이 끝난 뒤에는 플레이 가능한 게임 화면이 남지 않습니다.
기기에서 조작 테스트를 실행할 수 있지만, 골든 테스트는 화면만 렌더링하고
이미지 비교를 명시적으로 건너뜁니다. 기준 이미지와의 실제 비교는 컴퓨터에서
`Pinball - Golden Tests` 또는 `flutter test --tags golden`으로 실행하세요.
테스트용 폰트는 컴퓨터에서만 로드하므로 기기에는 추가 테스트 자산이 필요 없습니다.

```sh
# Gherkin 시나리오만 실행
flutter test --tags gherkin

# 골든 이미지 비교만 실행
flutter test --tags golden

# 의도적으로 화면을 변경한 뒤 골든 기준 이미지 갱신
flutter test test/golden/pinball_screen_golden_test.dart --update-goldens

# .feature 파일을 수정한 뒤 Dart 위젯 테스트 재생성
dart run build_runner build
```

골든 테스트는 실제 Flame/Forge2D 게임판을 `390 x 844` 크기로 렌더링해 초기
계기판, 발사대 충전, 게임 종료 화면을 검사합니다. `1280 x 800` 데스크톱
배치와 8자리 점수가 표시된 `320 x 740` 좁은 화면도 검사합니다. 동봉한 폰트로
글자 모양을 일정하게 유지하고 읽을 수 있게 합니다. 위젯 테스트는 큰 글자,
작은 가로 화면, 화면 배치 변경 시 게임 상태 유지, 크기 변경 후 발사대 입력을
검증합니다. `test/table_traps_test.dart`는 레인으로 돌아온 공이 발사대에 다시
놓이는지와 공이 멈춰 끼는 곳이 없는지 검사합니다. 게임판 테스트는 양쪽 플리퍼의
가장 바깥 끝으로 공을 쳐 보고, 모든 범퍼·달·금색 기둥에서 공이 튀며 점수가
오르는지 확인합니다. `test/render_budget_test.dart`는 정적인 게임판 그림을 프레임마다
재사용하는지와 그리기 코드에 블러·마스크가 다시 들어오지 않았는지 검사합니다.

점수 비교용 골든 이미지는 같은 `390 x 844` 화면에서 8자리(`12,345,678`),
9자리(`123,456,789`), 네이티브 정수형의 최댓값인 19자리
(`9,223,372,036,854,775,807`)를 표시합니다. 마지막 예시는 Android 및
네이티브 Dart의 표시 한계를 확인하기 위한 것으로 게임의 점수 상한을 추가하지
않습니다. 이미지는 `test/golden/goldens/`의 `pinball_score_8_digits.png`,
`pinball_score_9_digits.png`, `pinball_score_19_digits.png`입니다.

Gherkin 시나리오의 원본은 `test/features/pinball_controls.feature`입니다.
`bdd_widget_test`가 해당 Flutter 위젯 테스트를 생성하며, 재사용하는 단계별
구현은 `test/steps/`에 있습니다. 시나리오는 초기 계기판, 양쪽 플리퍼의 터치
조작, 발사대 끌기·놓기, 다시 시작, 키보드 흔들기를 검증합니다.

`test/pinball_physics_test.dart`는 실제 Forge2D 물리 시간을 진행시켜 발사 전
대기, 충전, 공 소실, 다시 시작, 최소 발사력으로 레인 출구 통과, 비행 중 발사대
연타가 공에 영향을 주지 않는 동작을 검증합니다.

보스 공격·피격·격파 화면도 골든 기준 이미지로 검증합니다.
보스 테스트는 시간에 따른 동작, 빠른 공의 약점 통과, 접촉 중 중복 피해 방지,
실제 게임의 발사·공 소실·격파 정리, 부위별 렌더링, 체력 접근성, 중심 정렬,
범퍼 통로와 플리퍼의 보이는 충돌 면을 검증합니다. 이미지 디코딩은 테스트의
가상 시간 밖에서 수행하고, 물리 시간은 테스트가 직접 진행시킵니다.

## 프로젝트 구조

```text
lib/
  main.dart          Flutter 앱, 반응형 계기판, 게임 호스트, 터치 입력
  pinball_game.dart  Flame/Forge2D 게임, 물리 바디, 점수 계산, 렌더링
  pinball_style.dart 공통 색상, 재질 그리기, 접근성을 지원하는 도트 점수판
  boss_encounter.dart 시간 기반 보스 동작, 체력, 약점과 꽃잎
  moonlit_boss.dart   부위별로 따로 움직이는 보스 그림
  moonlit_table.dart  정원 배경, 달 문양과 보석 장애물 그리기

assets/
  fonts/             제품 폰트와 라이선스
  images/moonlit/    정원, 투명 보스 부품 그림과 제작 기록

test/
  features/          Gherkin 시나리오와 생성한 Flutter 위젯 테스트
  fonts/             컴퓨터 테스트 전용 폰트와 라이선스
  golden/            골든 테스트와 저장소에 포함하는 기준 이미지
  steps/             실행 가능한 Gherkin 단계 구현
  support/           공통 게임·위젯 테스트 환경
  widget_test.dart   반응형 배치, 접근성, 입력 회귀 테스트
```

## 아키텍처

Android 개발자 관점으로 보면 `main.dart`는 화면 표시·입력 레이어를 가진
Activity/Fragment에 가깝고, `pinball_game.dart`는 물리 엔진을 가진 사용자 정의
게임 뷰에 가깝습니다.

```mermaid
graph TD
  A[MonPinballApp] --> B[PinballScreen]
  B --> C["GameWidget of MonPinballGame"]
  B --> K[Dashboard instruments]
  C --> D[MonPinballGame]
  C --> E[PinballHud overlay]
  E --> F[Pointer input routing]
  F --> D
  D --> G[Forge2DWorld]
  G --> H[BodyComponent objects]
  H --> I[Ball, rails, flippers, bumpers, targets]
  D --> J[ValueNotifier<PinballSnapshot>]
  J --> K
```

### 레이어별 역할

| 레이어 | 파일 | 역할 |
| --- | --- | --- |
| 앱 기본 화면 | `lib/main.dart` | `MaterialApp`, 화면 구성, `GameWidget` 연결 |
| 계기판 | `lib/main.dart` | 게임 표시 영역 밖의 반응형 점수·남은 공·상태·발사 충전 표시 |
| 터치 입력 | `lib/main.dart` | 포인터 누르기·이동·놓기, 발사대 끌기 추적, 플리퍼 누름 상태 |
| 게임 상태 | `lib/pinball_game.dart` | 점수, 남은 공, 발사 충전, 게임 종료, 계기판 상태 스냅샷 |
| 물리 월드 | `lib/pinball_game.dart` | Forge2D 중력, 바디, 충돌 도형, 충돌 콜백 |
| 게임판 렌더링 | `lib/pinball_game.dart` | 배경, 레일, 범퍼, 슬링샷, 공, 효과 |

### 화면 표시와 입력 레이어

이전 `PinballHud`는 `Stack`으로 터치 리스너와 보이는 계기판을 게임 위에
겹쳐 놓았습니다. 현재 계기판은 게임 표시 영역 밖에 배치합니다. 세로 화면에서는
위쪽, 넓은 화면에서는 오른쪽에 놓아 게임판을 가리지 않도록 합니다.

현재 `PinballHud`에는 터치 리스너만 남아 있습니다. `LayoutBuilder`는 이전에도
`Stack` 안에 있었으며, 감싸던 `Stack`을 제거하면서 최상위가 됐습니다.
실제 게임 표시 영역의 너비를 구해 왼쪽·오른쪽 터치를 구분하고, 포인터 좌표도
그 영역 내부 좌표를 유지합니다. 계기판 배치가 바뀌어도 게임 인스턴스는
계속 유지됩니다.

## 실행 흐름

Flame은 프레임마다 `update(dt)`와 `render(canvas)`를 호출합니다. 게임
프레임워크가 Android의 `Choreographer`와 사용자 정의 `View.onDraw()`에
해당하는 호출 일정과 그리기를 관리합니다.

```mermaid
sequenceDiagram
  participant Flutter as Flutter Widget Tree
  participant GameWidget as Flame GameWidget
  participant Game as MonPinballGame
  participant World as Forge2DWorld
  participant HUD as Dashboard instruments

  Flutter->>GameWidget: build()
  Flutter->>Game: create MonPinballGame once in PinballScreen
  GameWidget->>Game: onLoad()
  Game->>World: add rails, bumpers, flippers, ball
  Game->>HUD: publish PinballSnapshot

  loop every frame
    GameWidget->>Game: update(dt)
    Game->>World: physics step
    World->>World: resolve contacts
    Game->>Game: drain check, launcher charge update
    Game->>HUD: ValueNotifier update if state changed
    GameWidget->>Game: render(canvas)
  end
```

## 주요 클래스

### `MonPinballGame`

`MonPinballGame`은 `Forge2DGame`을 상속하는 중앙 게임 컨트롤러입니다.

역할:

- `28 x 48` 고정 크기의 게임판 월드 생성
- 점수, 남은 공, 발사 충전, 상태, 게임 종료 여부 관리
- `ValueNotifier<PinballSnapshot>`으로 계기판 상태 전달
- Flame의 `KeyboardEvents`로 키보드 입력 처리
- 레일, 범퍼, 표적, 플리퍼, 발사대, 공 생성
- 공이 게임판 아래로 떨어졌는지 감지

주요 메서드:

| 메서드 | 용도 |
| --- | --- |
| `onLoad()` | 물리 월드 초기화 및 컴포넌트 생성 |
| `onGameResize()` | 고정 크기 월드를 현재 화면에 맞춤 |
| `update(dt)` | 프레임별 발사 충전 갱신 및 공 이탈 감지 |
| `isLauncherTouch()` | 화면 좌표를 월드 좌표로 변환해 발사대 영역인지 확인 |
| `launcherChargeFromDrag()` | 아래로 끈 거리를 `0.0..1.0` 충전량으로 변환 |
| `releaseLauncher()` | 발사대에서 대기 중인 공에만 발사 속도 적용 |
| `addScore()` | 점수 갱신 및 파동 효과 생성 |
| `restartGame()` | 점수·남은 공·공·발사대 상태 초기화 |

### `PinballHud`

`PinballHud`는 Flame 캔버스 위에 놓이는 투명한 Flutter 입력 레이어입니다.
별도 계기판은 `ValueListenableBuilder`로 `MonPinballGame.hud`의 변경을 받아
게임판을 가리지 않고 표시 내용을 갱신합니다.

`PinballHud`의 터치 입력 분배:

- 왼쪽 절반: 왼쪽 플리퍼
- 발사 레인을 제외한 오른쪽 절반: 오른쪽 플리퍼
- 오른쪽 발사 레인: 발사대 끌기

포인터 입력은 Flutter 오버레이에서 처리하고, 게임 동작은 `MonPinballGame`에
위임합니다. 화면 관련 처리가 물리 클래스에 섞이지 않도록 분리한 구조입니다.

### 물리 컴포넌트

대부분의 게임판 객체는 `BodyComponent<MonPinballGame>`을 상속합니다.
`BodyComponent`는 Flame과 Forge2D를 연결하며, Forge2D `Body`를 소유하고
이를 렌더링하며 Flame 컴포넌트 트리에서 갱신됩니다.

| 클래스 | 바디 종류 | 용도 |
| --- | --- | --- |
| `PinballBall` | 동적 | 중력, 충격량, 충돌의 영향을 받는 공 |
| `TableRail` | 정적 선분 | 게임판 경계와 레인 레일 |
| `Flipper` | 운동학적 | 플레이어가 회전을 조작하는 플리퍼 |
| `Bumper` | 정적 원 | 점수를 주고 공을 밀어냄 |
| `Spinner` | 정적 다각형 | 점수를 주고 회전 반응을 표시 |
| `DropTarget` | 정적 다각형 | 표적 타격 점수 부여 |
| `Slingshot` | 정적 다각형 | 플리퍼 근처의 삼각형 반발 구역 |
| `LaunchLaneExit` | 정적 센서 | 발사 레인을 나온 공을 게임판 쪽으로 밀어줌 |
| `LauncherView` | 시각 표현 전용 | 발사대 트랙과 충전 위치를 그림 |
| `PulseRing` | 시각 표현 전용 | 일시적인 점수 타격 효과 |

## 입력 흐름

### 터치: 플리퍼와 발사대

```mermaid
sequenceDiagram
  participant User
  participant HUD as PinballHud Listener
  participant Game as MonPinballGame
  participant Flipper
  participant Ball

  User->>HUD: pointer down
  HUD->>Game: isLauncherTouch(screen position)

  alt pointer is in plunger lane
    HUD->>Game: startLauncherCharge(timed: false)
    HUD->>Game: setLauncherDragCharge(0)
    User->>HUD: drag downward
    HUD->>Game: launcherChargeFromDrag(start, current)
    HUD->>Game: setLauncherDragCharge(charge)
    User->>HUD: pointer up
    HUD->>Game: releaseLauncher()
    Game->>Ball: launch(power)
  else left screen
    HUD->>Game: setLeftFlipper(true)
    Game->>Flipper: isPressed = true
    User->>HUD: pointer up
    HUD->>Game: setLeftFlipper(false)
  else right screen outside plunger lane
    HUD->>Game: setRightFlipper(true)
    Game->>Flipper: isPressed = true
    User->>HUD: pointer up
    HUD->>Game: setRightFlipper(false)
  end
```

### 키보드

```mermaid
sequenceDiagram
  participant Keyboard
  participant GameWidget
  participant Game as MonPinballGame

  Keyboard->>GameWidget: key event
  GameWidget->>Game: onKeyEvent(event, keysPressed)
  Game->>Game: A/Left sets left flipper
  Game->>Game: D/Right sets right flipper
  Game->>Game: Space/Down/S charges or releases launcher
  Game->>Game: W/Up nudges ball
  Game->>Game: R restarts game
```

## 발사대 알고리즘

모바일 발사대는 누른 시간 대신 끈 거리를 사용합니다. 실제 스프링을 당기는
느낌에 가깝게 조작하도록 한 선택입니다.
머리 부분이 고정된 받침대 쪽으로 내려가면서 용수철이 압축됩니다. 충전과
발사는 대기 중인 공에만 적용되며, 비행 중에는 발사대를 조작해도 충전·재발사·
추가 추진이 발생하지 않습니다.

```text
onPointerDown(position):
  if position is inside launcher lane and ball is waiting:
    remember drag start position
    set charge to 0
    mark action as launcher
  else if x is left half:
    press left flipper
  else:
    press right flipper

onPointerMove(position):
  if current action is launcher and ball is waiting:
    startWorld = screenToWorld(dragStart)
    currentWorld = screenToWorld(position)
    charge = clamp((currentWorld.y - startWorld.y) / 6.2, 0, 1)
    update HUD charge
    update LauncherView.charge

onPointerUp:
  if current action is launcher and ball is waiting:
    power = max(charge, 0.2)
    ball.velocity = Vector2(0, -55 - 48 * power)
    reset charge to 0
```

`currentWorld.y - startWorld.y`를 사용하는 이유:

- 게임판 좌표에서 `y`가 클수록 아래쪽입니다.
- 손가락을 아래로 끌면 `y`가 증가합니다.
- 이 차이를 스프링의 당김 강도에 자연스럽게 대응시킬 수 있습니다.

## 공 발사와 레인 출구

발사 레인은 게임판 오른쪽에 있습니다. 공은 레인 아래쪽에서 시작해 발사 시
위로 이동합니다. 레인 위쪽은 넓게 만들었으며, `LaunchLaneExit` 센서가 공을
왼쪽 게임판으로 밀어줍니다.
공은 처음 시작하거나 공을 잃거나 다시 시작한 뒤 발사 전까지 고정됩니다.
최소 발사력으로도 연타 없이 상단 출구에 도달하도록 발사 속도를 정했습니다.

```mermaid
graph TD
  A[Ball starts at x=25, y=43] --> B[Player drags plunger down]
  B --> C[releaseLauncher]
  C --> D[PinballBall.launch]
  D --> E[Ball moves upward in right lane]
  E --> F[LaunchLaneExit sensor near top]
  F --> G[Steer left and preserve upward speed]
  G --> H[Ball enters playfield]
```

센서의 충돌 도형은 `isSensor: true`이므로 공을 물리적으로 막지 않습니다.
상승 중인 공의 위쪽 속도는 유지하면서 왼쪽으로 방향을 바꿔 안쪽 레일을
넘어가게 합니다. 짧은 재작동 대기 시간으로 반복 방향 전환을 방지합니다.

## 충돌과 점수 계산

Forge2D의 접촉 콜백은 `ContactCallbacks`로 전달됩니다. 점수를 주는 객체는
`ContactCallbacks`를 믹스인하고 `beginContact`를 구현합니다.

```mermaid
sequenceDiagram
  participant World as Forge2DWorld
  participant Object as Bumper/Target/Spinner/Slingshot
  participant Game as MonPinballGame
  participant HUD as Dashboard instruments

  World->>Object: beginContact(other, contact)
  Object->>Object: verify other is PinballBall
  Object->>Game: addScore(points, position, color, reason)
  Game->>Game: score += points
  Game->>World: add PulseRing effect
  Game->>HUD: publish PinballSnapshot
```

점수 계산의 보호 장치:

- 범퍼, 스피너, 표적은 짧은 재작동 대기 시간으로 한 번의 접촉에서 점수가
  과도하게 반복되는 것을 방지합니다.
- `gameOver` 상태에서는 새 점수를 반영하지 않습니다.
- 타격 효과는 별도 `PulseRing` 컴포넌트이므로 점수 계산이 화면 오버레이의
  렌더링에 의존하지 않습니다.

## 플리퍼 알고리즘

플리퍼는 Forge2D의 운동학적 바디입니다. 현재는 회전 관절 대신 각속도를
설정해 목표 각도로 회전시킵니다.

```text
update(dt):
  targetAngle = isPressed ? activeAngle : restAngle
  delta = targetAngle - currentAngle

  if abs(delta) is small:
    angularVelocity = 0
    snap transform to targetAngle if world is not locked
  else:
    angularVelocity = clamp(delta * 24, -24, 24)
```

절충점:

- 첫 버전에서 사용하기에 단순하고 충분히 안정적입니다.
- 더 사실적인 물리 반응이 필요하면 Forge2D `RevoluteJoint`와 모터 제한으로
  교체할 수 있습니다.

## 공 이탈과 초기화 흐름

```mermaid
sequenceDiagram
  participant Game as MonPinballGame
  participant Ball as PinballBall
  participant HUD as Dashboard instruments

  Game->>Game: update(dt)
  Game->>Ball: check ball.position.y
  alt y > boardHeight + 4
    Game->>Game: lives -= 1
    alt lives <= 0
      Game->>Game: gameOver = true
      Game->>Game: reset ball to launcher
    else lives remain
      Game->>Game: reset ball to launcher
    end
    Game->>HUD: publish PinballSnapshot
  end
```

## 좌표계

게임은 고정 크기의 월드를 사용하고 화면 크기에 맞춰 카메라 배율을 조정합니다.

```text
월드 크기: 28 x 48
원점: 게임판의 왼쪽 위쪽을 기준으로 하는 좌표 공간
x는 오른쪽으로 증가
y는 아래쪽으로 증가
카메라: 게임판 중앙에 위치
배율: min(screenWidth / 28, screenHeight / 48) * 0.96
```

물리 설정은 휴대폰 해상도에 영향을 받지 않습니다. 발사 레인 판정 시 Flutter의
포인터 위치를 월드 좌표로 변환합니다.

## 현재 제약

- 플리퍼는 관절 모터 대신 각도로 제어하는 운동학적 바디입니다.
- 아직 소리가 없습니다.
- 이미지 자산 없이 모든 그림을 Canvas 기본 도형으로 그립니다.
- 게임판 배치는 월드 좌표로 코드에 직접 지정되어 있습니다.
- 물리 회귀 테스트는 발사와 공 이탈 상태를 검증하며, 세부 충돌 점수는 아직
  테스트로 다루지 않습니다.

## 향후 개선 후보

1. 게임판이 커지면 `pinball_game.dart`를 `components/`, `input/`, `state/`로 분리
2. 더 사실적인 물리 반응을 위해 플리퍼에 `RevoluteJoint`와 모터 제한 적용
3. `flame_audio`로 소리 효과 추가
4. 재현 가능한 Forge2D 물리 테스트를 충돌 점수 검증으로 확장
5. 컴포넌트 코드를 수정하지 않고 레벨을 조정할 수 있도록 게임판 좌표를 데이터로 분리

## 최초 커밋 체크리스트

```sh
flutter analyze
flutter test
git init
git add .
git commit -m "Initial Flame pinball game"
```
