# LLM 적용 방식

2026-10-15 작성: LLM을 앱에 맞추는 일반적인 방법을 정리하고, TripDNA에 어떻게 적용할지 계획 초안을 적었다.

상태: 학습 정리와 적용 계획 **초안**. 결정 문서가 아니다. 추천의 흐름·책임·미정 항목은 [추천 구조](../recommendation/README.md)가 담당하며, 이 문서와 어긋나면 그쪽을 따른다. 앱에는 아직 LLM 호출 코드가 없고, 호출은 `scripts/`의 Python 실험에만 있다(2026-10-15 확인).

## 1. 개념: ML과 무엇이 다른가

LLM 앱에서는 모델을 학습시키지 않는다. 이미 학습된 모델을 API로 부르고, **무엇을 넣고(context) 무엇을 시키고(prompt) 어떤 형태로 받는지(schema)**를 설계한 뒤 eval로 측정한다.


| 고전 ML                  | LLM 앱                         |
| ---------------------- | ----------------------------- |
| 모델 학습                  | 거의 하지 않음                      |
| 모델 선택                  | 모델 고르기(비용·지연·품질)              |
| feature selection      | context 설계: 프롬프트에 넣을 정보와 뺄 정보 |
| 하이퍼파라미터 튜닝             | 프롬프트 문구·예시·출력 형식·temperature  |
| validation set, metric | eval: 고정 입력 세트 + 채점 기준        |


## 2. 방법의 층 (보통 위에서부터 적용)

1. **System prompt**: 역할·규칙·금지·톤.
2. **Few-shot 예시**: 좋은 입력·출력 쌍. 규칙을 길게 쓰는 것보다 효과가 큰 경우가 많다.
3. **Structured output**: JSON schema로 응답 형식을 정하고 코드가 검증한다. 모델은 판단을, 코드는 ID·형식·계산을 맡는다.
4. **Context 주입 / RAG**: 앱 데이터를 매 호출에 넣는다. 데이터가 프롬프트에 다 들어가지 않을 때만 검색이나 vector DB로 골라 넣는다.
5. **Tool use**: 웹 검색 같은 도구. 실시간 사실이 필요할 때만 쓴다.
6. **Fine-tuning**: 위 방법으로 안 될 때의 마지막 수단. 수천 개 규모의 검수된 예시가 필요하다는 것이 실무 글의 공통 의견이다.
7. **Eval**: 위 모든 변경을 측정하는 장치. 없으면 프롬프트를 고쳐도 좋아졌는지 알 수 없다.

실무 글에서 반복되는 요약: 프롬프트는 지시, RAG는 지식, fine-tuning은 행동을 바꾼다. 셋은 서로를 대체하지 않는다.

## 3. TripDNA의 현재 위치


| 층                 | 설계 문서                                | 실험                                                     | 앱   |
| ----------------- | ------------------------------------ | ------------------------------------------------------ | --- |
| System prompt     | 추천 구조의 매칭·출처 원칙                      | `data/exploration/guidelines/`의 지침 블록                  | 없음  |
| Few-shot          | 정하지 않음                               | 정하지 않음                                                 | 없음  |
| Structured output | 흐름 3번이 응답 항목을 정함                     | 프롬프트에 "JSON만" 지시 → `json.loads` → `check_output` 형식 검사 | 없음  |
| 코드 검증             | 허용 ID·제외·조건 검사(흐름 4번)                | 형식·허용 ID 검사                                            | 없음  |
| Context           | 압축 도시 표·평가·제외·컨셉을 매번 전송, 도시 자료는 앱 번들 | 실행별 입력 구성 비교                                           | 없음  |
| RAG / vector DB   | 만들지 않기로 함                            | —                                                      | —   |
| Tool(검색)          | 자유문장에 사실 확인이 필요할 때만                  | 검색 사용 구성은 비교했으나 현재 구성(기본 미사용)은 미실험                     | 없음  |
| Fine-tuning       | 언급 없음                                | —                                                      | —   |
| Eval              | [평가 계획](../evaluation/README.md)     | 고정 케이스·실행 기록(`runs*`)                                  | —   |
| 호출 위치             | Cloud Functions 중계(API 키를 앱에 넣지 않음)  | PC에서 직접 호출                                             | 없음  |


설계 방향은 위 2절의 일반적인 순서와 대체로 일치한다. 아직 비어 있는 것은 few-shot, API 차원의 출력 형식 강제, 그리고 앱·서버 구현이다.

## 4. 적용 계획 (제안)

순서대로 진행하며, 앞 단계의 eval 결과가 나오기 전에 다음 단계로 넘어가지 않는다.

1. **응답 schema 확정.** 흐름 3번의 응답 항목(요청 이해 요약, 순위 도시, 도시별 이유·유의점·확인할 조건, 반영한 기억, 해석이 기대는 조건)을 JSON schema 하나로 적는다. 앱 카드와 코드 검증이 이 schema를 기준으로 삼는다.
2. **API 차원의 형식 강제.** 지금은 프롬프트 문구로 JSON을 요구하고 사후에 검사한다. 모델 API의 structured output 기능으로 schema를 강제하면 형식 실패와 그에 따른 재시도 문제가 줄어든다. 모델·제공자를 정할 때 함께 확인한다(현재 요금·지원 범위는 확인하지 않았다).
3. **프롬프트 버전 관리.** 프롬프트를 서버(Cloud Functions) 쪽 파일로 두고 버전 문자열을 붙인다. 이렇게 하면 앱 업데이트 없이 고칠 수 있다. 버전은 추천 결과의 입력 버전에 포함한다. 추천 구조의 "프롬프트 변경 시 결과 무효화" 규칙이 이 버전에 기대게 된다.
4. **Few-shot 시험.** 잘 쓴 카드 1~2개를 예시로 넣은 구성과 넣지 않은 구성을 같은 케이스로 비교한다. 예시 도시가 추천에 과하게 등장하는지도 함께 본다.
5. **Eval 고정.** 기존 고정 케이스와 실행 스크립트를 그대로 쓴다. 채점은 인상평 대신 루브릭(허용 ID, 제외 위반, 미확인을 단정했는지, 이유가 요청과 맞는지)으로 하고, 최소 한 단계는 사람이 직접 읽는다. 프롬프트·모델을 바꿀 때마다 같은 세트로 회귀 확인을 한다. promptfoo 같은 도구는 케이스와 구성이 늘어 스크립트 관리가 부담될 때 검토한다.
6. **검색 tool.** 기본 미사용 구성이 eval을 통과한 뒤, 자유문장에 사실 확인이 필요한 경우만 검색을 켜는 구성을 따로 잰다(비용·지연·품질).



## 5. 지금 하지 않는 것

- **Fine-tuning**: 검수된 예시가 수천 개 규모로 필요하고 모델이 바뀔 때마다 다시 해야 한다. 프롬프트·schema·eval로 해결되지 않는 형식이나 스타일 문제가 eval에서 반복 확인될 때 다시 본다.
- **RAG / vector DB**: 도시 100곳 규모의 압축 표는 프롬프트에 들어간다. 도시 수나 자료량이 커져 입력 비용·지연이 문제가 될 때 다시 본다.
- **다단계 에이전트**: 추천받기 한 번에 호출 한 번이라는 설계를 유지한다.



## 참고 자료

- [anthropics/prompt-eng-interactive-tutorial](https://github.com/anthropics/prompt-eng-interactive-tutorial): 프롬프트 기초 실습(노트북, 자동 채점)
- [anthropics/claude-cookbooks](https://github.com/anthropics/claude-cookbooks): structured output·RAG·tool use 코드 예제
- [dair-ai/Prompt-Engineering-Guide](https://github.com/dair-ai/Prompt-Engineering-Guide): 개념 정리
- [humanlayer/12-factor-agents](https://github.com/humanlayer/12-factor-agents): LLM 앱을 실서비스 품질로 만드는 원칙(프롬프트 소유, 구조화된 출력, 코드가 제어 흐름을 쥠)
- [promptfoo/promptfoo](https://github.com/promptfoo/promptfoo): 프롬프트·모델 비교 eval 도구
- [Simon Willison: Your AI product needs evals](https://simonwillison.net/2024/Mar/31/your-ai-product-needs-evals): Hamel Husain 글의 요약
- [Thoughtworks: How to evaluate an LLM system](https://www.thoughtworks.com/insights/blog/generative-ai/how-to-evaluate-an-LLM-system)

