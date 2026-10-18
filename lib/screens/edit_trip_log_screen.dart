import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';

class EditTripLogScreen extends StatefulWidget {
  final TripLogEntry? entry;

  const EditTripLogScreen({super.key, this.entry});

  @override
  State<EditTripLogScreen> createState() => _EditTripLogScreenState();
}

class _EditTripLogScreenState extends State<EditTripLogScreen> {
  final _titleController = TextEditingController();
  late final quill.QuillController _quillController;

  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _isLoading = false;

  // Orange theme colors
  static const Color orange = Color(0xFFF97316);
  static const Color lightOrangeBackground = Color(0xFFFFFBF7);

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    if (widget.entry != null) {
      _titleController.text = widget.entry!.title;
      try {
        final doc =
        quill.Document.fromJson(jsonDecode(widget.entry!.content));
        _quillController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        final doc = quill.Document()..insert(0, widget.entry!.content);
        _quillController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else {
      _titleController.text = '';
      _quillController = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    if (_titleController.text.isEmpty ||
        _quillController.document.isEmpty()) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
            content: Text(tr('Title and log content cannot be empty.'))),
      );
      return;
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final contentJson =
    jsonEncode(_quillController.document.toDelta().toJson());
    final tripLogProvider = context.read<TripLogProvider>();

    try {
      if (widget.entry == null) {
        await tripLogProvider.addEntry(
          title: _titleController.text,
          content: contentJson,
        );
      } else {
        await tripLogProvider.updateEntry(
          id: widget.entry!.id,
          title: _titleController.text,
          content: contentJson,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        // AI 에러인 경우 특별한 메시지 표시
        String errorMessage = 'Failed to save log: $e';
        if (e.toString().contains('AI analysis failed')) {
          errorMessage = 'AI Error: Please try again.\n\nThe AI service failed to analyze your travel log. Please check your content and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(errorMessage)),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: lightOrangeBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        elevation: 1,
        title: Text(
          tr(widget.entry == null ? 'New Trip Log' : 'Edit Trip Log'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title Field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: tr('Trip Title'),
                hintText: tr('e.g., Unforgettable Moments in Italy'),
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: orange, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Editor with visible border
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: orange.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: orange.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: quill.QuillEditor(
                    controller: _quillController,
                    focusNode: _focusNode,
                    scrollController: _scrollController,
                    config: const quill.QuillEditorConfig(
                      padding: EdgeInsets.all(16),
                      scrollable: true,
                      showCursor: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Save Button (always above keyboard)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveLog,
            icon: _isLoading
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(orange),
              ),
            )
                : const Icon(Icons.check_rounded),
            label: Text(tr(_isLoading ? 'Analyzing...' : 'Save & Analyze')),
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }
}