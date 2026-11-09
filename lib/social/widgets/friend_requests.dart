import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/social/data/geo_data.dart';
import 'package:country_flags/country_flags.dart';
import '../services/social_repository.dart';

class FriendRequests extends StatefulWidget {
  final String uid;
  const FriendRequests({super.key, required this.uid});
  @override
  State<FriendRequests> createState() => _FriendRequestsState();
}

class _FriendRequestsState extends State<FriendRequests> {
  late Stream<List<Map<String, dynamic>>> _stream;
  final _busy = <String>{};
  @override
  void initState() {
    super.initState();
    _stream = SocialRepository.instance.watchFriendRequests(widget.uid);
  }

  @override
  void didUpdateWidget(FriendRequests old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid)
      _stream = SocialRepository.instance.watchFriendRequests(widget.uid);
  }

  Future<void> _respond(String uid, bool accept) async {
    setState(() => _busy.add(uid));
    try {
      await SocialRepository.instance.respondFriendRequest(uid, accept);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Could not update request. Please try again.')),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F5F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      color: Color(0xFF008F83),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${tr('Friend requests')} (${snapshot.data!.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                for (final row in snapshot.data!) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if ((GeoData.isLoaded
                              ? GeoData.I
                                    .countryByIso3(
                                      row['nationality'] as String?,
                                    )
                                    ?.iso2
                              : null)
                          case final String code)
                        SizedBox(
                          width: 30,
                          height: 21,
                          child: CountryFlag.fromCountryCode(code),
                        )
                      else
                        const Icon(Icons.person_outline_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr('Fellow traveler'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy.contains(row['uid'])
                              ? null
                              : () => _respond(row['uid'] as String, false),
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(tr('Decline'), maxLines: 1)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy.contains(row['uid'])
                              ? null
                              : () => _respond(row['uid'] as String, true),
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(tr('Accept'), maxLines: 1)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
}
