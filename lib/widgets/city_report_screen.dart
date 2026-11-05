import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/widgets/city_detail_modal.dart';
import 'package:jidoapp/widgets/city_tour_navigation.dart';

/// 앱에 들어 있는 도시 여행 리포트 (tool/city_travel/export_app_reports.py 가 만든 assets/city_reports).
class CityReports {
  static Map<String, String>? _index;

  static Future<Map<String, String>> _load() async {
    if (_index != null) return _index!;
    try {
      final raw = json.decode(await rootBundle.loadString('assets/city_reports/index.json')) as Map;
      _index = {for (final e in raw.entries) '${e.key}': '${e.value}'};
    } catch (_) {
      _index = {};
    }
    return _index!;
  }

  /// 이 도시의 리포트가 있는지
  static Future<bool> has(String city) async => (await _load()).containsKey(city);

  /// 리포트 HTML (압축을 풀어서). 없으면 null.
  static Future<String?> html(String city) async {
    final slug = (await _load())[city];
    if (slug == null) return null;
    try {
      final data = await rootBundle.load('assets/city_reports/$slug.html.gz');
      return utf8.decode(GZipCodec().decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
    } catch (_) {
      return null;
    }
  }
}

/// 도시 리포트를 앱 화면으로 연다.
/// [fromInfo]: opened from that city's Info sheet, so "Info" just goes back to it.
void openCityReport(BuildContext context, String city, {bool fromInfo = false}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CityReportScreen(city: city, fromInfo: fromInfo)));
}

/// 목차(Getting in · Landmarks · Plans ...) 바를 스크롤에 맞춘다:
/// 지금 화면에 열려 있는 구역의 칩만 색이 칠해지고, 그 칩이 보이도록 바가 옆으로 따라간다.
const _tocSyncScript = r"""
(function () {
  var nav = document.querySelector('nav.toc');
  if (!nav) return;
  var style = document.createElement('style');
  style.textContent = '.toc a{transition:background .2s,color .2s,border-color .2s}' +
    '.toc a.hl{background:var(--accent);border-color:var(--accent);color:var(--accent-ink)}';
  document.head.appendChild(style);
  var items = [].slice.call(nav.querySelectorAll('a[href^="#"]')).map(function (a) {
    a.classList.remove('hl');
    return { a: a, el: document.getElementById(a.getAttribute('href').slice(1)) };
  }).filter(function (x) { return x.el; });
  var active = null;
  function pick() {
    var line = nav.offsetHeight + 28;
    var cur = null;
    for (var i = 0; i < items.length; i++) {
      if (items[i].el.getBoundingClientRect().top <= line) cur = items[i];
    }
    var atEnd = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4;
    if (atEnd && items.length) cur = items[items.length - 1];
    return cur;
  }
  function update() {
    var cur = pick();
    if (cur === active) return;
    if (active) active.a.classList.remove('hl');
    active = cur;
    if (!active) return;
    active.a.classList.add('hl');
    var left = active.a.offsetLeft - (nav.clientWidth - active.a.offsetWidth) / 2;
    nav.scrollTo({ left: Math.max(0, left), behavior: 'smooth' });
  }
  var ticking = false;
  window.addEventListener('scroll', function () {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () { ticking = false; update(); });
  }, { passive: true });
  update();
})();
""";

class CityReportScreen extends StatefulWidget {
  const CityReportScreen({super.key, required this.city, this.fromInfo = false});

  final String city;
  final bool fromInfo;

  @override
  State<CityReportScreen> createState() => _CityReportScreenState();
}

class _CityReportScreenState extends State<CityReportScreen> {
  late final Future<String?> _html = CityReports.html(widget.city);

  Future<void> _external(WebUri? uri) async {
    if (uri == null) return;
    final u = Uri.parse(uri.toString());
    if (u.scheme == 'http' || u.scheme == 'https' || u.scheme == 'mailto') {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  void _goInfo() {
    final nav = Navigator.of(context);
    if (widget.fromInfo) {
      nav.pop();
      return;
    }
    final city = context.read<CityProvider>().getCityDetail(widget.city);
    final navContext = nav.context;
    nav.pop();
    if (city != null && navContext.mounted) showCityDetailModal(navContext, city);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          CityViewSwitch(tourSelected: true, onInfo: _goInfo),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    return FutureBuilder<String?>(
        future: _html,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final html = snap.data;
          if (html == null) {
            return Center(child: Text(tr('Could not load this guide.')));
          }
          return InAppWebView(
            initialData: InAppWebViewInitialData(data: html, baseUrl: WebUri('https://travelogapp.uk/'), mimeType: 'text/html', encoding: 'utf-8'),
            initialUserScripts: UnmodifiableListView([
              UserScript(source: _tocSyncScript, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END, forMainFrameOnly: true),
            ]),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: true,
              supportMultipleWindows: true,
              javaScriptCanOpenWindowsAutomatically: true,
              mediaPlaybackRequiresUserGesture: true,
            ),
            // 예약/제휴 링크는 앱 밖(브라우저)에서 연다. 같은 페이지 안의 목차 이동은 그대로 둔다.
            shouldOverrideUrlLoading: (controller, action) async {
              final uri = action.request.url;
              if (uri == null || uri.host == 'travelogapp.uk' || uri.scheme == 'about' || uri.scheme == 'data') {
                return NavigationActionPolicy.ALLOW;
              }
              await _external(uri);
              return NavigationActionPolicy.CANCEL;
            },
            onCreateWindow: (controller, action) async {
              await _external(action.request.url);
              return false;
            },
          );
        },
    );
  }
}
