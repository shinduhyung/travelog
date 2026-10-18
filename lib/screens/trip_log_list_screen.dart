// lib/screens/trip_log_list_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/screens/ai_summary_screen.dart';
import 'package:jidoapp/screens/edit_trip_log_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:collection/collection.dart';
import 'package:jidoapp/screens/trip_log_detail_screen.dart';
// 수정된 임포트 경로
import 'package:jidoapp/models/country_model.dart';

class TripLogListScreen extends StatefulWidget {
  const TripLogListScreen({super.key});

  @override
  State<TripLogListScreen> createState() => _TripLogListScreenState();
}

class _TripLogListScreenState extends State<TripLogListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  static const Color orange = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
  }

  List<TripLogEntry> _getFilteredEntries(TripLogProvider provider) {
    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isEmpty) {
      return provider.entries;
    }
    return provider.entries.where((entry) {
      final term = searchTerm;
      bool matches = entry.content.toLowerCase().contains(term) ||
          entry.title.toLowerCase().contains(term);

      if (matches) return true;

      if (entry.summary != null) {
        final summary = entry.summary!;
        if (summary.countries.any((c) => c.name.toLowerCase().contains(term))) return true;
        if (summary.cities.any((cg) => cg.cities.any((cityDetail) => cityDetail.name.toLowerCase().contains(term)))) return true;
        if (summary.airports.any((a) =>
        a.iataCode.toLowerCase().contains(term) ||
            a.name.toLowerCase().contains(term))) return true;
        if (summary.landmarks.any((l) => l.name.toLowerCase().contains(term))) return true;
        if (summary.flights.any((f) => f.airlineName.toLowerCase().contains(term) || f.flights.any((fl) => fl.flightNumber.toLowerCase().contains(term)))) return true;
        if (summary.trains.any((t) => (t.trainCompany?.toLowerCase().contains(term) ?? false) || (t.trainNumber?.toLowerCase().contains(term) ?? false) || (t.origin?.toLowerCase().contains(term) ?? false) || (t.destination?.toLowerCase().contains(term) ?? false))) return true;
        if (summary.buses.any((b) => (b.busCompany?.toLowerCase().contains(term) ?? false) || (b.origin?.toLowerCase().contains(term) ?? false) || (b.destination?.toLowerCase().contains(term) ?? false))) return true;
        if (summary.ferries.any((f) => (f.ferryName?.toLowerCase().contains(term) ?? false) || (f.origin?.toLowerCase().contains(term) ?? false) || (f.destination?.toLowerCase().contains(term) ?? false))) return true;
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final tripLogProvider = Provider.of<TripLogProvider>(context);
    final filteredEntries = _getFilteredEntries(tripLogProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(context),
            Expanded(
              child: tripLogProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: orange))
                  : _buildBody(filteredEntries, tripLogProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: orange),
              onPressed: _stopSearch,
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration:  InputDecoration(
                  hintText: tr('Search logs...'),
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => _searchController.clear(),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 12, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text(
            tr('My Trip Logs'),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: orange,
              letterSpacing: -1.0,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.black87, size: 28),
                onPressed: _startSearch,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: orange, size: 32),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EditTripLogScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<TripLogEntry> entries, TripLogProvider provider) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty ? Icons.note_add_outlined : Icons.search_off_outlined,
              size: 80,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'No logs yet' : 'No results found',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final entry = entries[i];
        return _TripLogCard(
          entry: entry,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TripLogDetailScreen(entryId: entry.id),
            ),
          ),
          onDelete: () => _showDeleteConfirmation(context, provider, entry.id),
          onEdit: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => EditTripLogScreen(entry: entry)),
          ),
          onAiTap: entry.summary == null ? null : () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AiSummaryScreen(entry: entry)),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, TripLogProvider provider, String entryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:  Text(tr('Delete Log')),
        content:  Text(tr('Are you sure you want to delete this trip log?')),
        actions: [
          TextButton(
            child:  Text(tr('Cancel')),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child:  Text(tr('Delete'), style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.deleteEntry(entryId);
            },
          ),
        ],
      ),
    );
  }
}

enum _CardAction { edit, changeFlag, delete }

class _TripLogCard extends StatelessWidget {
  final TripLogEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onAiTap;

  const _TripLogCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    this.onAiTap,
  });

  static const Color orange = Color(0xFFF97316);

  String _isoToEmoji(String isoCode) {
    if (isoCode.length != 2) return '';
    final int offset = 0x1F1E6 - 'A'.codeUnitAt(0);
    final String char1 = String.fromCharCode(isoCode.toUpperCase().codeUnitAt(0) + offset);
    final String char2 = String.fromCharCode(isoCode.toUpperCase().codeUnitAt(1) + offset);
    return char1 + char2;
  }

  Set<String> _getCurrentIsoCodes(BuildContext context) {
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    return entry.summary?.countries.map((countryLog) {
      final match = RegExp(r'\((.*?)\)').firstMatch(countryLog.name);
      final String? isoCode = match?.group(1);
      if (isoCode == null || isoCode == 'N/A') return null;
      final country = countryProvider.allCountries.firstWhereOrNull(
            (c) => c.isoA3.toLowerCase() == isoCode.toLowerCase(),
      );
      return country?.isoA2 ?? countryProvider.allCountries.firstWhereOrNull(
              (c) => c.isoA2.toLowerCase() == isoCode.toLowerCase())?.isoA2;
    }).whereType<String>().toSet() ?? {};
  }

  void _showFlagSelectionDialog(BuildContext context) {
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final currentIsoCodes = _getCurrentIsoCodes(context);

    showDialog(
      context: context,
      builder: (ctx) => _CountrySelectionDialog(
        allCountries: countryProvider.allCountries,
        initialSelection: currentIsoCodes,
        onSelectionChanged: (Set<String> newSelection) {
          // Logic for updating entry flags goes here
          // Example: Provider.of<TripLogProvider>(context, listen: false).updateEntryFlags(entry.id, newSelection.toList());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    String formattedDate = '';
    final formatter = DateFormat.yMMMd();

    if (entry.summary != null) {
      final List<DateTime> potentialDates = [];
      void addDate(String? dateStr) {
        if (dateStr != null && dateStr.isNotEmpty && dateStr != 'Unknown') {
          try {
            potentialDates.add(DateTime.tryParse(dateStr)?.toLocal() ?? entry.date);
          } catch (e) {
            potentialDates.add(entry.date);
          }
        }
      }

      entry.summary!.countries.forEach((c) => addDate(c.arrivalDate));
      entry.summary!.cities.forEach((cg) => cg.cities.forEach((c) => addDate(c.arrivalDate)));
      entry.summary!.flights.forEach((fg) => fg.flights.forEach((f) => addDate(f.flightDate)));
      entry.summary!.trains.forEach((t) => addDate(t.date));
      entry.summary!.buses.forEach((b) => addDate(b.date));
      entry.summary!.ferries.forEach((f) => addDate(f.date));
      entry.summary!.cars.forEach((c) => addDate(c.date));

      if (potentialDates.isEmpty) {
        potentialDates.add(entry.date);
      }

      final uniqueDates = potentialDates.map((date) => DateTime(date.year, date.month, date.day)).toSet().toList();
      uniqueDates.sort();
      final earliestDate = uniqueDates.first;
      final latestDate = uniqueDates.last;

      if (earliestDate.isAtSameMomentAs(latestDate)) {
        formattedDate = formatter.format(earliestDate);
      } else {
        formattedDate = '${formatter.format(earliestDate)} - ${formatter.format(latestDate)}';
      }
    } else {
      formattedDate = formatter.format(entry.date);
    }

    final Set<String> isoCodesA2 = _getCurrentIsoCodes(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: orange.withOpacity(0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(formattedDate),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      if (onAiTap != null)
                        IconButton(
                          icon: const Icon(Icons.auto_awesome, color: orange, size: 20),
                          onPressed: onAiTap,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      _buildPopupMenuButton(context),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isoCodesA2.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: isoCodesA2.take(10).map((code) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      tr(_isoToEmoji(code)),
                      style: const TextStyle(fontSize: 22),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenuButton(BuildContext context) {
    return PopupMenuButton<_CardAction>(
      onSelected: (value) {
        if (value == _CardAction.edit) onEdit();
        if (value == _CardAction.delete) onDelete();
        if (value == _CardAction.changeFlag) _showFlagSelectionDialog(context);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      elevation: 4,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CardAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 22, color: Colors.grey.shade700),
              const SizedBox(width: 12),
               Text(tr('Edit'), style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
         PopupMenuItem(
          value: _CardAction.changeFlag,
          child: Row(
            children: [
              Icon(Icons.outlined_flag, size: 22, color: orange),
              SizedBox(width: 12),
              Text(tr('Change Flags'), style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
        const PopupMenuDivider(),
         PopupMenuItem(
          value: _CardAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 22),
              SizedBox(width: 12),
              Text(tr('Delete'), style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
        ),
      ],
      icon: Icon(Icons.more_horiz, color: Colors.grey.shade400, size: 24),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 170),
    );
  }
}

class _CountrySelectionDialog extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> initialSelection;
  final Function(Set<String>) onSelectionChanged;

  const _CountrySelectionDialog({
    required this.allCountries,
    required this.initialSelection,
    required this.onSelectionChanged,
  });

  @override
  State<_CountrySelectionDialog> createState() => _CountrySelectionDialogState();
}

class _CountrySelectionDialogState extends State<_CountrySelectionDialog> {
  late Set<String> _selectedIsoCodes;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color orange = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    _selectedIsoCodes = Set.from(widget.initialSelection);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _isoToEmoji(String isoCode) {
    if (isoCode.length != 2) return '';
    final int offset = 0x1F1E6 - 'A'.codeUnitAt(0);
    final String char1 = String.fromCharCode(isoCode.toUpperCase().codeUnitAt(0) + offset);
    final String char2 = String.fromCharCode(isoCode.toUpperCase().codeUnitAt(1) + offset);
    return char1 + char2;
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final filteredCountries = widget.allCountries.where((country) {
      return country.name.toLowerCase().contains(_searchQuery);
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title:  Text(tr('Change Flags'), style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: tr('Search Country'),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCountries.length,
                itemBuilder: (context, index) {
                  final country = filteredCountries[index];
                  final isSelected = _selectedIsoCodes.contains(country.isoA2);
                  return CheckboxListTile(
                    value: isSelected,
                    activeColor: orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedIsoCodes.add(country.isoA2);
                        } else {
                          _selectedIsoCodes.remove(country.isoA2);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Text(tr(_isoToEmoji(country.isoA2)), style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(tr(country.name), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel'), style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            widget.onSelectionChanged(_selectedIsoCodes);
            Navigator.of(context).pop();
          },
          child:  Text(tr('Save')),
        ),
      ],
    );
  }
}