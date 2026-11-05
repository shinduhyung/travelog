import 'package:flutter/material.dart';

/// Routes with their own app bar do not need the app-wide floating back button.
final nativeBackRoutes = ValueNotifier<Set<Route<dynamic>>>({});

class NativeBackScope extends StatefulWidget {
  final Widget child;
  const NativeBackScope({super.key, required this.child});

  @override
  State<NativeBackScope> createState() => _NativeBackScopeState();
}

class _NativeBackScopeState extends State<NativeBackScope> {
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _route = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route != null) {
        nativeBackRoutes.value = {...nativeBackRoutes.value, route};
      }
    });
  }

  @override
  void dispose() {
    final route = _route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nativeBackRoutes.value = {...nativeBackRoutes.value}..remove(route);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
