// lib/widgets/unesco_visit_editor_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/models/unesco_model.dart';
import 'package:jidoapp/providers/unesco_provider.dart';

class UnescoVisitEditorCard extends StatefulWidget {
  final String siteName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<UnescoSubLocation> availableLocations;

  const UnescoVisitEditorCard({
    super.key,
    required this.siteName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
    required this.availableLocations,
  });

  @override
  State<UnescoVisitEditorCard> createState() => _UnescoVisitEditorCardState();
}

class _UnescoVisitEditorCardState extends State<UnescoVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;
  late String _displayTitle, _displayMemo;
  bool _isEditing = false;
  final ExpansionTileController _expansionTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.visitDate.title;
    _displayMemo  = widget.visitDate.memo ?? '';
    _titleController = TextEditingController(text: _displayTitle);
    _memoController  = TextEditingController(text: _displayMemo);
    _currentPhotos   = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day = widget.visitDate.day;
    if (_displayTitle.isEmpty && _displayMemo.isEmpty && _currentPhotos.isEmpty) {
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    context.read<UnescoProvider>().updateLandmarkVisit(
      widget.siteName, widget.index,
      title: _titleController.text,
      memo: _memoController.text,
      year: _year ?? -9999,
      month: _month ?? -9999,
      day: _day ?? -9999,
      photos: _currentPhotos,
    );
    setState(() {
      _displayTitle = _titleController.text;
      _displayMemo  = _memoController.text;
      _isEditing = false;
    });
  }

  void _cancelEditing() {
    setState(() {
      _titleController.text = _displayTitle;
      _memoController.text  = _displayMemo;
      _year  = widget.visitDate.year;
      _month = widget.visitDate.month;
      _day   = widget.visitDate.day;
      _currentPhotos = List.from(widget.visitDate.photos);
      _isEditing = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final p = await showDatePicker(
      context: context,
      initialDate: DateTime(_year ?? DateTime.now().year, _month ?? 1, _day ?? 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (p != null && mounted) {
      setState(() { _year = p.year; _month = p.month; _day = p.day; });
    }
  }

  void _pickImage(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source);
    if (f != null && mounted) setState(() => _currentPhotos.add(f.path));
  }

  void _toggleLocationInVisit(String locName, bool isSelected) {
    final provider = context.read<UnescoProvider>();
    final currentDetails = List<String>.from(widget.visitDate.visitedDetails);
    if (isSelected) {
      if (!currentDetails.contains(locName)) {
        currentDetails.add(locName);
        if (!provider.isSubLocationVisited(widget.siteName, locName)) {
          provider.toggleSubLocation(widget.siteName, locName);
        }
      }
    } else {
      currentDetails.remove(locName);
    }
    provider.updateLandmarkVisit(widget.siteName, widget.index, visitedDetails: currentDetails);
    setState(() {});
  }

  Widget _buildPhotoPreview(String path, int i) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 60, height: 60, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(path), fit: BoxFit.cover),
        ),
      ),
      if (_isEditing)
        Positioned(top: -6, right: 6,
            child: GestureDetector(
              onTap: () => setState(() => _currentPhotos.removeAt(i)),
              child: Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.cancel, color: Colors.red, size: 22),
              ),
            )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController,
        initiallyExpanded: _isEditing,
        title: Text(
          _displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          'Date: $_year-$_month-$_day',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Visit Record'),
              content: const Text('Are you sure you want to delete this visit record?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_isEditing) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Visit Date: $_year-$_month-$_day',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Edit Date'),
                    onPressed: () => _selectDate(context),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title', isDense: true, filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _memoController,
                  maxLines: 3, minLines: 1,
                  decoration: InputDecoration(
                    labelText: 'Memo', isDense: true, filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ] else if (_displayMemo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_displayMemo, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4)),
                ),

              const SizedBox(height: 12),

              if (widget.availableLocations.isNotEmpty) ...[
                const Text('Locations included in this visit:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                IgnorePointer(
                  ignoring: !_isEditing,
                  child: Wrap(
                    spacing: 8.0, runSpacing: 4.0,
                    children: widget.availableLocations.map((loc) {
                      final isChecked = widget.visitDate.visitedDetails.contains(loc.name);
                      return FilterChip(
                        label: Text(loc.name, style: const TextStyle(fontSize: 11)),
                        selected: isChecked,
                        selectedColor: themeColor.withOpacity(0.2),
                        checkmarkColor: themeColor,
                        onSelected: (bool selected) => _toggleLocationInVisit(loc.name, selected),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_currentPhotos.isNotEmpty || _isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(children: [
                      if (_isEditing)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                    ]),
                  ),
                ),

              const SizedBox(height: 16),

              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (_isEditing) ...[
                  TextButton(
                    onPressed: _cancelEditing,
                    child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0,
                    ),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Record'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeColor,
                      side: BorderSide(color: themeColor.withOpacity(0.5)),
                    ),
                  ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}