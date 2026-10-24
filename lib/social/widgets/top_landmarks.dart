import 'package:flutter/material.dart';

import '../data/geo_data.dart';
import '../models/social_profile.dart';
import '../services/social_store.dart';
import '../theme.dart';
import 'avatar.dart';
import 'cards.dart';
import 'flag.dart';
import '../social_hub.dart';

/// Travelog Top 250 (rank 1..250)
List<LandmarkMeta> get top250 => GeoData.I.topLandmarks.take(250).toList();

/// One person in a Top 250 comparison: profile + color + label + visited set.
class TopPerson {
  TopPerson({required this.profile, required this.color, required this.label}) : visited = profile.landmarks.toSet();

  final SocialProfile profile;
  final Color color;
  final String label;
  final Set<String> visited;

  int countIn(List<LandmarkMeta> list) => list.where((m) => visited.contains(m.name)).length;

  /// Resolves uids through the store. First uid = AppColors.me, second = AppColors.friend.
  static List<TopPerson> resolve(SocialStore store, List<String> uids) {
    final out = <TopPerson>[];
    for (final uid in uids) {
      final p = uid == store.uid ? store.me : store.friend(uid);
      if (p == null) continue;
      out.add(TopPerson(
        profile: p,
        color: out.isEmpty ? AppColors.me : AppColors.friend,
        label: uid == store.uid ? 'You' : p.displayName,
      ));
    }
    return out;
  }
}

/// "You 37/250" + progress bar
class TopScoreLine extends StatelessWidget {
  const TopScoreLine({super.key, required this.person, required this.total, this.avatar = false});

  final TopPerson person;
  final int total;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = person.countIn(top250);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            if (avatar) ...[UserAvatar(profile: person.profile, radius: 12), const SizedBox(width: 8)] else ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: person.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                person.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '$n', style: TextStyle(color: person.color, fontWeight: FontWeight.w900)),
                TextSpan(text: '/$total', style: const TextStyle(color: AppColors.label, fontWeight: FontWeight.w700)),
              ]),
              style: theme.textTheme.labelLarge,
            ),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (n / total).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation(person.color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small lit/dim indicator for one person
class VisitDot extends StatelessWidget {
  const VisitDot({super.key, required this.person, required this.lit, this.size = 22});

  final TopPerson person;
  final bool lit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = person.label.isEmpty ? '?' : person.label.characters.first.toUpperCase();
    return Tooltip(
      message: '${person.label}: ${lit ? 'visited' : 'not yet'}',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit ? person.color : Colors.white,
          border: Border.all(color: lit ? person.color : const Color(0xFFD1D5DB), width: 1.6),
          boxShadow: lit ? [BoxShadow(color: person.color.withValues(alpha: 0.45), blurRadius: 6)] : null,
        ),
        child: person.label == 'You'
            ? Icon(Icons.person_rounded, size: size * 0.7, color: lit ? Colors.white : const Color(0xFFD1D5DB))
            : Padding(
                padding: const EdgeInsets.all(3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: size * 0.5,
                      fontWeight: FontWeight.w900,
                      color: lit ? Colors.white : const Color(0xFFD1D5DB),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Card: score per person, strip of visited Top 250 landmarks, "See all 250"
class TopLandmarksPreview extends StatelessWidget {
  const TopLandmarksPreview({super.key, required this.uids});

  final List<String> uids;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final people = TopPerson.resolve(store, uids);
    final top = top250;
    final theme = Theme.of(context);
    final visited = [
      for (final m in top)
        if (people.any((p) => p.visited.contains(m.name))) m,
    ];

    return SectionCard(
      emoji: '🌟',
      title: 'Top 250 landmarks',
      tint: AppColors.gold,
      subtitle: people.length > 1 ? 'Lit up = visited' : 'Travelog world ranking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in people) TopScoreLine(person: p, total: top.length),
          const SizedBox(height: 10),
          if (visited.isEmpty)
            const EmptyHint('None of the Top 250 yet', emoji: '🗺️')
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: visited.length.clamp(0, 10),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _StripTile(meta: visited[i], people: people),
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                socialRoute<void>((_) => TopLandmarksScreen(uids: uids)),
              ),
              icon: const Icon(Icons.format_list_numbered, size: 18),
              label: Text('See all ${top.length}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkMint)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripTile extends StatelessWidget {
  const _StripTile({required this.meta, required this.people});

  final LandmarkMeta meta;
  final List<TopPerson> people;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 110,
      child: Stack(
        children: [
          Positioned.fill(child: LandmarkImage(name: meta.name, height: 110, radius: 14)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)],
                  stops: [0.45, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Text('#${meta.rank}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          if (people.length > 1)
            Positioned(
              right: 6,
              top: 6,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final p in people)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: VisitDot(person: p, lit: p.visited.contains(meta.name), size: 16),
                  ),
              ]),
            ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 6,
            child: Text(
              meta.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, height: 1.15),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TopFilter { all, first, second, both, neither }

/// The full ranked Top 250 with lit/dim indicators per person.
class TopLandmarksScreen extends StatefulWidget {
  const TopLandmarksScreen({super.key, required this.uids});

  final List<String> uids;

  @override
  State<TopLandmarksScreen> createState() => _TopLandmarksScreenState();
}

class _TopLandmarksScreenState extends State<TopLandmarksScreen> {
  _TopFilter _filter = _TopFilter.all;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final people = TopPerson.resolve(store, widget.uids);
    final top = top250;
    final theme = Theme.of(context);

    bool v(int i, LandmarkMeta m) => i < people.length && people[i].visited.contains(m.name);
    bool everyone(LandmarkMeta m) => people.isNotEmpty && people.every((p) => p.visited.contains(m.name));
    bool nobody(LandmarkMeta m) => people.every((p) => !p.visited.contains(m.name));

    bool keep(_TopFilter f, LandmarkMeta m) => switch (f) {
          _TopFilter.all => true,
          _TopFilter.first => v(0, m),
          _TopFilter.second => v(1, m),
          _TopFilter.both => everyone(m),
          _TopFilter.neither => nobody(m),
        };

    String short(String s) => s.length <= 8 ? s : '${s.substring(0, 7)}…';
    final filters = <(_TopFilter, String)>[
      (_TopFilter.all, 'All'),
      if (people.length == 1) (_TopFilter.first, 'Visited'),
      if (people.length > 1) (_TopFilter.first, people[0].label == 'You' ? 'You' : short(people[0].label)),
      if (people.length > 1) (_TopFilter.second, short(people[1].label)),
      if (people.length > 1) (_TopFilter.both, 'Both'),
      if (people.isNotEmpty) (_TopFilter.neither, people.length > 1 ? 'Neither' : 'Not yet'),
    ];
    final filter = filters.any((f) => f.$1 == _filter) ? _filter : _TopFilter.all;
    final rows = [for (final m in top) if (keep(filter, m)) m];

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WhiteCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in people) TopScoreLine(person: p, total: top.length, avatar: true),
                if (people.isEmpty) const EmptyHint('Profile not available'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ChipBar(
            children: [
              for (final f in filters)
                ChoiceChip(
                  selected: filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                  label: Text('${f.$2} ${top.where((m) => keep(f.$1, m)).length}', maxLines: 1),
                ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Top 250 landmarks', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        itemCount: rows.length + 1 + (rows.isEmpty ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) return header;
          if (rows.isEmpty) return const EmptyHint('Nothing here', emoji: '🔍');
          final m = rows[i - 1];
          final country = GeoData.I.countryByIso3(m.iso3);
          final all = everyone(m);
          final highlight = all ? (people.length > 1 ? AppColors.both : AppColors.mint) : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: highlight == null ? Colors.white : Color.alphaBlend(highlight.withValues(alpha: 0.08), Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: highlight?.withValues(alpha: 0.35) ?? AppColors.line),
            ),
            child: Row(children: [
              SizedBox(
                width: 34,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${m.rank}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: m.rank <= 3 ? AppColors.gold : AppColors.label,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 48, height: 48, child: LandmarkImage(name: m.name, height: 48, radius: 10)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (country?.iso2 != null) ...[Flag(country!.iso2, width: 14, radius: 2), const SizedBox(width: 4)],
                      Expanded(
                        child: Text(
                          [m.city, country?.longName].whereType<String>().join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              for (var k = 0; k < people.length; k++)
                Padding(
                  padding: EdgeInsets.only(left: k == 0 ? 0 : 4),
                  child: VisitDot(person: people[k], lit: v(k, m)),
                ),
            ]),
          );
        },
      ),
    );
  }
}
