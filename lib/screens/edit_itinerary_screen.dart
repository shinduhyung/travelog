// lib/screens/edit_itinerary_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/itinerary_entry_model.dart';
import 'package:jidoapp/providers/itinerary_provider.dart';
import 'package:provider/provider.dart';

class EditItineraryScreen extends StatefulWidget {
  final ItineraryEntry? entry;

  const EditItineraryScreen({super.key, this.entry});

  @override
  State<EditItineraryScreen> createState() => _EditItineraryScreenState();
}

class _EditItineraryScreenState extends State<EditItineraryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _titleController.text = widget.entry!.title;
      _contentController.text = widget.entry!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _generateAndSaveChanges() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(tr('Title and itinerary content cannot be empty.'))),
      );
      return;
    }
    if (_isLoading) return;

    setState(() { _isLoading = true; });

    final provider = context.read<ItineraryProvider>();

    try {
      if (widget.entry == null) {
        await provider.addEntry(
          title: _titleController.text,
          content: _contentController.text,
        );
      } else {
        await provider.updateEntry(
          id: widget.entry!.id,
          title: _titleController.text,
          content: _contentController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error: $e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(widget.entry == null ? 'New Itinerary' : 'Edit Itinerary')),
        // --- actions (저장 아이콘) 제거 ---
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration:  InputDecoration(
                labelText: tr('Trip Title'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration:  InputDecoration(
                  labelText: tr('Your Travel Plan'),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateAndSaveChanges,
              icon: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(tr(_isLoading ? 'Generating...' : 'Generate Itinerary')),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 18),
              ),
            )
          ],
        ),
      ),
    );
  }
}