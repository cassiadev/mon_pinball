# Mon Pinball 앱 아이콘

`source.png`는 각 플랫폼 아이콘을 만드는 원본입니다.

macOS에서 저장소 루트를 기준으로 생성합니다.

```sh
swift tool/generate_app_icons.swift
```

각 플랫폼 프로젝트의 아이콘을 갱신하며, 별도 스토어 제출용 파일은 Git에서 제외된 `build/app-icons/`에 생성합니다.

규격과 원본 보존 여부를 검사하려면 Python 3와 Pillow가 있는 환경에서 실행합니다.

```sh
python3 tool/verify_app_icons.py
```

검사는 선택 사항이며 앱 빌드·실행에는 필요하지 않습니다.
