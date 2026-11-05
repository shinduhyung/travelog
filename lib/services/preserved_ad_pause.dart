/// A shared clock freeze: overlapping screens exclude elapsed time only once.
class PreservedAdPause {
  final Set<Object> _owners = {};
  DateTime? _startedAt;
  bool get isPaused => _owners.isNotEmpty;

  void begin(Object owner, DateTime now) {
    if (_owners.isEmpty) _startedAt = now;
    _owners.add(owner);
  }

  DateTime? end(Object owner, DateTime now, DateTime? anchor) {
    if (!_owners.remove(owner) || _owners.isNotEmpty) return anchor;
    final started = _startedAt;
    _startedAt = null;
    if (started == null || anchor == null) return anchor;
    final from = anchor.isAfter(started) ? anchor : started;
    return now.isAfter(from) ? anchor.add(now.difference(from)) : anchor;
  }
}
