# 문서 체계 v2 — 적용 문서

작성일: 2026-10-07. 이전: [v1](../v1/README.md). 압축 범위를 바로잡아 다음 세 주제만 새 설계로 채택한다. 상세 적용 범위와 주제별 진입 경로는 [상위 목차](../README.md#적용-범위)를 따른다.

## 새 설계

- [추천](recommendation.md)
- [출처](sources.md)
- [평가](evaluation.md)
- [실행 6 계획](run6-plan.md): 실행 5의 세 구성(검색, 검색 + 제약 입력, 상위 모델 + 검색)을 Gemini로 반복한다. 호출 전 초안.
- [실행 5 계획](run5-plan.md): 평가 원문의 다음 비교를 구체화한 계획. 방식 구성이 평가 원문과 다르다. 2026-10-07 고정, 호출 전.

## 변경하지 않고 유지하는 원문

- 기억: [직접 증거·이관](../recommendation/preference-evidence.md), [경험 어휘](../recommendation/experience-vocabulary.md), [기존 사용자 정보](../recommendation/architecture.md#3-사용자-정보-하나의-점수-벡터로-압축하지-않는다), [기억·제외 정책](../recommendation/architecture.md#6-피드백기억제외-정책).
- [저장·전송](../data/storage-and-privacy.md).
- [계측](../evaluation/metrics.md).
- [화면별 원문](../screens/README.md).
- [후보 선정 기록](../data/destination-selection.md)과 [보존 자료 형식](../data/city-format.md).
- [제휴 정책](../v1/project.md#5-수익화-제휴-단독).
- [출시 차단 요건](../v1/project.md#10-출시-차단-요건)과 [출시 검사](../v1/progress.md#6-출시-검사와-병행-업무).

## 채택 철회된 압축 초안

[memory](memory.md), [storage](storage.md), [metrics](metrics.md), [screens](screens.md), [candidates](candidates.md), [affiliates](affiliates.md), [release](release.md)는 정리 과정의 기록으로 남긴다. 현재 요구사항으로 적용하지 않는다. 항목별 대조·채택 결정 전까지 원문이 기준이다.

제품 목표·범위는 [루트 README](../../README.md), 진행 상태는 [TODO](../TODO.md), 과거 실험 결과는 [v1](../v1/README.md)과 [원본 파일](../../data/exploration/README.md)에서 찾는다.
