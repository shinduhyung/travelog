import 'package:flutter/material.dart';

/// Hides the legacy floating button whenever the visible route owns a back button.
class AutomaticBackGuard extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Listenable changes;
  final Route<dynamic>? Function() currentRoute;
  final Widget child;
  const AutomaticBackGuard({
    super.key,
    required this.navigatorKey,
    required this.changes,
    required this.currentRoute,
    required this.child,
  });
  @override
  State<AutomaticBackGuard> createState() => _AutomaticBackGuardState();
}

class _AutomaticBackGuardState extends State<AutomaticBackGuard> {
  bool _hidden = true, _scheduled = false;
  Animation<double>? _transition;
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed)
      _check();
  }

  @override
  void initState() {
    super.initState();
    widget.changes.addListener(_check);
    _check();
  }

  @override
  void didUpdateWidget(AutomaticBackGuard old) {
    super.didUpdateWidget(old);
    if (old.changes != widget.changes) {
      old.changes.removeListener(_check);
      widget.changes.addListener(_check);
    }
    _check();
  }

  void _check() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      var native = false;
      final route = widget.currentRoute();
      final animation = route is TransitionRoute<dynamic>
          ? route.animation
          : null;
      if (_transition != animation) {
        _transition?.removeStatusListener(_onStatus);
        _transition = animation;
        _transition?.addStatusListener(_onStatus);
      }
      if (animation != null &&
          animation.status != AnimationStatus.completed &&
          animation.status != AnimationStatus.dismissed) {
        if (!_hidden) setState(() => _hidden = true);
        return;
      }
      void visit(Element e) {
        if (native) return;
        final w = e.widget;
        if (w is Offstage && w.offstage) return;
        final ownBack =
            w is BackButton ||
            w is CloseButton ||
            (w is IconButton &&
                w.icon is Icon &&
                const [
                  Icons.arrow_back,
                  Icons.arrow_back_rounded,
                  Icons.arrow_back_ios,
                  Icons.arrow_back_ios_new,
                  Icons.arrow_back_ios_new_rounded,
                  Icons.arrow_back_ios_rounded,
                  Icons.chevron_left,
                  Icons.chevron_left_rounded,
                ].contains((w.icon as Icon).icon));
        if (ownBack && ModalRoute.of(e) == route) {
          native = true;
          return;
        }
        e.visitChildren(visit);
      }

      widget.navigatorKey.currentContext?.visitChildElements(visit);
      if (native != _hidden) setState(() => _hidden = native);
    });
  }

  @override
  void dispose() {
    widget.changes.removeListener(_check);
    _transition?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Offstage(offstage: _hidden, child: widget.child);
}
