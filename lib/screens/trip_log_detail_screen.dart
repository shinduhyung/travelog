// lib/screens/trip_log_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/screens/edit_trip_log_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
// Removed: import 'dart:io';
// Added: flutter_quill import
import 'package:flutter_quill/flutter_quill.dart' as quill;
// Added: dart:convert import
import 'dart:convert';

// Changed: StatelessWidget -> StatefulWidget
class TripLogDetailScreen extends StatefulWidget {
  final String entryId;

  const TripLogDetailScreen({super.key, required this.entryId});

  @override
  State<TripLogDetailScreen> createState() => _TripLogDetailScreenState();
}

class _TripLogDetailScreenState extends State<TripLogDetailScreen> {
  // Added: Quill controller & loading state
  quill.QuillController? _controller;
  bool _isLoading = true;
  TripLogEntry? _entry;

  // 추가: Trip Log 테마색 (Orange)
  static const Color orange = Color(0xFFF97316);

  // Removed: _parseContent function
  // Removed: _buildImageErrorWidget function

  @override
  void initState() {
    super.initState();
    // Added: Initialize controller after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntryAndInitController();
    });
  }


  // Added: Load entry and initialize Quill controller
  void _loadEntryAndInitController() {
    if (!mounted) return;

    final provider = context.read<TripLogProvider>();
    final entry = provider.entries.firstWhereOrNull(
          (e) => e.id == widget.entryId,
    );

    if (entry == null) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return;
    }

    _entry = entry;

    // Added: Parse content and initialize controller
    quill.Document doc;
    try {
      // 1. Parse as JSON (Delta format)
      doc = quill.Document.fromJson(jsonDecode(entry.content));
    } catch (e) {
      // 2. Parsing failed → treat as plain text
      doc = quill.Document()..insert(0, entry.content);
    }

    setState(() {
      _controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );

      _isLoading = false;
    });
  }

  @override
  void dispose() {
    // Added: dispose controller
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    // Updated: Use loaded state instead of Consumer
    if (_isLoading || _controller == null) {
      return Scaffold(
        // 변경: 로딩 인디케이터 색상을 오렌지로 통일
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(orange))),
      );
    }

    if (_entry == null) {
      return  Scaffold(
        body: Center(child: Text(tr("Unable to find this entry."))),
      );
    }

    // Guaranteed non-null
    final entry = _entry!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: orange, // 변경: 편집 버튼 아이콘 색상을 오렌지로 통일
            onPressed: () async {
              // Updated: Refresh on return from edit screen
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditTripLogScreen(entry: entry),
                ),
              );
              // Reload controller when returning from editor
              _loadEntryAndInitController();
            },
          ),
        ],
      ),

      // Updated: body structure now includes QuillViewer
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(DateFormat.yMMMMd(AppLocale.instance.locale.languageCode).add_jm().format(entry.date)),
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24, thickness: 1),

            Expanded(
              child: quill.QuillEditor.basic(
                controller: _controller!,
                config: const quill.QuillEditorConfig(
                  scrollable: true,
                  padding: EdgeInsets.zero,
                  showCursor: false,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}