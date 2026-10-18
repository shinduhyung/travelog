"""Verify new metric ideas against actual public WDI observations, not labels.

Keeps only >=10 map countries with observations in 2022-2025. No app changes.
"""
import concurrent.futures
import gzip
import json
from pathlib import Path
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'audit/statistics_ideas_sources'
CANDIDATES = '''
SP.POP.GROW|인구 증가율
SP.URB.TOTL.IN.ZS|도시 거주 인구 비율
SP.URB.GROW|도시 인구 증가율
SP.POP.0014.TO.ZS|14세 이하 인구 비율
SP.POP.65UP.TO.ZS|65세 이상 인구 비율
SP.POP.DPND|생산연령 인구 대비 부양인구 비율
SP.POP.DPND.OL|생산연령 인구 대비 고령인구 비율
SM.POP.NETM|연간 순이민자 수
SP.DYN.CBRT.IN|인구 1천 명당 출생아 수
SP.DYN.CDRT.IN|인구 1천 명당 사망자 수
SP.ADO.TFRT|청소년 출산율
SM.POP.RHCR.EA|유엔난민기구 관할 난민 수용 인원
SM.POP.RHCR.EO|유엔난민기구 관할 자국 출신 난민 수
NY.GDP.MKTP.KD.ZG|실질 GDP 성장률
FP.CPI.TOTL.ZG|소비자물가 상승률
SL.UEM.TOTL.ZS|실업률
SL.UEM.1524.ZS|청년 실업률
SL.TLF.CACT.ZS|경제활동참가율
SL.TLF.CACT.FE.ZS|여성 경제활동참가율
SL.AGR.EMPL.ZS|농업 종사자 비율
SL.IND.EMPL.ZS|산업 부문 종사자 비율
SL.SRV.EMPL.ZS|서비스업 종사자 비율
SL.EMP.VULN.ZS|취약고용 비율
SL.EMP.SELF.ZS|자영업자 비율
SL.GDP.PCAP.EM.KD|취업자 1인당 GDP
BX.TRF.PWKR.DT.GD.ZS|GDP 대비 해외 개인송금 수취액
BX.KLT.DINV.WD.GD.ZS|GDP 대비 외국인직접투자 순유입액
NE.TRD.GNFS.ZS|GDP 대비 무역 규모
NE.EXP.GNFS.ZS|GDP 대비 상품·서비스 수출액
NE.IMP.GNFS.ZS|GDP 대비 상품·서비스 수입액
BN.CAB.XOKA.GD.ZS|GDP 대비 경상수지
DT.DOD.DECT.GN.ZS|국민총소득 대비 대외부채
GC.DOD.TOTL.GD.ZS|GDP 대비 중앙정부 부채
GC.TAX.TOTL.GD.ZS|GDP 대비 조세 수입
GC.XPN.TOTL.GD.ZS|GDP 대비 정부 지출
SE.XPD.TOTL.GD.ZS|GDP 대비 공공 교육비
SH.XPD.CHEX.GD.ZS|GDP 대비 경상의료비
GB.XPD.RSDV.GD.ZS|GDP 대비 연구개발비
NV.IND.MANF.ZS|GDP 중 제조업 부가가치 비율
NV.AGR.TOTL.ZS|GDP 중 농림어업 부가가치 비율
NV.SRV.TOTL.ZS|GDP 중 서비스업 부가가치 비율
NY.GNS.ICTR.ZS|GDP 대비 총저축
TX.VAL.TECH.MF.ZS|제조업 수출 중 첨단기술 제품 비율
FI.RES.TOTL.MO|수입액 기준 외환보유액 충당 개월 수
IC.BUS.NDNS.ZS|15~64세 인구 1천 명당 신설 유한책임회사 수
FX.OWN.TOTL.ZS|15세 이상 금융계좌 보유율
FX.OWN.TOTL.MA.ZS|15세 이상 모바일머니 계좌 보유율
FB.ATM.TOTL.P5|성인 10만 명당 ATM 수
FB.CBK.BRCH.P5|성인 10만 명당 은행 지점 수
FS.AST.PRVT.GD.ZS|GDP 대비 민간 부문 국내신용
FD.AST.PRVT.GD.ZS|GDP 대비 은행의 민간 부문 국내신용
SI.POV.DDAY|하루 3달러 미만 극빈율·2021 PPP 기준
SI.DST.10TH.10|상위 10%의 소득 점유율
SI.DST.FRST.10|하위 10%의 소득 점유율
SP.DYN.IMRT.IN|영아 사망률
SH.DYN.MORT|5세 미만 아동 사망률
SH.DYN.NMRT|신생아 사망률
SH.STA.MMRT|모성 사망비
SH.STA.BRTC.ZS|숙련 의료인력이 참여한 출산 비율
SH.MED.PHYS.ZS|인구 1천 명당 의사 수
SH.MED.NUMW.P3|인구 1천 명당 간호·조산 인력 수
SH.XPD.OOPC.CH.ZS|경상의료비 중 가계 직접부담 비율
SH.TBS.INCD|결핵 발생률
SH.STA.DIAB.ZS|20~79세 당뇨병 유병률
SN.ITK.DEFC.ZS|영양부족 인구 비율
SH.STA.STNT.ZS|5세 미만 아동 발육부진율
SH.STA.WAST.ZS|5세 미만 아동 소모증 비율
SH.DYN.NCOM.ZS|주요 비감염성질환으로 인한 30~70세 조기사망 확률
SH.STA.SUIC.P5|자살 사망률
SH.H2O.BASW.ZS|기본 식수 서비스 이용률
SH.H2O.SMDW.ZS|안전하게 관리되는 식수 이용률
SH.STA.BASS.ZS|기본 위생시설 이용률
SH.STA.SMSS.ZS|안전하게 관리되는 위생시설 이용률
SH.STA.HYGN.ZS|기본 손씻기 시설 이용률
SH.IMM.MEAS|홍역 예방접종률
SH.IMM.IDPT|디프테리아·백일해·파상풍 예방접종률
SH.UHC.SRVS.CV.XD|보편적 의료서비스 보장 지수
SP.DYN.CONU.ZS|15~49세 기혼·동거 여성 피임 사용률
SP.DYN.WFRC.ZS|현대적 피임법을 통한 가족계획 수요 충족률
SH.STA.AIRP.P5|대기오염 관련 연령표준화 사망률
SE.ADT.LITR.ZS|성인 문해율
SE.ADT.1524.LT.ZS|청년 문해율
SE.PRM.CMPT.ZS|초등교육 이수율
SE.SEC.CMPT.LO.ZS|전기 중등교육 이수율
SE.PRM.ENRL.TC.ZS|초등교육 교사 1명당 학생 수
SE.SEC.ENRL.TC.ZS|중등교육 교사 1명당 학생 수
SE.PRM.UNER.ZS|초등학령기 아동 미취학률
SE.XPD.PRIM.PC.ZS|1인당 GDP 대비 초등학생 1인당 공교육비
IT.CEL.SETS.P2|인구 100명당 이동전화 가입 회선 수
IT.NET.BBND.P2|인구 100명당 유선 초고속인터넷 가입 회선 수
IT.NET.SECR.P6|인구 100만 명당 보안 인터넷 서버 수
SP.POP.SCIE.RD.P6|인구 100만 명당 연구개발 연구자 수
IP.JRN.ARTC.SC|과학·기술 학술논문 수
IP.PAT.RESD|거주자 특허 출원 수
IP.TMK.RSCT|거주자 상표 출원 건수
EG.ELC.ACCS.ZS|전력 접근률
EG.USE.ELEC.KH.PC|1인당 전력 소비량
EG.FEC.RNEW.ZS|최종 에너지 소비 중 재생에너지 비율
EG.ELC.RNEW.ZS|발전량 중 재생에너지 비율
EG.CFT.ACCS.ZS|청정 조리연료·기술 접근률
EG.EGY.PRIM.PP.KD|구매력 기준 GDP 대비 에너지 집약도
EG.IMP.CONS.ZS|에너지 사용량 대비 순수입 비율
EG.ELC.NUCL.ZS|발전량 중 원자력 비율
EG.ELC.HYRO.ZS|발전량 중 수력 비율
EG.ELC.COAL.ZS|발전량 중 석탄 비율
EG.ELC.NGAS.ZS|발전량 중 천연가스 비율
EG.ELC.RNWX.ZS|발전량 중 수력을 제외한 재생에너지 비율
EG.ELC.LOSS.ZS|송배전 전력 손실률
EN.GHG.ALL.MT.CE.AR5|토지이용·산림 제외 온실가스 총배출량
EN.GHG.ALL.PC.CE.AR5|토지이용·산림 제외 1인당 온실가스 배출량
EN.GHG.CO2.PC.CE.AR5|토지이용·산림 제외 1인당 이산화탄소 배출량
EN.GHG.CO2.RT.GDP.PP.KD|구매력 기준 GDP 대비 이산화탄소 배출량
AG.LND.FRST.ZS|육지 면적 중 산림 비율
ER.LND.PTLD.ZS|육지 보호구역 비율
ER.MRN.PTMR.ZS|영해 중 해양 보호구역 비율
EN.BIR.THRD.NO|멸종위기 조류 종 수
EN.MAM.THRD.NO|멸종위기 포유류 종 수
EN.FSH.THRD.NO|멸종위기 어류 종 수
EN.HPT.THRD.NO|멸종위기 고등식물 종 수
ER.H2O.FWST.ZS|가용 담수 대비 취수량·물 스트레스
ER.H2O.INTR.PC|1인당 재생가능 내부 담수자원량
AG.LND.IRIG.AG.ZS|농경지 중 관개 면적 비율
AG.LND.ARBL.ZS|육지 중 경작지 비율
AG.CON.FERT.ZS|경작지 1헥타르당 비료 사용량
AG.YLD.CREL.KG|1헥타르당 곡물 수확량
ER.FSH.CAPT.MT|포획 어업 생산량
ER.FSH.AQUA.MT|양식업 생산량
IS.AIR.PSGR|등록 항공사의 여객 수송 실적
IS.AIR.GOOD.MT.K1|등록 항공사의 항공화물 수송 실적
IS.AIR.DPRT|등록 항공사의 항공기 출발 횟수
IS.SHP.GOOD.TU|컨테이너 항만 물동량
IS.RRS.TOTL.KM|철도 노선 총연장
IS.RRS.PASG.KM|철도 여객 수송 실적
IS.RRS.GOOD.MT.K6|철도 화물 수송 실적
LP.LPI.OVRL.XQ|물류성과지수
IS.SHP.GCNW.XQ|정기선 해운 연결성 지수
ST.INT.ARVL|외국인 관광객 도착 건수
ST.INT.RCPT.CD|국제관광 수입
SG.GEN.PARL.ZS|하원·단원제 의회의 여성 의석 비율
SG.LAW.INDX|여성·기업·법 지수
'''


def fetch(url, dest):
    if dest.exists():
        return json.loads(gzip.decompress(dest.read_bytes()))
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=90) as response:
                raw = response.read()
            parsed = json.loads(raw)
            if not isinstance(parsed, list) or len(parsed) != 2 or not isinstance(parsed[1], list):
                raise ValueError(str(parsed)[:200])
            if parsed[0]['pages'] != 1:
                raise ValueError('Unexpected pagination')
            dest.write_bytes(gzip.compress(raw))
            return parsed
        except Exception:
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def main():
    OUT.mkdir(exist_ok=True)
    catalog = {r['id']: r for r in json.loads((OUT / 'wdi_indicator_catalog.json').read_text(encoding='utf8'))[1]}
    all_countries = json.loads((OUT / 'countries.json').read_text(encoding='utf8'))[1]
    real_countries = {r['id'] for r in all_countries if r['region']['id'] != 'NA'}
    geo = json.loads((ROOT / 'assets/custom.geo.json').read_text(encoding='utf-8-sig'))
    map_codes = {f['properties'].get('iso_a3_eh') or f['properties'].get('iso_a3') for f in geo['features']}
    if 'KOS' in map_codes:
        map_codes.add('XKX')
    valid_countries = real_countries & map_codes
    candidates = [line.split('|') for line in CANDIDATES.strip().splitlines()]
    missing = [r for r in candidates if r[0] not in catalog]
    candidates = [r for r in candidates if r[0] in catalog]
    batches = [candidates[i:i+8] for i in range(0, len(candidates), 8)]

    def process(batch):
        codes = ';'.join(r[0] for r in batch)
        url = f'https://api.worldbank.org/v2/country/all/indicator/{codes}?source=2&format=json&date=2022:2025&per_page=20000'
        import hashlib
        dest = OUT / ('observations_' + hashlib.sha256(codes.encode()).hexdigest()[:12] + '.json.gz')
        data = fetch(url, dest)
        results = []
        for code, label in batch:
            latest = {}
            by_year = {}
            for row in data[1]:
                iso = row['countryiso3code']
                if row['indicator']['id'] != code or iso not in valid_countries or row['value'] is None:
                    continue
                if iso not in latest or int(row['date']) > int(latest[iso]['date']):
                    latest[iso] = row
                by_year.setdefault(int(row['date']), {})[iso] = row
            comparable_years = [year for year, rows in by_year.items()
                                if len(rows) >= 10 and len({r['value'] for r in rows.values()}) >= 10]
            ranking_year = max(comparable_years) if comparable_years else None
            ranking_rows = by_year.get(ranking_year, {})
            results.append({'id': code, 'label': label, 'country_count': len(latest),
                            'ranking_year': ranking_year, 'same_year_country_count': len(ranking_rows),
                            'distinct_same_year_values': len({r['value'] for r in ranking_rows.values()}),
                            'observation_years': sorted({int(r['date']) for r in latest.values()}),
                            'official_name': catalog[code]['name'], 'definition': catalog[code]['sourceNote'],
                            'source_organization': catalog[code]['sourceOrganization'],
                            'source_lastupdated': data[0].get('lastupdated'), 'api_url': url,
                            'url': 'https://data.worldbank.org/indicator/' + code,
                            'observations': [{'iso_a3': iso, 'value': r['value'], 'year': int(r['date'])}
                                             for iso, r in sorted(latest.items())],
                            'same_year_observations': [{'iso_a3': iso, 'value': r['value'], 'year': int(r['date'])}
                                                      for iso, r in sorted(ranking_rows.items())]})
        return results

    results, errors = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(process, batch): batch for batch in batches}
        for future in concurrent.futures.as_completed(futures):
            try:
                rows = future.result()
                results.extend(rows)
                print('Verified batch:', len(rows), flush=True)
            except Exception as error:
                errors.append({'indicators': [r[0] for r in futures[future]], 'error': str(error)})
    order = {code: i for i, (code, _) in enumerate(candidates)}
    results.sort(key=lambda r: order[r['id']])
    passed = [r for r in results if r['ranking_year'] is not None]
    output = {'audit_date': '2026-10-17', 'rule': '>=10 distinct nonaggregate map countries and >=10 distinct numeric values in one common year in 2022-2025',
              'accepted': passed, 'insufficient_recent_coverage': [r for r in results if r['ranking_year'] is None],
              'not_in_current_wdi_catalog': missing, 'errors': errors}
    (ROOT / 'audit/statistics_ideas_verified.json').write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf8')
    lines = ['# 추가 통계 후보 검증', '', '항목마다 같은 연도의 국가·지역별 실제 수치 10개 이상 및 서로 다른 수치 10종 이상 확인. 지역 집계 제외. 표기 연도는 이 조건을 만족하는 2022~2025년 중 가장 최근 관측연도.', '']
    lines.extend(f"- [ ] [{r['label']}]({r['url']}) — {r['ranking_year']}년 · {r['same_year_country_count']}개국·지역" for r in passed)
    (ROOT / 'audit/statistics_ideas_checklist.md').write_text('\n'.join(lines)+'\n', encoding='utf8')
    print(json.dumps({'candidates': len(candidates), 'accepted': len(passed), 'missing': missing, 'errors': errors}))


if __name__ == '__main__':
    main()
