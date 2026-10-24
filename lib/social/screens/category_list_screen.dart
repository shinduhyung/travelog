import 'package:flutter/material.dart';

import '../data/geo_data.dart';
import '../models/social_profile.dart';
import '../models/stats.dart';
import '../services/social_store.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/flag.dart';

/// 프로필의 숫자 타일을 누르면 열리는 목록 화면 (나라/도시/랜드마크/…)
enum ListCategory { countries, cities, landmarks, unesco, airports, flights, capitals }

extension on ListCategory {
  String get label => switch (this) {
        ListCategory.countries => 'Countries',
        ListCategory.cities => 'Cities',
        ListCategory.landmarks => 'Landmarks',
        ListCategory.unesco => 'UNESCO sites',
        ListCategory.airports => 'Airports',
        ListCategory.flights => 'Flights',
        ListCategory.capitals => 'Capitals',
      };

  String get noun => switch (this) {
        ListCategory.unesco => 'UNESCO sites',
        _ => label.toLowerCase(),
      };

  String get emoji => switch (this) {
        ListCategory.countries => '🌍',
        ListCategory.cities => '🏙️',
        ListCategory.landmarks => '🗽',
        ListCategory.unesco => '🏛️',
        ListCategory.airports => '🛫',
        ListCategory.flights => '✈️',
        ListCategory.capitals => '⭐',
      };
}

enum _Sort { recent, az, visits }

const _sortLabels = {_Sort.recent: 'Recent', _Sort.az: 'A–Z', _Sort.visits: 'Most visited'};

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key, required this.uid, required this.category});

  /// 누구의 목록인지 (나 또는 친구)
  final String uid;
  final ListCategory category;

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

/// 목록 한 줄
class _Item {
  _Item({
    required this.title,
    required this.leading,
    this.titleExtra,
    this.extraAccent = false,
    this.place,
    this.details,
    this.rating = 0,
    this.date,
    this.visits = 0,
    this.shared = false,
    this.onTap,
    String? search,
  }) : search = (search ?? title).toLowerCase();

  final String title;

  /// 제목 뒤에 작게 붙는 회색/민트 글자 ("#1", "· Capital", 공항 이름)
  final String? titleExtra;
  final bool extraAccent;
  final Widget leading;

  /// 2번째 줄: 장소 (나라 / 도시, 나라 / 항공사)
  final String? place;

  /// 3번째 줄: 날짜·횟수
  final String? details;
  final double rating;

  /// 정렬용 날짜 ("YYYY-MM-DD" / "YYYY-MM" / "YYYY")
  final String? date;
  final int visits;

  /// 내가(친구 목록을 볼 때) 같은 항목을 가지고 있는지
  final bool shared;
  final void Function(BuildContext context)? onTap;
  final String search;
}

// ── 날짜/숫자 표시 ────────────────────────────────────────────────────

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "2019-04-03" → "Apr 3, 2019", "2019-04" → "Apr 2019", "2019" → "2019"
String? formatVisitDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('-');
  final y = parts[0];
  final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
  final d = parts.length > 2 ? int.tryParse(parts[2]) : null;
  if (m == null || m < 1 || m > 12) return y;
  if (d == null) return '${_months[m - 1]} $y';
  return '${_months[m - 1]} $d, $y';
}

String? _firstOf(PlaceInfo? i) => i?.first ?? (i == null || i.years.isEmpty ? null : '${i.years.first}');

String? _lastOf(PlaceInfo? i) => i?.last ?? (i == null || i.years.length < 2 ? null : '${i.years.last}');

/// "Apr 2019 · last Jan 2024"
String? _dateLine(PlaceInfo? i) {
  final f = formatVisitDate(_firstOf(i));
  final l = formatVisitDate(_lastOf(i));
  if (f == null) return l == null ? null : 'Last $l';
  if (l == null || l == f) return f;
  return '$f · last $l';
}

String? _sortDate(PlaceInfo? i) => _lastOf(i) ?? _firstOf(i);

String _visitsText(int n) => n == 1 ? '1 visit' : '$n visits';

String _km(double km) {
  final s = km.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '$b km';
}

String? _join(Iterable<String?> parts, [String sep = ' · ']) {
  final list = parts.whereType<String>().where((s) => s.isNotEmpty).toList();
  return list.isEmpty ? null : list.join(sep);
}

// ── 화면 ─────────────────────────────────────────────────────────────

class _CategoryListScreenState extends State<CategoryListScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Sort _sort = _Sort.recent;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final self = widget.uid == store.uid;
    final profile = self ? store.me : store.friend(widget.uid);
    final me = self ? null : store.me;
    final theme = Theme.of(context);
    final cat = widget.category;

    final hidden = !self &&
        profile != null &&
        ((!profile.privacy.cities && (cat == ListCategory.cities || cat == ListCategory.capitals)) ||
            (!profile.privacy.flights && (cat == ListCategory.flights || cat == ListCategory.airports)));

    final all = (profile == null || hidden)
        ? <_Item>[]
        : _buildItems(profile, me, myProfile: store.me, friendProfile: self ? null : profile);
    final owner = self ? 'Your ${cat.noun}' : "${profile?.displayName ?? 'Friend'}'s ${cat.noun}";

    Widget body;
    if (profile == null) {
      body = const Center(child: EmptyHint('Profile not loaded yet', emoji: '⏳'));
    } else if (hidden) {
      body = Center(child: EmptyHint('Hidden by ${profile.displayName}', emoji: '🔒'));
    } else if (all.isEmpty) {
      body = Center(child: EmptyHint('No ${cat.noun} yet', emoji: cat.emoji));
    } else {
      final items = _filterSort(all);
      final sharedCount = all.where((i) => i.shared).length;
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search ${cat.noun}',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: PopupMenuButton<_Sort>(
                    initialValue: _sort,
                    tooltip: 'Sort',
                    onSelected: (s) => setState(() => _sort = s),
                    itemBuilder: (_) => [
                      for (final s in _Sort.values) PopupMenuItem(value: s, child: Text(_sortLabels[s]!)),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_rounded, size: 18, color: AppColors.darkMint),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(_sortLabels[_sort]!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (me != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.mint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cat == ListCategory.flights
                          ? "You've flown $sharedCount of these routes"
                          : "You've been to $sharedCount of these",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.darkMint, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [EmptyHint('Nothing matches "$_query"', emoji: '🔍')],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    itemCount: items.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _Row(item: items[i], showShared: me != null),
                    ),
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${cat.label} · ${all.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text(owner,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: body,
    );
  }

  List<_Item> _filterSort(List<_Item> all) {
    final list = _query.isEmpty ? List.of(all) : all.where((i) => i.search.contains(_query)).toList();
    int byName(_Item a, _Item b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
    switch (_sort) {
      case _Sort.recent:
        list.sort((a, b) {
          if (a.date == null && b.date == null) return byName(a, b);
          if (a.date == null) return 1;
          if (b.date == null) return -1;
          final c = b.date!.compareTo(a.date!);
          return c != 0 ? c : byName(a, b);
        });
      case _Sort.az:
        list.sort(byName);
      case _Sort.visits:
        list.sort((a, b) {
          final c = b.visits.compareTo(a.visits);
          return c != 0 ? c : byName(a, b);
        });
    }
    return list;
  }

  // ── 카테고리별 항목 ─────────────────────────────────────────────────

  List<_Item> _buildItems(SocialProfile p, SocialProfile? me, {SocialProfile? myProfile, SocialProfile? friendProfile}) {
    final geo = GeoData.I;

    /// 2번째 줄: "🏠 France · Lived"
    String? placeLine(String? place, PlaceInfo? i) {
      final line = _join([place, if (i?.lived == true && i?.home != true) 'Lived']);
      if (i?.home == true) return line == null ? '🏠 Home' : '🏠 $line';
      return line;
    }

    /// 3번째 줄: "Apr 3, 2019 · last Jan 2024 · 3 visits"
    String? detailLine(PlaceInfo? i, [int? visits]) {
      final v = visits ?? i?.visits ?? 0;
      return _join([_dateLine(i), if (v > 1) _visitsText(v)]);
    }

    Widget flagLead(String? iso2) => _LeadBox(child: Flag(iso2, width: 40, radius: 5));

    switch (widget.category) {
      case ListCategory.countries:
        final mine = me?.countries.toSet() ?? const <String>{};
        return [
          for (final name in p.countries)
            () {
              final meta = geo.countryByName(name);
              final info = p.countryInfo[name];
              return _Item(
                title: meta?.longName ?? name,
                search: '${meta?.longName ?? name} $name',
                leading: flagLead(meta?.iso2),
                place: placeLine(meta?.subregion ?? meta?.continent, info),
                details: detailLine(info),
                rating: info?.rating ?? 0,
                date: _sortDate(info),
                visits: info?.visits ?? 0,
                shared: mine.contains(name),
                onTap: meta == null ? null : (ctx) => showCountrySheet(ctx, meta, me: myProfile, friend: friendProfile),
              );
            }(),
        ];

      case ListCategory.cities:
      case ListCategory.capitals:
        final mine = me?.cities.toSet() ?? const <String>{};
        final keys = widget.category == ListCategory.capitals
            ? ProfileStats(p).cityMetas.where((c) => c.isCapital).map((c) => c.key)
            : p.cities;
        return [
          for (final key in keys)
            () {
              final meta = geo.cities[key];
              final country = geo.countryByIso2(meta?.iso2);
              final info = p.cityInfo[key];
              final name = displayCityName(key);
              return _Item(
                title: name,
                titleExtra: widget.category == ListCategory.cities && meta?.isCapital == true ? '· Capital' : null,
                extraAccent: true,
                search: '$name ${country?.longName ?? ''}',
                leading: flagLead(meta?.iso2),
                place: placeLine(country?.longName, info),
                details: detailLine(info),
                rating: info?.rating ?? 0,
                date: _sortDate(info),
                visits: info?.visits ?? 0,
                shared: mine.contains(key),
              );
            }(),
        ];

      case ListCategory.landmarks:
        final mine = me?.landmarks.toSet() ?? const <String>{};
        return [
          for (final name in p.landmarks)
            () {
              final meta = geo.landmarks[name];
              final country = geo.countryByIso3(meta?.iso3);
              final info = p.landmarkInfo[name];
              return _Item(
                title: name,
                titleExtra: meta != null && meta.rank > 0 ? '#${meta.rank}' : null,
                extraAccent: true,
                search: '$name ${meta?.city ?? ''} ${country?.longName ?? ''}',
                leading: SizedBox(
                  width: _leadSize,
                  height: _leadSize,
                  child: LandmarkImage(name: name, height: _leadSize, radius: 12),
                ),
                place: _join([meta?.city, country?.longName], ', '),
                details: detailLine(info),
                rating: info?.rating ?? 0,
                date: _sortDate(info),
                visits: info?.visits ?? 0,
                shared: mine.contains(name),
                onTap: (ctx) => _showLandmarkSheet(ctx, name, info),
              );
            }(),
        ];

      case ListCategory.unesco:
        final mine = me?.unesco.toSet() ?? const <String>{};
        return [
          for (final name in p.unesco)
            () {
              final meta = geo.unesco[name];
              final country = geo.countryByIso3(meta?.iso3);
              final info = p.unescoInfo[name];
              return _Item(
                title: name,
                search: '$name ${country?.longName ?? ''}',
                leading: flagLead(country?.iso2),
                place: _join([country?.longName, 'UNESCO', meta?.type]),
                details: detailLine(info),
                rating: info?.rating ?? 0,
                date: _sortDate(info),
                visits: info?.visits ?? 0,
                shared: mine.contains(name),
              );
            }(),
        ];

      case ListCategory.airports:
        final mine = me?.airports.keys.toSet() ?? const <String>{};
        return [
          for (final e in p.airports.entries)
            () {
              final iata = e.key;
              final meta = geo.airports[iata];
              final country = geo.countryByIso2(meta?.iso2);
              final info = p.airportInfo[iata];
              final visits = info != null && info.visits > 0 ? info.visits : e.value;
              return _Item(
                title: iata,
                titleExtra: meta?.name,
                search: '$iata ${meta?.name ?? ''} ${meta?.city ?? ''} ${country?.longName ?? ''}',
                leading: flagLead(meta?.iso2),
                place: _join([meta?.city, country?.longName], ', '),
                details: detailLine(info, visits),
                rating: info?.rating ?? 0,
                date: _sortDate(info),
                visits: visits,
                shared: mine.contains(iata),
              );
            }(),
        ];

      case ListCategory.flights:
        final mine = <String>{
          if (me != null) ...[
            for (final f in me.flightLog) '${f.from}-${f.to}',
            for (final r in me.flights.routes) '${r.from}-${r.to}',
          ],
        };
        double km(String from, String to) {
          final a = geo.airports[from];
          final b = geo.airports[to];
          if (a == null || b == null) return 0;
          return haversineKm(a.lat, a.lng, b.lat, b.lng);
        }

        if (p.flightLog.isNotEmpty) {
          final routeCounts = <String, int>{};
          for (final f in p.flightLog) {
            routeCounts['${f.from}-${f.to}'] = (routeCounts['${f.from}-${f.to}'] ?? 0) + 1;
          }
          return [
            for (final f in p.flightLog)
              () {
                final code = f.airline;
                final airline = code == null ? null : (geo.airlines[code]?.name ?? code);
                final d = km(f.from, f.to);
                final times = routeCounts['${f.from}-${f.to}'] ?? 1;
                return _Item(
                  title: '${f.from} → ${f.to}',
                  titleExtra: d > 0 ? _km(d) : null,
                  search: '${f.from} ${f.to} ${airline ?? ''} ${f.number ?? ''}',
                  leading: _LeadBox(child: _AirlineChip(code: code)),
                  place: _join([airline, f.number]),
                  details: _join([formatVisitDate(f.date), if (times > 1) '$times× this route']),
                  date: f.date,
                  visits: times,
                  shared: mine.contains('${f.from}-${f.to}'),
                );
              }(),
          ];
        }
        return [
          for (final r in p.flights.routes)
            () {
              final d = km(r.from, r.to);
              return _Item(
                title: '${r.from} → ${r.to}',
                titleExtra: d > 0 ? _km(d) : null,
                search: '${r.from} ${r.to}',
                leading: const _LeadBox(child: _AirlineChip(code: null)),
                details: r.times == 1 ? '1 flight' : '${r.times} flights',
                visits: r.times,
                shared: mine.contains('${r.from}-${r.to}'),
              );
            }(),
        ];
    }
  }

  void _showLandmarkSheet(BuildContext context, String name, PlaceInfo? info) {
    final geo = GeoData.I;
    final meta = geo.landmarks[name];
    final country = geo.countryByIso3(meta?.iso3);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final dates = _dateLine(info);
        final visits = info?.visits ?? 0;
        final rating = info?.rating ?? 0;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LandmarkImage(name: name, height: 200, radius: 20),
                const SizedBox(height: 14),
                Text(name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (country != null) ...[Flag(country.iso2, width: 22, radius: 3), const SizedBox(width: 6)],
                    Expanded(
                      child: Text(
                        [meta?.city, country?.longName].whereType<String>().join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.label),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (meta != null && meta.rank > 0) Chip(avatar: const Text('🏆'), label: Text('World #${meta.rank}')),
                    if (meta?.category case final c?) Chip(label: Text(c)),
                    if (dates != null) Chip(avatar: const Text('📅'), label: Text(dates)),
                    if (visits > 0) Chip(avatar: const Text('🔁'), label: Text(_visitsText(visits))),
                  ],
                ),
                if (rating > 0) ...[const SizedBox(height: 10), Stars(rating, size: 20)],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 줄 위젯 ──────────────────────────────────────────────────────────

/// 모든 줄의 앞쪽(국기/사진) 크기 — 줄 정렬을 맞춘다
const double _leadSize = 52;

class _LeadBox extends StatelessWidget {
  const _LeadBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: _leadSize, height: _leadSize, child: Center(child: child));
}

class _AirlineChip extends StatelessWidget {
  const _AirlineChip({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final c = code;
    final meta = c == null ? null : GeoData.I.airlines[c];
    final hex = meta?.colorHex?.replaceAll('#', '');
    final parsed = hex != null && hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    final color = parsed != null ? Color(0xFF000000 | parsed) : AppColors.indigo;
    return Container(
      width: 48,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: c == null
          ? Icon(Icons.flight_rounded, size: 18, color: color)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(c,
                  maxLines: 1,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color.lerp(color, Colors.black, 0.3))),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.showShared});

  final _Item item;
  final bool showShared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onTap = item.onTap;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
    final extraStyle = theme.textTheme.labelMedium?.copyWith(
      color: item.extraAccent ? AppColors.darkMint : AppColors.label,
      fontWeight: item.extraAccent ? FontWeight.w800 : FontWeight.w600,
    );
    final subStyle = theme.textTheme.bodySmall?.copyWith(color: AppColors.label);
    final shared = showShared && item.shared;

    return WhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap == null ? null : () => onTap(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _leadSize),
        child: Row(
          children: [
            item.leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      text: item.title,
                      style: titleStyle,
                      children: [
                        if (item.titleExtra case final x?) TextSpan(text: '  $x', style: extraStyle),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.place case final s?) ...[
                    const SizedBox(height: 2),
                    Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle),
                  ],
                  if (item.details case final s?) ...[
                    const SizedBox(height: 2),
                    Text(s,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subStyle?.copyWith(fontSize: (subStyle.fontSize ?? 12) - 1)),
                  ],
                ],
              ),
            ),
            if (item.rating > 0) ...[
              const SizedBox(width: 8),
              Stars(item.rating, size: 12),
            ],
            if (shared) ...[
              const SizedBox(width: 6),
              const Tooltip(
                message: 'You too',
                child: Icon(Icons.check_circle_rounded, size: 18, color: AppColors.mint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
