# Balance validation

2026-10-29. Repeated diagnostic players use the production launcher and flippers,
gravity and collisions. During measured episodes no ball position, score, shield,
health or damage is injected. Progress is memory-only; stage unlocks and any
explicitly labelled experimental rule values are prepared before each scenario.
The measured time is simulated game time at 60 frames per second. These players
are reproducible diagnostics and are not calibrated human skill models.

## Reproduce

```sh
flutter test --no-pub --dart-define=BALANCE_LABEL=baseline-normal test/balance_playthrough.dart
```

Defaults: nine NORMAL stages, eight seeds, four policies, a 180-second episode
cap (288 episodes). Policies are launch-only, periodic simultaneous pulses,
reactive pulses and predicted-intercept pulses. Seeded launch schedules are
independent of policy. Results include censored timeouts, score labels, loss
traces, mission hits and naturally occurring boss exposures. Every tenth hit's
label is replaced by the combo announcement; its base score is recorded as
unlabelled instead of attributing a guessed source.

Parameters: `BALANCE_RUNS`, `BALANCE_SECONDS`, `BALANCE_STAGES`,
`BALANCE_DIFFICULTIES`, `BALANCE_POLICIES`, `BALANCE_MODE`. Explicit pre-run
rule experiments use `BALANCE_TARGET`, `BALANCE_EXPOSURE_MS` or
`BALANCE_BOSS_HEALTH`; their values are
recorded in each result and do not represent the production rules.

Local raw results are saved under `build/qa/balance/<label>.json`.

## Baseline and experiments

Base production commit: `9daa248`. All 288 clean NORMAL baseline episodes ran;
the nine benchmark cases passed. A preliminary baseline artifact marked
`preflight-invalid` is excluded because later-stage memory unlocks were initially
missing and clear-record callbacks raised errors. The loader was fixed with a
failing-then-passing regression before the clean baseline was rerun.

| Scenario | Launch only | Three control policies | Observed implication |
| --- | --- | --- | --- |
| Neon 12-combo stage | 8/8 clear, median 4.0s | 24/24 clear, medians about 4.0s | Completes during automatic launch rally |
| Neon experimental 30-combo stage | 8/8 clear, median 15.9s | 24/24 clear | Adds time but little survival demand |
| Neon experimental 60-combo stage | 4/8 clear | 23/24 clear, medians 22–34s | Creates a stronger control/survival distinction |
| Garden boss | 0/8 clear | 5/24 clear | Intro boss is harder than the neon boss under these policies |
| Neon boss | 3/8 clear | 18/24 clear | Existing accelerator route supports upper-field return |
| Abyss boss | 0/8 clear | 1/24 clear | Low return/damage opportunities warrant route investigation |

Increasing exposure to seven seconds alone did not help: same-policy garden
clears changed from 5/32 to 4/32 and abyss from 1/32 to 0/32. For 126 fully
observed lower-field abyss openings, only 23 reached `y<16` within eight seconds;
59 did not reach `y<30`. This supports investigating the route before increasing
the timer or reducing health. An earlier-reacting control model did not remove
the garden/abyss gap.

The initial garden score stage remained an intentionally forgiving introduction:
all launch-only runs cleared, with control policies finishing sooner and often
using fewer balls. No single-device unlimited scoring loop was confirmed in the
sample.

## 최종 조정과 비교 결과

조정은 네 곳이며, 기존 해금과 저장 기록은 유지합니다.

| 항목 | 조정 전 | 최종 동작과 이유 |
| --- | --- | --- |
| 정원 수련 발사 | 수직 속도 -30 | -50으로 올려 실제 보석 배치를 지나 상단에 도달하도록 변경. 좌우 발사 모두 실제 중력에서 검증 |
| 심해 달 범퍼 | 중심 `(14,36.8)`, 반지름 2.5 | 중심 `(10.5,36.8)`, 반지름 2.0. 중앙 귀환 경로를 열고 필수 타깃 위에도 공이 통과할 간격을 확보 |
| 네온 2-2 | 12콤보 | 60콤보. 12는 발사 랠리 중 약 4초에 끝났고, 30 실험도 발사만으로 전부 완료. 60은 조작 시 23/24, 발사만 할 때 4/8 완료 |
| 쉬움 심해 보스 | 체력 9,600 | 쉬움에서만 6,400. 비교 실행에서 7/24→12/24 완료. 보통·어려움은 9,600 유지 |

보통 난이도에서 같은 8개 시드와 네 조작 모델로 비교한 보스 결과입니다.

| 보스 | 조정 전 완료 | 조정 후 완료 |
| --- | --- | --- |
| 정원 | 5/32 | 20/32 |
| 네온 | 21/32 | 21/32 |
| 심해 | 1/32 | 4/32 |

발사만 하는 모델을 제외한 세 조작 모델의 최종 난이도별 결과입니다.
각 칸은 8개 시드 × 3모델이며, 심해 쉬움은 최종 제품 설정으로 따로 재실행했습니다.

| 난이도 | 정원 | 네온 | 심해 |
| --- | --- | --- | --- |
| 쉬움 | 22/24 | 20/24 | 12/24 |
| 보통 | 17/24 | 18/24 | 4/24 |
| 어려움 | 11/24 | 8/24 | 2/24 |

심해의 하단 개방 후 8초를 관측한 사례에서 상단 `y<16` 도달은
23/126→66/147로 늘었습니다. 여기서 하단은 개방 위치 `y>=30`, 완전한
8초 관측은 프레임 반올림을 고려해 `followupSeconds>=7.999`로 집계했습니다.
위치는 보드 좌표이며 작은 `y`가 더 위입니다.

체력 8,000·6,400 실험은 각각 난이도 세 개에서 총 72회 수행했습니다.
보통의 체력 감소 효과는 일관적이지 않아 유지했고, 쉬움에서 확인된
완화만 반영했습니다. 노출 시간을 일괄 7초로 늘리는 안은 채택하지 않았습니다.

## 실행한 최종 검증

- 주요 코호트는 컴퓨터에서 누적 1,560회입니다. 같은 시드를 재사용하는
  비교 실행이므로 독립적인 플레이어 1,560명의 결과를 뜻하지 않습니다.
  로그 형식 검사용 자연 플레이 1회는 별도입니다. 실패한 사전 실행과
  공의 초기 위치·속도를 지정한 49개 수련 궤적 실험은 이 수에 포함하지 않았습니다.
- 전체 기본 테스트 202개 통과, 정적 분석 문제 없음. 실제 경로·좌우 수련
  발사·정지 위험·월드 전환 충돌 형상·60콤보·쉬움 심해 자연 완주 회귀를 포함합니다.
- 세 월드의 실제 게임 화면 캡처 검사 3개가 통과했고 직접 확인했습니다.
- Galaxy SM-M336K에서 보통·쉬움의 세 보스를 두 조작 모델과 두 시드로
  24회 측정했습니다. 14회 완료했고, 대응하는 컴퓨터 실행의 완료 여부·시간·점수·
  소모 공과 24/24 일치했습니다. 이는 사람의 터치 완주가 아니라 실제 기기의
  실제 앱 코드와 조작 함수를 사용하는 고정 시간 단계 자동 플레이입니다.
- Android가 긴 콘솔 행을 자르므로 이번 기기 자료는 노출 배열 앞까지의
  완전한 핵심 항목을 복원했습니다. 기기 전체 노출·손실 궤적을 보존했다고
  주장하지 않습니다. 후속 출력은 짧은 독립 JSON 행으로 변경했고 한 판으로
  형식과 결과 보존을 확인했습니다. 컴퓨터 원자료는 전체 상세 항목을 보관합니다.
- Android Studio의 JBR(JetBrains Runtime)로 일반 앱 빌드 성공 후 Galaxy에
  설치했습니다. 일반 앱에서 쉬움 심해의 공 5개·체력 6,400과 새 범퍼 배치를
  확인하고, 직접 발사·양쪽 플리퍼로 35,000점까지 진행했습니다. 이 짧은 직접
  플레이에서 보스 피해나 완주는 관찰하지 않았습니다.
- 일시정지와 재시작을 확인하고 쉬움 심해를 점수 0·공 5개의 발사 대기 상태로
  남겼습니다. 해당 일반 앱의 Flutter/AndroidRuntime 오류 필터 결과는 비어 있었습니다.
- 독립적인 코드·원자료 검토에서 중대한 제품 결함은 발견되지 않았습니다.
  검토에서 지적한 관측 구간 집계 두 곳은 원자료의 명시한 기준으로 수정했습니다.

## 해석의 한계

자동 모델의 완료율은 사람의 완료율 추정치가 아닙니다. 모델은 목표 조준,
공 받기와 상황별 발사 선택을 학습하지 않으며 기울이기도 사용하지 않습니다.
180초 제한은 살아 있는 플레이를 중단할 수 있으므로 실제 실패와 구분합니다.
표본에서 무한 득점이나 정지를 확인하지 못했어도 모든 궤적의 부재를 증명하지는
않습니다. 심해 보통·어려움은 여전히 가장 낮은 완료율을 보였으며, 사람의
완주와 주관적인 조작감에 대한 추가 피드백이 필요합니다.
