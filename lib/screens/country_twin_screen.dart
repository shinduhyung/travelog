import 'package:jidoapp/social/data/geo_data.dart';
import 'package:jidoapp/widgets/country_twin_result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/discover_scaffold.dart';

class CountryTwinScreen extends StatefulWidget {
  const CountryTwinScreen({super.key});
  @override
  State<CountryTwinScreen> createState() => _CountryTwinScreenState();
}

class _CountryTwinScreenState extends State<CountryTwinScreen> {
  Future<Map<String, dynamic>>? _future;
  String? _signature;
  List<String> _mine = [];
  Map<String, String> _names = {};
  Map<String, dynamic> _mineRecords = {};
  bool _sending = false;
  String? _friendState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<CountryProvider>();
    if (provider.isLoading) return;
    _names = {for (final c in provider.allCountries) c.isoA2: c.name};
    _mine = [
      for (final c in provider.allCountries)
        if (provider.visitDetails[c.name]?.isVisited == true) c.isoA2,
    ]..sort();
    final signature =
        '${FirebaseAuth.instance.currentUser?.uid}|${_mine.join(',')}';
    if (signature != _signature) {
      _signature = signature;
      _future = _load();
    }
  }

  Future<Map<String, dynamic>> _load() async {
    await GeoData.load();
    final result = await FirebaseFunctions.instance
        .httpsCallable(
          'discoverCountryTwin',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call<dynamic>({'countries': _mine});
    final data = Map<String, dynamic>.from(result.data as Map);
    _mineRecords = Map<String, dynamic>.from(data['mine'] as Map? ?? {});
    _friendState = null;
    return data;
  }

  @override
  Widget build(BuildContext context) => DiscoverScaffold(
    appBar: AppBar(title: Text(tr('Travel Soulmate'), maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(
                      'We could not load your travel soulmate. Please try again.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: Text(tr('Try again')),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final raw = snapshot.data!['match'];
        if (raw is! Map)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tr('No matching travel records yet. Add your visited places and try again.'),
              ),
            ),
          );
        final match = Map<String, dynamic>.from(raw);
        return CountryTwinResult(
          match: match,
          names: _names,
          mine: _mine,
          mineRecords: _mineRecords,
          friendState:
              _friendState ?? match['friendState'] as String? ?? 'none',
          sending: _sending,
          onAddFriend: () async {
            if (_sending) return;
            setState(() => _sending = true);
            try {
              final response = await FirebaseFunctions.instance
                  .httpsCallable('socialSendFriendRequest')
                  .call({'uid': match['uid']});
              if (mounted)
                setState(() => _friendState = response.data['state'] as String);
            } catch (_) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr('Could not send request. Please try again.'),
                    ),
                  ),
                );
            } finally {
              if (mounted) setState(() => _sending = false);
            }
          },
        );
      },
    ),
  );
}
