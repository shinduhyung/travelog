# affiliate_stats

모든 제휴 프로그램의 클릭·전환·수수료를 한 파일로 모읍니다.

| 프로그램 | 방식 | 필요한 것 |
|---|---|---|
| Impact (Airalo, Omio) | API 자동 | app.impact.com → Settings → API: Account SID + Auth Token (읽기 전용) |
| Expedia 크리에이터 (Hotels.com, Vrbo) | Partnerize API 자동 | Partnerize 콘솔 → API access: User application key + User API key, publisher ID |
| GetYourGuide | 수동 | 공개 리포팅 API 없음. 파트너 포털 Analytics에서 숫자/CSV 확인 |
| Trip.com | 수동 | 리포팅 API 없음. Affiliate 대시보드 Report 내보내기 |
| Bounce | 수동 | API 없음(담당자 확인). 대시보드 수치 |

1. `.env.example`을 `.env`로 복사해 키를 넣습니다 (`.env`는 gitignore됨).
2. 수동 프로그램은 `manual.csv`에 `date,program,clicks,conversions,commission_usd` 행을 추가합니다.
3. `python tool/affiliate_stats/fetch_stats.py --days 30` → `out/stats.csv`, `out/programs.csv`.
4. 대시보드 갱신: Claude에게 "제휴 대시보드 새로고침"이라고 하면 out/ 파일을 올립니다.
