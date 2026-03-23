// lib/widgets/landmark_visit_editor_card.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';

class LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<LandmarkSubLocation>? availableLocations;

  const LandmarkVisitEditorCard({
    super.key,
    required this.landmarkName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
    this.availableLocations,
  });

  @override
  State<LandmarkVisitEditorCard> createState() => _LandmarkVisitEditorCardState();
}

class _LandmarkVisitEditorCardState extends State<LandmarkVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;

  // UI에 즉각 반영하기 위한 로컬 상태 변수
  late String _displayTitle;
  late String _displayMemo;
  bool _isEditing = false;

  final ExpansionTileController _expansionTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.visitDate.title;
    _displayMemo = widget.visitDate.memo ?? '';

    _titleController = TextEditingController(text: _displayTitle);
    _memoController = TextEditingController(text: _displayMemo);
    _currentPhotos = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day = widget.visitDate.day;

    // 제목과 메모가 모두 비어있는 새 기록이면 자동으로 수정 모드로 시작
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
    // 1. Provider에 데이터 업데이트
    context.read<LandmarksProvider>().updateLandmarkVisit(
      widget.landmarkName,
      widget.index,
      title: _titleController.text,
      memo: _memoController.text,
      year: _year ?? -9999,
      month: _month ?? -9999,
      day: _day ?? -9999,
      photos: _currentPhotos,
    );

    // 2. 로컬 상태 업데이트 및 보기 모드로 전환
    setState(() {
      _displayTitle = _titleController.text;
      _displayMemo = _memoController.text;
      _isEditing = false;
    });
  }

  void _cancelEditing() {
    // 수정을 취소하고 원래 데이터로 되돌림
    setState(() {
      _titleController.text = _displayTitle;
      _memoController.text = _displayMemo;
      _year = widget.visitDate.year;
      _month = widget.visitDate.month;
      _day = widget.visitDate.day;
      _currentPhotos = List.from(widget.visitDate.photos);
      _isEditing = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime initialDate = DateTime(
      _year ?? DateTime.now().year,
      _month ?? DateTime.now().month,
      _day ?? DateTime.now().day,
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
        _day = picked.day;
      });
    }
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
      setState(() {
        _currentPhotos.add(pickedFile.path);
      });
    }
  }

  void _toggleLocationInVisit(String locName, bool isSelected) {
    final provider = context.read<LandmarksProvider>();
    List<String> currentDetails = List.from(widget.visitDate.visitedDetails);

    if (isSelected) {
      if (!currentDetails.contains(locName)) {
        currentDetails.add(locName);
        if (!provider.isSubLocationVisited(widget.landmarkName, locName)) {
          provider.toggleSubLocation(widget.landmarkName, locName);
        }
      }
    } else {
      currentDetails.remove(locName);
    }

    provider.updateLandmarkVisit(
        widget.landmarkName,
        widget.index,
        visitedDetails: currentDetails
    );

    setState(() {});
  }

  Widget _buildPhotoPreview(String photoPath, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(photoPath), fit: BoxFit.cover),
          ),
        ),
        // 수정 모드일 때만 사진 삭제(X) 버튼 표시
        if (_isEditing)
          Positioned(
            top: -6,
            right: 6,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentPhotos.removeAt(index);
                });
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel, color: Colors.red, size: 22),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController,
        initiallyExpanded: _isEditing,
        title: Text(
          _displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text('Date: $_year-$_month-$_day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Visit Record'),
                content: const Text('Are you sure you want to delete this visit record?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete();
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditing) ...[
                  // --- 수정 모드 (Edit Mode) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Visit Date: $_year-$_month-$_day', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        label: const Text('Edit Date'),
                        onPressed: () => _selectDate(context),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: 'Memo',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ] else ...[
                  // --- 보기 모드 (View Mode) ---
                  if (_displayMemo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _displayMemo,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                      ),
                    ),
                ],

                const SizedBox(height: 12),

                // --- Sub-locations (장소 체크) ---
                if (widget.availableLocations != null && widget.availableLocations!.length > 1) ...[
                  Text("Locations included in this visit:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: !_isEditing, // 보기 모드일 때는 클릭 불가능하게 처리
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: widget.availableLocations!.map((loc) {
                        final isChecked = widget.visitDate.visitedDetails.contains(loc.name);
                        return FilterChip(
                          label: Text(loc.name, style: const TextStyle(fontSize: 12)),
                          selected: isChecked,
                          selectedColor: themeColor.withOpacity(0.2),
                          checkmarkColor: themeColor,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300)
                          ),
                          onSelected: (bool selected) {
                            _toggleLocationInVisit(loc.name, selected);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- 사진 영역 ---
                if (_currentPhotos.isNotEmpty || _isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
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
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // --- 버튼 영역 (수정 / 취소 / 저장) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Record'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: themeColor,
                          side: BorderSide(color: themeColor.withOpacity(0.5)),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}