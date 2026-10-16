# Android와 iOS를 같은 저장소에서 관리하기

현재 통합 브랜치는 `flight-search-wip`입니다. Android 작업 컴퓨터와 Mac에서
이 브랜치를 사용하면 공통 기능을 파일이나 ZIP으로 복사할 필요가 없습니다.
`lib/`, `assets/`는 공유하고, 네이티브 설정은 `android/`, `ios/`에 각각 유지합니다.
결제와 광고의 플랫폼별 동작은 Dart 코드에서 `Platform.isAndroid` / `Platform.isIOS`로
선택합니다. 공통 파일 전체를 Android용 또는 iOS용으로 덮어쓰지 않습니다.

## 작업 시작 시 최신 코드 받기

각 컴퓨터에서 최초 한 번 같은 저장소를 clone하고 `flight-search-wip` 브랜치를
checkout합니다. 기존 작업 폴더가 있으면 먼저 변경 사항을 커밋하고, 원격 저장소가
`https://github.com/shinduhyung/travelog`인지 확인합니다.

이후 프로젝트 폴더에서 실행합니다. Python 3와 Git이 필요합니다.

```sh
python3 scripts/sync_project.py
flutter pub get
```

Windows에서 `python3` 명령이 없으면 `py -3 scripts/sync_project.py`를 사용합니다.
동기화 스크립트는 현재 브랜치의 upstream을 fetch하고 fast-forward로 업데이트합니다.
로컬 변경이 있거나 양쪽에서 새 커밋을 만든 경우에는 중단하므로 작업을 덮어쓰지 않습니다.
이 경우 변경 내용을 확인해 병합해야 합니다. 의미가 다른 코드의 충돌까지 무조건
자동 해결하는 도구는 아닙니다. GitHub 인증은 각 컴퓨터에 별도로 설정해야 합니다.

## 기능 수정 후 다른 컴퓨터로 전달

관련 파일만 선택해 커밋합니다. 개인 키와 `.env`는 포함하지 않습니다.

```sh
git add lib/ assets/
git commit -m "feat: update regional features"
git push origin flight-search-wip
```

다른 컴퓨터에서는 위 동기화 스크립트를 실행하면 됩니다.
같은 파일을 두 컴퓨터에서 동시에 수정하기 전에 반드시 먼저 동기화합니다.
큰 기능은 `codex/기능명` 같은 작업 브랜치에서 수정하고 통합 브랜치로 병합합니다.
Android와 iOS의 장기 브랜치를 따로 두기보다는 이 공통 브랜치에서 함께 관리하면
동일 기능을 두 번 병합하는 일을 줄일 수 있습니다. 별도 출시 브랜치가 필요하면
검증된 공통 커밋에서 분기하고, 플랫폼별 출시 수정만 좁게 유지합니다.

## 플랫폼별 버전과 빌드

`platform_versions.json`은 기존 Android `1.0.1+90`, iOS `1.0.27+1`을 각각 보존합니다.
새 출시 시 각 스토어의 최신 업로드보다 높은 번호로 해당 항목을 수정합니다.
공통 `pubspec.yaml`의 버전을 플랫폼마다 번갈아 수정할 필요가 없습니다.

```sh
python3 scripts/build_platform.py android
python3 scripts/build_platform.py ios
```

Android는 AAB, iOS는 IPA를 생성합니다. iOS 빌드는 Mac과 Xcode가 필요하며,
각 플랫폼의 SDK·서명 설정과 로컬 `.env` 등은 먼저 준비해야 합니다.
스크립트는 스토어에 업로드하거나 배포하지 않습니다.

실제 빌드 없이 명령만 확인하거나 버전을 일시적으로 지정할 수도 있습니다.

```sh
python3 scripts/build_platform.py android --dry-run
python3 scripts/build_platform.py ios --build-name 1.0.28 --build-number 2 --dry-run
```

Apple API 개인 키(`functions/SubscriptionKey_*.p8`), `.env`, Android 서명 키는
Git 대신 각 컴퓨터와 배포 환경에 별도로 보관합니다. 동기화 스크립트가 이 파일들을
다른 컴퓨터로 전달하지는 않습니다.
