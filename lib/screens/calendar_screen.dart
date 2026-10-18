// lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/calendar_memo_model.dart';
import 'package:jidoapp/models/itinerary_entry_model.dart';
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/providers/calendar_provider.dart';
import 'package:jidoapp/providers/itinerary_provider.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
// [Update] Remove EditItineraryScreen, add AiItineraryView
import 'package:jidoapp/screens/ai_itinerary_view.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ValueNotifier<List<dynamic>> _selectedEvents;
  final Map<DateTime, List<dynamic>> _events = {};

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late int _selectedYear;
  late int _selectedMonth;

  // Color Definitions
  final Color _pastelRedMain = const Color(0xFFEF9A9A);
  final Color _pastelRedLightest = const Color(0xFFFFEBEE);
  final Color _pastelRedLighter = const Color(0xFFFFCDD2);

  final Color _pastelBlueMain = const Color(0xFF90CAF9);
  final Color _pastelBlueLightest = const Color(0xFFE3F2FD);
  final Color _pastelBlueLighter = const Color(0xFFBBDEFB);

  final Color _pastelOrangeMain = const Color(0xFFFFCC80);
  final Color _pastelOrangeLightest = const Color(0xFFFFF3E0);
  final Color _pastelOrangeLighter = const Color(0xFFFFE0B2);

  final Color _shadowColor = Colors.grey.withOpacity(0.2);

  // Regex to remove leading emojis from content
  final RegExp _leadingEmojiPattern = RegExp(r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]\s*', unicode: true);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _selectedYear = _focusedDay.year;
    _selectedMonth = _focusedDay.month;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents(
        context.read<ItineraryProvider>().entries,
        context.read<CalendarProvider>().memos,
        context.read<TripLogProvider>().entries,
      );
    });
  }

  void _loadEvents(
      List<ItineraryEntry> itineraries,
      List<CalendarMemoModel> memos,
      List<TripLogEntry> tripLogs,
      ) {
    _events.clear();

    // 1. Manual Itineraries
    for (var entry in itineraries) {
      for (var plan in entry.effectiveDailyPlans) {
        final date = DateTime.utc(plan.date.year, plan.date.month, plan.date.day);

        if (_events[date] == null) _events[date] = [];

        final alreadyExists = _events[date]!.any((e) =>
        e is ItineraryEvent &&
            e.type == ItineraryType.manual &&
            e.itineraryId == entry.id);

        if (!alreadyExists) {
          _events[date]!.add(ItineraryEvent(
            itineraryId: entry.id,
            title: entry.title,
            content: plan.content,
            type: ItineraryType.manual,
            date: date,
          ));
        }
      }
    }

    // 2. AI Trip Logs
    for (var entry in tripLogs) {
      if (entry.generatedItinerary == null || entry.generatedItinerary!.isEmpty) {
        continue;
      }

      final dailyPlans = ItineraryEntry.parseFromText(
        entry.generatedItinerary!,
        entry.date,
      );

      for (var plan in dailyPlans) {
        final date = DateTime.utc(plan.date.year, plan.date.month, plan.date.day);

        if (_events[date] == null) _events[date] = [];

        final alreadyExists = _events[date]!.any((e) =>
        e is ItineraryEvent &&
            e.type == ItineraryType.tripLog &&
            e.tripLogId == entry.id);

        if (!alreadyExists) {
          _events[date]!.add(ItineraryEvent(
            itineraryId: 0,
            tripLogId: entry.id,
            title: entry.title,
            content: plan.content,
            type: ItineraryType.tripLog,
            date: date,
          ));
        }
      }
    }

    // 3. Memos
    for (var memo in memos) {
      try {
        final d = DateTime.parse(memo.date);
        final date = DateTime.utc(d.year, d.month, d.day);
        if (_events[date] == null) _events[date] = [];
        _events[date]!.add(memo);
      } catch (_) {}
    }

    _selectedEvents.value = _getEventsForDay(_selectedDay!);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedYear = focusedDay.year;
        _selectedMonth = focusedDay.month;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _onYearChanged(int? newYear) {
    if (newYear != null) {
      setState(() {
        _selectedYear = newYear;
        _focusedDay = DateTime.utc(_selectedYear, _selectedMonth, 1);
        _selectedDay = _focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    }
  }

  void _onMonthChanged(int? newMonth) {
    if (newMonth != null) {
      setState(() {
        _selectedMonth = newMonth;
        _focusedDay = DateTime.utc(_selectedYear, _selectedMonth, 1);
        _selectedDay = _focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      final newFocusedDay = DateTime.utc(_focusedDay.year, _focusedDay.month - 1, 1);
      _focusedDay = newFocusedDay;
      _selectedYear = newFocusedDay.year;
      _selectedMonth = newFocusedDay.month;
      _selectedDay = newFocusedDay;
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  void _goToNextMonth() {
    setState(() {
      final newFocusedDay = DateTime.utc(_focusedDay.year, _focusedDay.month + 1, 1);
      _focusedDay = newFocusedDay;
      _selectedYear = newFocusedDay.year;
      _selectedMonth = newFocusedDay.month;
      _selectedDay = newFocusedDay;
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  void _showMemoEditPage(BuildContext context, {CalendarMemoModel? memoToEdit}) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _MemoEditPage(
        memoToEdit: memoToEdit,
        selectedDay: memoToEdit != null ? DateTime.parse(memoToEdit.date) : _selectedDay ?? DateTime.now(),
        pastelBlueMain: _pastelBlueMain,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final itineraryProvider = context.watch<ItineraryProvider>();
    final calendarProvider = context.watch<CalendarProvider>();
    final tripLogProvider = context.watch<TripLogProvider>();

    _loadEvents(
      itineraryProvider.entries,
      calendarProvider.memos,
      tripLogProvider.entries,
    );

    final List<int> years = List.generate(21, (index) => DateTime.now().year - 10 + index);
    final List<String> months = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Title replacement for AppBar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              color: _pastelRedMain,
              width: double.infinity,
              child:  Center(
                child: Text(
                  tr('My Calendar'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: Icon(Icons.chevron_left, color: _pastelRedMain), onPressed: _goToPreviousMonth),
                  Row(children: [
                    DropdownButton<int>(value: _selectedYear, items: years.map((y) => DropdownMenuItem(value: y, child: Text(tr('$y')))).toList(), onChanged: _onYearChanged, underline: Container()),
                    const SizedBox(width: 8),
                    DropdownButton<int>(value: _selectedMonth, items: months.mapIndexed((i, m) => DropdownMenuItem(value: i + 1, child: Text(tr(m)))).toList(), onChanged: _onMonthChanged, underline: Container()),
                  ]),
                  IconButton(icon: Icon(Icons.chevron_right, color: _pastelRedMain), onPressed: _goToNextMonth),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 10, offset: const Offset(0, 5))]),
                child: TableCalendar<dynamic>(
                  locale: AppLocale.instance.locale.languageCode,
                  firstDay: DateTime.utc(2010, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  eventLoader: _getEventsForDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: _onDaySelected,
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    setState(() { _selectedYear = focusedDay.year; _selectedMonth = focusedDay.month; });
                  },
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, headerPadding: EdgeInsets.zero, leftChevronVisible: false, rightChevronVisible: false),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    todayDecoration: BoxDecoration(color: _pastelRedMain.withOpacity(0.4), shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: _pastelRedMain, shape: BoxShape.circle),
                    markerDecoration: BoxDecoration(color: _pastelRedMain, shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();

                      final hasManual = events.any((e) => e is ItineraryEvent && e.type == ItineraryType.manual);
                      final hasTripLog = events.any((e) => e is ItineraryEvent && e.type == ItineraryType.tripLog);
                      final hasMemo = events.any((e) => e is CalendarMemoModel);

                      final markerColors = <Color>[];
                      if (hasManual) markerColors.add(_pastelRedMain);
                      if (hasTripLog) markerColors.add(_pastelOrangeMain);
                      if (hasMemo) markerColors.add(_pastelBlueMain);

                      if (markerColors.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        right: 1, bottom: 1,
                        child: Row(
                          children: markerColors.mapIndexed((index, color) {
                            return Container(
                              margin: EdgeInsets.only(left: index > 0 ? 2.0 : 0.0),
                              width: 6.0, height: 6.0,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder<List<dynamic>>(
                valueListenable: _selectedEvents,
                builder: (context, value, _) {
                  if (value.isEmpty) return const SizedBox.shrink();
                  return ListView.builder(
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      final event = value[index];

                      final isMemo = event is CalendarMemoModel;
                      final isEvent = event is ItineraryEvent;
                      final isTripLog = isEvent && (event as ItineraryEvent).type == ItineraryType.tripLog;

                      Color borderColor;
                      Color bgColor;
                      String displayContent;

                      if (isMemo) {
                        borderColor = _pastelBlueLighter;
                        bgColor = _pastelBlueLightest;
                        displayContent = (event as CalendarMemoModel).content;
                      } else {
                        borderColor = isTripLog ? _pastelOrangeLighter : _pastelRedLighter;
                        bgColor = isTripLog ? _pastelOrangeLightest : _pastelRedLightest;

                        final e = event as ItineraryEvent;
                        displayContent = e.content;

                        if (isTripLog) {
                          displayContent = displayContent.replaceAll(_leadingEmojiPattern, '').trim();
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor, width: 1.5),
                          borderRadius: BorderRadius.circular(16.0),
                          color: bgColor,
                          boxShadow: [BoxShadow(color: _shadowColor, blurRadius: 4.0, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          title: Text(
                              isEvent ? (event as ItineraryEvent).title : (event as CalendarMemoModel).title ?? 'Memo',
                              style: const TextStyle(fontWeight: FontWeight.w800)
                          ),
                          subtitle: Text(
                            tr(displayContent),
                          ),
                          onTap: () {
                            if (isEvent) {
                              final e = event as ItineraryEvent;

                              if (e.type == ItineraryType.tripLog) {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => AiItineraryView(
                                    title: e.title,
                                    entryId: e.tripLogId!,
                                    sourceType: ItinerarySourceType.tripLog,
                                    initialDate: e.date,
                                  ),
                                ));
                              } else {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => AiItineraryView(
                                    title: e.title,
                                    entryId: e.itineraryId.toString(),
                                    sourceType: ItinerarySourceType.itinerary,
                                    initialDate: e.date,
                                  ),
                                ));
                              }
                            } else {
                              _showMemoEditPage(context, memoToEdit: event as CalendarMemoModel);
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMemoEditPage(context),
        backgroundColor: _pastelBlueMain,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

enum ItineraryType { manual, tripLog }

class ItineraryEvent {
  final int itineraryId;
  final String? tripLogId;
  final String title;
  final String content;
  final ItineraryType type;
  final DateTime? date;

  ItineraryEvent({
    required this.itineraryId,
    this.tripLogId,
    required this.title,
    required this.content,
    this.type = ItineraryType.manual,
    this.date,
  });
}

class _MemoEditPage extends StatefulWidget {
  final CalendarMemoModel? memoToEdit;
  final DateTime selectedDay;
  final Color pastelBlueMain;

  const _MemoEditPage({super.key, this.memoToEdit, required this.selectedDay, required this.pastelBlueMain});

  @override
  _MemoEditPageState createState() => _MemoEditPageState();
}

class _MemoEditPageState extends State<_MemoEditPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  XFile? _selectedImage;
  String? _existingImageUrl;
  bool _deleteExistingImage = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memoToEdit?.title ?? '');
    _contentController = TextEditingController(text: widget.memoToEdit?.content ?? '');
    _existingImageUrl = widget.memoToEdit?.imageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedImage = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (pickedImage != null) {
      setState(() {
        _selectedImage = pickedImage;
        _existingImageUrl = null;
        _deleteExistingImage = false;
      });
    }
  }

  void _saveMemo() {
    final title = _titleController.text.trim().isEmpty ? null : _titleController.text.trim();
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(tr('Memo content cannot be empty.'))));
      return;
    }
    final calendarProvider = context.read<CalendarProvider>();
    if (widget.memoToEdit == null) {
      calendarProvider.addMemo(widget.selectedDay, title, content, _selectedImage);
    } else {
      calendarProvider.updateMemo(widget.memoToEdit!, title, content, _selectedImage, deleteExistingImage: _deleteExistingImage);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final isEditing = widget.memoToEdit != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.pastelBlueMain,
        title: Text(isEditing ? 'Edit Memo' : 'New Memo', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
        actions: [
          TextButton(
            onPressed: _saveMemo,
            child: Text(tr(isEditing ? 'UPDATE' : 'SAVE'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(DateFormat.yMMMMEEEEd(AppLocale.instance.locale.languageCode).format(widget.selectedDay)), style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: tr('Title'), hintText: tr("Enter memo title"),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.pastelBlueMain, width: 2), borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: tr('Content'), hintText: tr("What happened today?"), alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: widget.pastelBlueMain, width: 2), borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.multiline, minLines: 8, maxLines: 15, style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
             Text(tr('Photo'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_selectedImage != null || _existingImageUrl != null && !_deleteExistingImage)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImage != null ? _selectedImage!.path : _existingImageUrl!),
                      width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(height: 200, color: Colors.grey.shade200, alignment: Alignment.center, child:  Text(tr('Image Load Error'), style: TextStyle(color: Colors.red))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label:  Text(tr('Change Photo'))),
                      ElevatedButton.icon(
                        onPressed: () => setState(() { _selectedImage = null; _existingImageUrl = null; _deleteExistingImage = true; }),
                        icon: const Icon(Icons.delete_forever), label:  Text(tr('Remove Photo')),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.add_a_photo), label:  Text(tr('Add Photo')),
                style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: widget.pastelBlueMain, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
          ],
        ),
      ),
    );
  }
}
