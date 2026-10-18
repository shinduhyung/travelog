// lib/screens/flight_connection_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'add_flight_log_screen.dart';

class FlightConnectionScreen extends StatefulWidget {
  final FlightLog? startNewItineraryWith;

  const FlightConnectionScreen({super.key, this.startNewItineraryWith});

  @override
  State<FlightConnectionScreen> createState() => _FlightConnectionScreenState();
}

class _FlightConnectionScreenState extends State<FlightConnectionScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.startNewItineraryWith != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showItineraryBuilder(context, initialLog: widget.startNewItineraryWith);
      });
    }
  }

  void _showItineraryBuilder(BuildContext context, {FlightLog? initialLog, FlightConnection? existingConnection}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ItineraryBuilderScreen(
          initialLog: initialLog,
          existingConnection: existingConnection,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  String _buildSmartRouteString(List<FlightLog> logs) {
    if (logs.isEmpty) return 'No Route';

    List<String> displayParts = [];
    int airportCount = 0;

    String? currentIata = logs[0].departureIata;
    if (currentIata != null) {
      displayParts.add(currentIata);
      airportCount++;
    }

    for (int i = 0; i < logs.length; i++) {
      if (airportCount >= 6) break;

      final currentLog = logs[i];
      final nextLog = (i + 1 < logs.length) ? logs[i + 1] : null;

      if (currentLog.arrivalIata != null) {
        displayParts.add(" ➔ ");
        displayParts.add(currentLog.arrivalIata!);
        airportCount++;
      }

      if (nextLog != null && nextLog.departureIata != null) {
        if (currentLog.arrivalIata != nextLog.departureIata) {
          if (airportCount < 6) {
            displayParts.add(", ");
            displayParts.add(nextLog.departureIata!);
            airportCount++;
          }
        }
      }
    }

    return displayParts.join("");
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('My Trips'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                   Text(
                    tr('Connected Flights'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Consumer<AirlineProvider>(
                builder: (context, provider, child) {
                  final connections = provider.flightConnections;
                  final allLogs = provider.allFlightLogs;

                  if (connections.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flight_takeoff, size: 80, color: Colors.orange.shade100),
                          const SizedBox(height: 20),
                          Text(
                            tr('No itineraries yet.'),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('Tap the + button to start your journey!'),
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    itemCount: connections.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final connection = connections[index];
                      final logsInConnection = connection.flightLogIds.map((id) {
                        try { return allLogs.firstWhere((log) => log.id == id); } catch (e) { return null; }
                      }).whereType<FlightLog>().toList();

                      if (logsInConnection.isEmpty) return const SizedBox.shrink();

                      final routeText = _buildSmartRouteString(logsInConnection);
                      final startDate = logsInConnection.first.date ?? '';
                      final flightCount = logsInConnection.length;

                      return Dismissible(
                        key: Key(connection.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24.0),
                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title:  Text(tr("Delete Itinerary?")),
                              content:  Text(tr("This action cannot be undone.")),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child:  Text(tr("Keep")),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child:  Text(tr("Delete")),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          provider.removeFlightConnection(connection.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr('Deleted "${connection.name ?? 'Itinerary'}"')),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        child: _buildItineraryCard(context, connection, routeText, startDate, flightCount, index),
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
        onPressed: () => _showItineraryBuilder(context),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildItineraryCard(BuildContext context, FlightConnection connection, String routeText, String startDate, int count, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showItineraryBuilder(context, existingConnection: connection),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              connection.name != null && connection.name!.isNotEmpty ? connection.name! : 'Trip #${index + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (startDate.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tr(startDate),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tr('$count flights'),
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(routeText),
                        style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItineraryBuilderScreen extends StatefulWidget {
  final FlightLog? initialLog;
  final FlightConnection? existingConnection;

  const _ItineraryBuilderScreen({this.initialLog, this.existingConnection});

  @override
  _ItineraryBuilderScreenState createState() => _ItineraryBuilderScreenState();
}

class _ItineraryBuilderScreenState extends State<_ItineraryBuilderScreen> {
  late List<FlightLog?> _flights;
  late List<ConnectionInfo> _connections;
  String? _connectionId;
  late TextEditingController _nameController;

  final Map<String, Color> _typeColors = {
    'Transfer': const Color(0xFFE91E63), // Pink
    'Layover': const Color(0xFF4CAF50),  // Green
    'Stopover': const Color(0xFF00BCD4), // Cyan
  };

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AirlineProvider>(context, listen: false);

    if (widget.existingConnection != null) {
      _connectionId = widget.existingConnection!.id;
      _nameController = TextEditingController(text: widget.existingConnection!.name);
      _connections = List.from(widget.existingConnection!.connections.map((c) => ConnectionInfo(type: c.type, duration: c.duration)));
      _flights = widget.existingConnection!.flightLogIds.map((id) {
        try { return provider.allFlightLogs.firstWhere((log) => log.id == id); } catch (e) { return null; }
      }).toList();
    } else {
      _connectionId = DateTime.now().microsecondsSinceEpoch.toString();
      _nameController = TextEditingController();
      _flights = [widget.initialLog, null];
      _connections = [ConnectionInfo(type: 'Transfer')];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFlight(int index) async {
    final provider = Provider.of<AirlineProvider>(context, listen: false);
    final allLogs = provider.allFlightLogs;
    final allConnections = provider.flightConnections;

    final Set<String> usedInOtherItineraries = {};
    for (final connection in allConnections) {
      if (widget.existingConnection != null && connection.id == widget.existingConnection!.id) {
        continue;
      }
      usedInOtherItineraries.addAll(connection.flightLogIds);
    }

    final Set<String> usedInThisItinerary = {};
    for (int i = 0; i < _flights.length; i++) {
      if (i != index && _flights[i] != null) {
        usedInThisItinerary.add(_flights[i]!.id);
      }
    }

    final availableLogs = allLogs.where((log) {
      final isUsedElsewhere = usedInOtherItineraries.contains(log.id);
      final isUsedHere = usedInThisItinerary.contains(log.id);
      return !isUsedElsewhere && !isUsedHere;
    }).toList();

    final selectedLog = await showDialog<FlightLog>(
        context: context, builder: (context) => _FlightPickerDialog(logs: availableLogs));

    if (selectedLog != null) {
      setState(() {
        _flights[index] = selectedLog;
      });
    }
  }

  void _addFlightSlot() {
    setState(() {
      _flights.add(null);
      _connections.add(ConnectionInfo(type: 'Transfer'));
    });
  }

  void _removeFlightSlot(int index) {
    setState(() {
      _flights.removeAt(index);
      _connections.removeAt(index - 1);
    });
  }

  Future<void> _editDuration(int index) async {
    final currentDuration = _connections[index].duration;
    int initialHours = 0;
    int initialMinutes = 0;
    bool isUnknown = false;

    if (currentDuration == 'Unknown') {
      isUnknown = true;
    } else if (currentDuration != null && currentDuration.isNotEmpty) {
      final parts = currentDuration.split(' ');
      for (var part in parts) {
        if (part.contains('h')) {
          initialHours = int.tryParse(part.replaceAll('h', '')) ?? 0;
        } else if (part.contains('m')) {
          initialMinutes = int.tryParse(part.replaceAll('m', '')) ?? 0;
        }
      }
    }

    final hoursController = TextEditingController(text: initialHours.toString());
    final minutesController = TextEditingController(text: initialMinutes.toString());

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: isUnknown ? 0.3 : 1.0,
                      child: IgnorePointer(
                        ignoring: isUnknown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      controller: hoursController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                      decoration:  InputDecoration(
                                        labelText: tr('Hours'),
                                        floatingLabelBehavior: FloatingLabelBehavior.always,
                                        border: OutlineInputBorder(borderSide: BorderSide.none),
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                             Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(tr(":"), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      controller: minutesController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                      decoration:  InputDecoration(
                                        labelText: tr('Mins'),
                                        floatingLabelBehavior: FloatingLabelBehavior.always,
                                        border: OutlineInputBorder(borderSide: BorderSide.none),
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title:  Text(
                          tr("Unknown"),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        value: isUnknown,
                        activeColor: Colors.orange,
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onChanged: (val) {
                          setStateDialog(() {
                            isUnknown = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:  Text(tr('Cancel'), style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      if (isUnknown) {
                        Navigator.pop(context, "Unknown");
                      } else {
                        final h = int.tryParse(hoursController.text) ?? 0;
                        final m = int.tryParse(minutesController.text) ?? 0;
                        if (h == 0 && m == 0) {
                          Navigator.pop(context, "");
                        } else {
                          String formatted = "";
                          if (h > 0) formatted += "${h}h";
                          if (m > 0) formatted += "${formatted.isNotEmpty ? ' ' : ''}${m}m";
                          Navigator.pop(context, formatted);
                        }
                      }
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold) // ⭐️ 수정됨
                    ),
                    child:  Text(tr('Confirm')),
                  ),
                ],
              );
            }
        );
      },
    );

    if (result != null) {
      setState(() {
        _connections[index].duration = result.isEmpty ? null : result;
      });
    }
  }

  void _saveItinerary() {
    if (_flights.any((log) => log == null)) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(tr('Please select all flights.')), backgroundColor: Colors.red));
      return;
    }

    final provider = Provider.of<AirlineProvider>(context, listen: false);
    final newConnection = FlightConnection(
      id: _connectionId,
      name: _nameController.text.trim(),
      flightLogIds: _flights.map((log) => log!.id).toList(),
      connections: _connections,
    );
    provider.saveFlightConnection(newConnection);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(tr(widget.existingConnection != null ? 'Edit Itinerary' : 'Add Itinerary'),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: tr('Trip Name'),
                hintText: tr('e.g. Summer Vacation'),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.label_outline, color: Colors.orange),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: _flights.length,
              itemBuilder: (context, index) {
                return Column(children: [
                  _buildFlightBox(index, _flights[index]),
                  if (index < _connections.length) _buildConnectionDetails(index),
                ]);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlightSlot,
        label:  Text(tr('Add Flight')),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20.0),
        color: Colors.white,
        child: ElevatedButton(
          onPressed: _saveItinerary,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 0
          ),
          child:  Text(tr('Save Itinerary'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildFlightBox(int index, FlightLog? log) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _pickFlight(index),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: log == null ? _buildEmptyFlightBox(index) : _buildPopulatedFlightBox(log),
            ),
          ),
          if (index >= 2)
            Positioned(
              top: 5, right: 5,
              child: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                  onPressed: () => _removeFlightSlot(index)
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyFlightBox(int index) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.add_circle, color: Colors.orange.shade200, size: 40),
      const SizedBox(height: 10),
      Text(tr('Tap to select Flight ${index + 1}'),
          style: TextStyle(color: Colors.orange.shade800, fontSize: 16, fontWeight: FontWeight.w600)
      ),
    ]),
  );

  Widget _buildPopulatedFlightBox(FlightLog log) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Text(log.airlineName ?? 'Airline', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Text(tr(log.date ?? ''), style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(log.departureIata ?? 'DEP'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const Icon(Icons.flight_takeoff, color: Colors.orange, size: 20),
                  Divider(color: Colors.orange.shade200, thickness: 2),
                  Text(tr(log.flightNumber ?? ''), style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tr(log.arrivalIata ?? 'ARR'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
            ],
          ),
        ],
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddFlightLogScreen(initialLog: log, isEditing: true),
              ),
            );
          },
          icon: const Icon(Icons.edit, size: 16),
          label:  Text(tr("Edit Details")),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      )
    ],
  );

  Widget _buildConnectionDetails(int index) {
    final durationStr = _connections[index].duration;
    final hasDuration = durationStr != null && durationStr.isNotEmpty;
    final currentType = _connections[index].type;
    final themeColor = _typeColors[currentType] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
                color: themeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: themeColor.withOpacity(0.3), width: 1)
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentType,
                isDense: false,
                itemHeight: 50,
                style: TextStyle(color: themeColor, fontWeight: FontWeight.w700, fontSize: 13),
                icon: Icon(Icons.arrow_drop_down, color: themeColor),
                borderRadius: BorderRadius.circular(16),
                items: ['Transfer', 'Layover', 'Stopover'].map((value) {
                  final itemColor = _typeColors[value] ?? Colors.black;
                  return DropdownMenuItem(
                    value: value,
                    child: Text(
                      tr(value),
                      style: TextStyle(
                        color: itemColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) setState(() => _connections[index].type = newValue);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          InkWell(
            onTap: () => _editDuration(index),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: hasDuration ? themeColor.withOpacity(0.08) : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasDuration ? themeColor.withOpacity(0.3) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    size: 16,
                    color: hasDuration ? themeColor : Colors.grey[400],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr(hasDuration
                        ? (durationStr == 'Unknown' ? 'Unknown' : durationStr!)
                        : 'Set Duration'),
                    style: TextStyle(
                      color: hasDuration ? themeColor : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _FlightPickerDialog extends StatelessWidget {
  final List<FlightLog> logs;
  const _FlightPickerDialog({required this.logs});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title:  Text(tr('Select Flight'), style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: logs.isEmpty
            ?  Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(tr('No available flights found.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        )
            : ListView.separated(
          shrinkWrap: true,
          itemCount: logs.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('${log.departureIata} ➔ ${log.arrivalIata}'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(tr('${log.airlineName} ${log.flightNumber} • ${log.date}')),
              onTap: () => Navigator.of(context).pop(log),
              trailing: const Icon(Icons.add_circle_outline, color: Colors.orange),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:  Text(tr('Cancel'), style: TextStyle(color: Colors.grey))
        )
      ],
    );
  }
}