import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';

// 정렬 옵션 정의
enum SortOption { alphabet, visitOrder }

// 그룹핑 옵션 정의
enum GroupOption { all, continent }

class FlagsScreen extends StatefulWidget {
  const FlagsScreen({super.key});

  @override
  State<FlagsScreen> createState() => _FlagsScreenState();
}

class _FlagsScreenState extends State<FlagsScreen> {
  // 현재 선택된 옵션 상태
  SortOption _sortOption = SortOption.alphabet;
  GroupOption _groupOption = GroupOption.all;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      appBar: AppBar(
        title:  Text(tr('Visited Flags')),
        actions: [
          // 그룹핑 옵션 메뉴 버튼
          PopupMenuButton<GroupOption>(
            icon: const Icon(Icons.view_module),
            onSelected: (GroupOption result) {
              setState(() {
                _groupOption = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<GroupOption>>[
               PopupMenuItem<GroupOption>(
                value: GroupOption.all,
                child: Text(tr('All')),
              ),
               PopupMenuItem<GroupOption>(
                value: GroupOption.continent,
                child: Text(tr('By Continent')),
              ),
            ],
          ),
          // 정렬 옵션 메뉴 버튼
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (SortOption result) {
              setState(() {
                _sortOption = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
               PopupMenuItem<SortOption>(
                value: SortOption.alphabet,
                child: Text(tr('Alphabetical')),
              ),
               PopupMenuItem<SortOption>(
                value: SortOption.visitOrder,
                child: Text(tr('Visit Order')),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<CountryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 방문한 국가 목록 가져오기
          var visitedCountries = provider.allCountries.where((c) => provider.visitedCountries.contains(c.name)).toList();

          if (visitedCountries.isEmpty) {
            return  Center(child: Text(tr("You haven't visited any countries yet.")));
          }

          // 정렬 로직 (현재는 둘 다 알파벳 순)
          // TODO: 나중에 Visit Order 로직 구현
          visitedCountries.sort((a, b) => a.name.compareTo(b.name));

          // 그룹핑 로직에 따라 다른 UI 표시
          if (_groupOption == GroupOption.all) {
            return _buildGridView(visitedCountries);
          } else {
            return _buildGroupedListView(visitedCountries);
          }
        },
      ),
    );
  }

  // 전체 국기를 하나의 그리드로 표시하는 위젯
  Widget _buildGridView(List<Country> countries) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 3 / 2.5,
      ),
      itemCount: countries.length,
      itemBuilder: (context, index) {
        return _buildFlagCard(countries[index]);
      },
    );
  }

  // 대륙별로 그룹화하여 리스트로 표시하는 위젯
  Widget _buildGroupedListView(List<Country> countries) {
    final Map<String, List<Country>> groupedByContinent = {};
    for (var country in countries) {
      final continent = country.continent ?? 'Others';
      if (groupedByContinent[continent] == null) {
        groupedByContinent[continent] = [];
      }
      groupedByContinent[continent]!.add(country);
    }

    final sortedContinents = groupedByContinent.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedContinents.length,
      itemBuilder: (context, index) {
        final continent = sortedContinents[index];
        final continentCountries = groupedByContinent[continent]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                tr(continent),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // 중첩 스크롤 방지
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 3 / 2.5,
              ),
              itemCount: continentCountries.length,
              itemBuilder: (context, index) {
                return _buildFlagCard(continentCountries[index]);
              },
            ),
          ],
        );
      },
    );
  }

  // 개별 국기 카드 UI
  Widget _buildFlagCard(Country country) {
    // 국기 이미지 URL (isoA2 코드를 소문자로 변환하여 사용)
    final flagUrl = 'https://flagcdn.com/w160/${country.isoA2.toLowerCase()}.png';

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: Image.network(
                flagUrl,
                fit: BoxFit.cover,
                // 이미지 로딩 중일 때 플레이스홀더 표시
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                },
                // 이미지 로딩 실패 시 에러 아이콘 표시
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported, color: Colors.grey);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              tr(country.name),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
