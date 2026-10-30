# 연결·실행·시연 안내

## 1. Gemini API 키

1. https://aistudio.google.com/apikey 에서 본인 Google 계정으로 키를 발급합니다.
2. 무료 할당량을 우선 사용합니다. 이 프로젝트를 위해 유료 결제를 자동으로 켜지 않습니다.
3. 비밀 설정의 `GEMINI_API_KEY`에 입력합니다. 모델은 `GEMINI_MODEL`로 바꿀 수 있습니다. 기본값은 현재 공식 문서의 `gemini-3.8-flash`입니다. 실제 계정에서 지원하는지 반드시 확인하세요.
4. https://ai.google.dev/gemini-api/docs/video-understanding 에서 지원 형식/한도를 확인할 수 있습니다.

## 2. 카카오 API 키

1. https://developers.kakao.com 에서 내 애플리케이션을 생성합니다.
2. 앱 키에서 REST API 키 → `KAKAO_REST_API_KEY`, JavaScript 키 → `KAKAO_JAVASCRIPT_KEY`를 설정합니다. 서로 다른 키입니다.
3. 콘솔에서 카카오맵 사용 설정을 활성화합니다. `disabled OPEN_MAP_AND_LOCAL service`가 나오면 키를 바꾸는 대신 이 설정을 확인하세요.
4. **앱 > 플랫폼 키 > JavaScript 키 > JavaScript SDK 도메인**에 로컬 주소와 배포 주소를 등록합니다. REST API 키의 호출 허용 IP 칸에 URL을 넣지 마세요. IP 설정과 도메인 등록은 별개입니다.
   - `http://localhost:8787`
   - 배포된 체험판의 origin (사이트 주소에서 경로를 제외)
5. 카카오 REST 키는 서버에만 존재합니다. JavaScript 키는 지도 SDK에 제공하는 공개 식별자이므로 브라우저에 전달되며 도메인 제한이 중요합니다.
6. 공식 문서: https://developers.kakao.com/docs/latest/ko/local/dev-guide / https://apis.map.kakao.com/web/guide/

현재 대화에서 비밀 설정을 입력하는 파일은 제출 소스 바깥의 `work/reelmap.env`입니다. `.env.local`과 함께 저장소/ZIP에 넣지 마세요. API 비밀 키를 채팅이나 발표 슬라이드에 붙여넣지 마세요.

## 3. 웹 체험판

- Gemini/카카오/체험 코드 값은 배포 환경 변수에도 설정해야 합니다. 로컬 파일 작성만으로 배포 서버에 반영되지 않습니다.
- API 키가 없는 상태에는 상단에 설정 미완료가 표시됩니다.
- 서버 비밀 설정이 바뀌면 같은 소스를 다시 배포해 새 설정을 적용합니다. 현재 체험판은 사용자 승인에 따라 공개 상태입니다. 화면 접속에 계정 로그인이 필요하지 않습니다.
- 평가자에게 웹 주소와 체험 코드를 전달합니다. 각자의 브라우저에 데이터가 저장되며 서로의 지도는 공유되지 않습니다.
- ‘설정·연결 상태’에 **설정됨**은 값 존재 여부입니다. API 인증 성공을 의미하지 않습니다. 첫 실제 분석과 검색으로 확인하세요.

## 4. iOS 실행

1. Mac App Store에서 Xcode를 설치하고 최초 실행·SDK 설치를 마칩니다.
2. `ios/ReelMap.xcodeproj`를 엽니다. `ReelMap` 스킴을 선택합니다.
3. 앱과 `ReelMapShare` 두 타깃의 Signing & Capabilities에서 본인 Team, 고유 Bundle ID를 지정합니다. 앱의 Bundle ID 접두어 안에 확장 Bundle ID가 있어야 합니다.
4. 지원되는 서명/프로비저닝으로 두 타깃에 동일한 App Group을 연결합니다. 현재 값은 `group.com.course.reelmap`이며, 프로젝트 `APP_GROUP_ID`를 본인 그룹으로 변경합니다.
5. 공유 확장과 본 앱의 데이터 공유는 **App Group이 실제로 연결되어야** 동작합니다. 무료 Personal Team에서 해당 capability를 지원하지 않으면 공유 저장을 실행할 수 없습니다. 가입/유료 결제는 자동으로 진행하지 않습니다.
6. 앱 내 설정의 App Group 연결 상태를 확인합니다. 미연결 상태에서 본 앱은 앱 전용 저장 공간을 사용하며, 공유 확장은 저장 성공으로 표시하지 않고 오류를 보여줍니다.
7. 앱과 확장의 `API.base`는 배포 URL입니다. 주소가 달라지면 `Shared/Models.swift`를 수정합니다.
8. 아이폰을 연결하고 개발자 모드를 활성화한 뒤 실행합니다. 인스타그램 → 공유 → 더 보기 → ‘릴맵에 저장’을 선택합니다. 실제 인스타 버전에 따른 공유 목록 노출은 실기기 검증이 필요합니다.
9. 체험 코드가 설정된 서버라면 본 앱 분석 화면과 공유 확장 화면에 각각 입력해야 합니다. 두 화면의 AppStorage는 별도입니다.

Xcode 27.1에서 시뮬레이터용 `xcodebuild`는 성공했습니다. 실기기 서명, IPA 생성·설치 성공을 의미하지 않습니다.

```sh
xcodebuild -project ios/ReelMap.xcodeproj -scheme ReelMap \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## 5. 시연 시나리오

- 첫 번째 제공 릴스: `https://www.instagram.com/reel/DF7oYUjB3jw/`
  - 실제 본문 확보 검사에서 산와쇼텐과 마포구 주소 확인.
  - 카카오에서 이름·주소의 유일한 일치가 확인되어야 자동 저장.
- 두 번째 제공 릴스: `https://www.instagram.com/reel/DB8o_fgSXB7/`
  - 실제 본문 확보 검사에서 식당 9곳과 샤워기 광고 구분.
  - 광고는 저장 대상에서 제외하고 원하는 식당만 선택.
- 별도로 처음 보는 공개 릴스 한 개를 입력해 결과와 원본 비교.
- 영상에만 식당명이 있으면 실제 MP4/MOV/WebM을 첨부해 자막·음성 추출 확인.
- 잘못된 링크/가져오기 제한 → 확인 필요 → 직접 검색·연결.
- 현재 위치 권한 허용/거부 → 주변 거리 정렬/목록 유지.
- 웹 페이지 새로고침 → 저장 유지 → JSON 백업·복원.

## 기술적 범위

- 인스타 로그인 쿠키나 비공개 계정 콘텐츠를 사용하지 않습니다. 공개 HTML도 요청 지역·IP·인스타 정책에 따라 차단될 수 있습니다.
- 링크에서 영상 메타데이터를 얻지 못하면 본문만 분석한 것으로 표시합니다. 영상·이미지를 추가하면 멀티모달 분석을 시도합니다. 12MB 초과 파일은 줄여야 합니다.
- iOS의 주변 위치/목록/분석/설정은 SwiftUI이고 지도 영역만 WKWebView로 카카오 JavaScript SDK를 표시합니다. 네이티브 카카오 지도 SDK를 통합한 버전은 아닙니다.
- 인스타 공유 작업은 확장 화면이 열려 있는 동안 처리합니다. 화면을 닫아도 계속 분석하는 백그라운드 작업은 구현하지 않았습니다.

## 본문 우선과 전체 분석

기본값에서는 본문을 먼저 분석하고 카카오에서 모든 식당의 이름·주소가 확인되면 파일 분석을 생략합니다. 확인되지 않은 식당이 있으면 첨부 파일로 보완합니다. 웹의 추가 자료 입력 영역 또는 iOS 첨부 파일 아래 ‘첨부 파일까지 분석’을 켜면 본문이 충분해도 파일을 직접 분석합니다.
분석 완료 후 입력·답변·추론·합계 토큰을 표시합니다. 두 단계가 실행되면 측정된 사용량을 합산하며, 측정 정보가 없으면 수치를 만들지 않습니다. 카카오 지도/API 비용은 Gemini 토큰에 포함되지 않습니다.
