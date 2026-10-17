"""새 도시 자료의 구조 검사. 사실 검수·추천 실험을 실행하지 않는다."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / 'data/destinations/catalog.json'
LEVELS = ('none', 'if_there', 'make_time', 'choose')
SEASON_SENSITIVE = {'festival', 'sports', 'concert', 'winter', 'water', 'hiking', 'wildlife', 'themepark'}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'중복 JSON 키: {key}')
        result[key] = value
    return result


def load(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_object)


def validate(data, candidates, pilot):
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    require(data['schema_version'] == 1, 'schema_version')
    require(data['status'] == 'draft' and data['release_ready'] is False, '초안의 출시 가능 표시 금지')
    require([level['id'] for level in data['levels']] == list(LEVELS), '등급 이름/순서')
    concepts = load(ROOT / 'data/exploration/coverage-check/grades-v2.json')['concepts']
    require(data['concepts'] == concepts, '기준 29개 세부와 다름')
    subs = {s for concept in concepts.values() for s in concept['sub']}
    candidate_map = {c['id']: c for c in candidates['candidates']}
    expected = {('th-phuket-island' if cid == 'th-phuket' else cid) for cid in candidate_map}
    require(set(data['cities']) == expected and len(expected) == 103, '후보 103곳 ID/누락/초과')
    require(set(pilot['cities']) <= set(data['cities']), '기존 20곳 누락')
    require(len(pilot['cities']) == 20 and len(subs) == 29, '기준 파일 크기')
    for sid, source in data['sources'].items():
        require(source['url'].startswith('https://') and source['supports'].strip(), f'{sid}: 출처')
        require(source['access'] in ('page_read', 'search_excerpt'), f'{sid}: 조회 방식')
        require(source['review_status'] == 'pending', f'{sid}: 사람 검수 상태')
        require(bool(re.fullmatch(r'\d{4}-\d{2}-\d{2}', source['checked_on'])), f'{sid}: 조회일')
    for cid, city in data['cities'].items():
        def check(condition, message):
            require(condition, f'{cid}: {message}')
        candidate = 'th-phuket' if cid == 'th-phuket-island' else cid
        check(city['candidate_id'] == candidate, '후보 ID 연결')
        check(city['country'] == candidate_map[candidate]['country_code'], '국가 코드')
        check(all(isinstance(city['name'][lang], str) and city['name'][lang].strip() for lang in ('ko', 'en')), '이름')
        check(isinstance(city['scope'], str) and city['scope'].strip(), '범위 누락')
        check(city['status'] == 'draft' and city['human_review'] is None, '초안을 사람 검수 완료로 표시')
        check(city['review'] == dict.fromkeys(('grades', 'scope', 'core', 'season'), 'pending'), '검수 상태')
        grades = city['grades']
        check(set(grades) == subs and all(v in LEVELS for v in grades.values()), '세부 누락/잘못된 등급')
        check(grades['locals'] in LEVELS[:2], '정의 미확정 locals 상위 등급')
        high = {s for s, grade in grades.items() if grade in LEVELS[2:]}
        check(set(city['core']) == high, '상위 등급 핵심 경험 누락/초과')
        check(all(isinstance(v, str) and v.strip() for v in city['core'].values()), '빈 핵심 경험')
        check(city['grade_note'].strip() and city['review_flags'], '판정/검수 메모 누락')
        check(all(isinstance(k, str) and k.strip() and isinstance(v, list) and v and set(v) <= subs for k, v in city['nearby'].items()), '근교 세부 참조')
        season, unknown = city['season'], city['season_unverified']
        check(set(season) <= subs and set(unknown) <= subs, '시즌 세부 ID')
        check(len(unknown) == len(set(unknown)) and not set(season) & set(unknown), '시즌 중복/충돌')
        check(all(grades[s] != 'none' for s in set(season) | set(unknown)), 'none에 시즌')
        for sub, months in season.items():
            check(isinstance(months, list) and months and all(type(m) is int and 1 <= m <= 12 for m in months), '시즌 달 범위')
            check(len(months) == len(set(months)), '시즌 달 중복')
        check(set(city['season_basis']) == set(season), '시즌 근거 누락')
        for sub, basis in city['season_basis'].items():
            check(basis['sources'] and set(basis['sources']) <= set(data['sources']), '시즌 출처 참조')
            check(basis['year'] is None or type(basis['year']) is int and 2020 <= basis['year'] <= 2100, '시즌 적용 연도')
            check(basis['note'].strip() and basis['review_status'] == 'pending', '시즌 근거 상태')
        required = {s for s in SEASON_SENSITIVE if grades[s] != 'none'}
        check(required <= set(season) | set(unknown), '행사·운영 시즌 미확인을 연중으로 누락')
        for sub, refs in city['evidence'].items():
            check(sub in subs | {'scope'} and refs and set(refs) <= set(data['sources']), '출처 참조')
        check(city['provenance'] == ('reassessed_pilot' if cid in pilot['cities'] else 'model_draft'), '작성 이력')
        last = {}
        for row in city.get('revisions', []):
            check(row['sub'] in subs and row['before'] in LEVELS and row['before'] != row['after'], '보정 기록 세부/등급')
            check(row['sub'] not in last or last[row['sub']] == row['before'], '보정 기록 순서')
            check(row['reason'].strip() and row['review_status'] == 'pending', '보정 근거/상태')
            last[row['sub']] = row['after']
        check(all(grades[s] == after for s, after in last.items()), '보정 기록과 현재 등급 불일치')
        if cid in pilot['cities']:
            reassessment = city['reassessment']
            check(set(reassessment['coverage']) == subs and len(reassessment['coverage']) == 29, '기존 29칸 재판정 범위')
            actual = {s for s in subs if grades[s] != pilot['cities'][cid]['grades'][s]}
            logged = reassessment['changed']
            check({row['sub'] for row in logged} == actual and len(logged) == len(actual), '등급 변경 기록 누락/초과')
            for row in logged:
                s = row['sub']
                check(row['city_id'] == cid and row['before'] == pilot['cities'][cid]['grades'][s] and row['after'] == grades[s], '변경 전후 불일치')
                check(row['reason'].strip() and row['review_status'] == 'pending', '변경 근거/상태')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', action='store_true', help='출시 검수 게이트: 현재 초안은 거부')
    args = parser.parse_args()
    try:
        data = load(CATALOG)
        validate(data, load(ROOT / 'data/planning/destination-candidates.json'), load(ROOT / 'data/exploration/city-draft/draft.json'))
        cities = data['cities']
        print(f"형식 통과: {len(cities)}곳, {sum(len(c['grades']) for c in cities.values())}칸, core {sum(len(c['core']) for c in cities.values())}항목")
        print(f"기존 등급 변경 {sum(len(c.get('reassessment', {}).get('changed', [])) for c in cities.values())}칸; 시즌 미확인 {sum(len(c['season_unverified']) for c in cities.values())}칸")
        print('출시 검수 완료: 0곳. 구조 통과는 사실·등급 검수를 의미하지 않는다.')
        if args.release:
            raise ValueError('출시 거부: draft 자료이며 사람 검수 기록이 없다. 앱 번들에 적용하지 말 것.')
    except (ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
