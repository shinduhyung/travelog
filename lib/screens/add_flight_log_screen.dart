// lib/screens/add_flight_log_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/flight_info.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/services/aero_data_box_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart'; // TODO: 실제 경로로 수정 (subscription_sheet.dart 파일 위치 확인)
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AddFlightLogScreen extends StatefulWidget {
  final FlightLog? initialLog;
  final bool isEditing;
  final String? initialAirlineName;
  final bool initialIsMileage;
  final bool startWithUpgradeView;
  final String? scrollToSection;
  final String? defaultUpgradeAirline;

  const AddFlightLogScreen({
    super.key,
    this.initialLog,
    this.isEditing = false,
    this.initialAirlineName,
    this.initialIsMileage = false,
    this.startWithUpgradeView = false,
    this.scrollToSection,
    this.defaultUpgradeAirline,
  });

  @override
  State<AddFlightLogScreen> createState() => _AddFlightLogScreenState();
}

class _AddFlightLogScreenState extends State<AddFlightLogScreen> {
  final Map<String, GlobalKey> _sectionKeys = {
    'Ticket': GlobalKey(),
  };

  final Map<String, Color> _seatClassColors = {
    'Economy': Colors.blue.shade700,
    'Premium Economy': Colors.indigo.shade700,
    'Business': Colors.purple.shade700,
    'First': Colors.pink.shade700,
  };

  final _formKey = GlobalKey<FormState>();

  final _dateController = TextEditingController();
  final _departureHoursController = TextEditingController();
  final _departureMinutesController = TextEditingController();
  final _arrivalHoursController = TextEditingController();
  final _arrivalMinutesController = TextEditingController();
  final _departureAirportController = TextEditingController();
  final _destinationAirportController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _airlineController = TextEditingController();
  final _aircraftController = TextEditingController();
  final _durationHoursController = TextEditingController();
  final _durationMinutesController = TextEditingController();
  final _delayHoursController = TextEditingController();
  final _delayMinutesController = TextEditingController();
  final _departureTerminalController = TextEditingController();
  final _departureGateController = TextEditingController();
  final _arrivalTerminalController = TextEditingController();
  final _arrivalGateController = TextEditingController();
  final _memoController = TextEditingController();

  final _bookingDateController = TextEditingController();
  final _ticketPriceController = TextEditingController();
  final _vatController = TextEditingController();
  final _mileageAirlineController = TextEditingController();

  final _upgradeDateController = TextEditingController();
  final _upgradePriceController = TextEditingController();
  final _upgradeVatController = TextEditingController();
  final _upgradeMileageAirlineController = TextEditingController();

  bool _isDateUnknown = false;
  bool _isDepartureTimeUnknown = false;
  bool _isArrivalTimeUnknown = false;
  bool _isFlightNumberUnknown = false;
  bool _isAircraftUnknown = true;
  bool _isAirlineUnknown = false;
  bool _isDurationUnknown = false;
  bool _isSeatClassUnknown = false;
  bool _isDepartureTerminalUnknown = true;
  bool _isDepartureGateUnknown = true;
  bool _isArrivalTerminalUnknown = true;
  bool _isArrivalGateUnknown = true;

  bool _isTicketPriceUnknown = true;
  bool _isBookingDateUnknown = true;
  bool _isMileageTicket = false;
  bool _isVatUnknown = true;

  bool _wasUpgraded = false;
  bool _isUpgradePriceUnknown = true;
  bool _isUpgradeDateUnknown = true;
  bool _isUpgradeInMiles = false;
  bool _isUpgradeVatUnknown = true;

  bool _isFastSearch = false;

  List<String> _aircraftModels = [];
  String? _selectedAircraft;
  bool _isDirectAircraftInput = false;
  String _selectedSeatClass = 'Economy';
  bool _hasDelay = false;
  bool _isCanceled = false;
  bool _isLoading = false;
  String? _ticketPhotoPath;
  List<String> _flightLogPhotos = [];
  double _rating = 0.0;
  bool _isThroughTicket = false;
  Itinerary? _currentItinerary;
  List<FlightLog> _linkedLogs = [];

  final AeroDataBoxService _aeroDataBoxService = AeroDataBoxService();

  @override
  void initState() {
    super.initState();
    _loadAircraftModels().then((_) {
      if (widget.isEditing && widget.initialLog != null) {
        _populateFieldsForEditing();
      } else {
        _initializeNewLog();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.isEditing && widget.startWithUpgradeView) {
          if (mounted) {
            setState(() {
              if (widget.initialLog?.upgradePrice == null) {
                _isUpgradeInMiles = true;
                _upgradeMileageAirlineController.text = widget.defaultUpgradeAirline ?? '';
              }
              if (_selectedSeatClass == 'Economy') {
                _selectedSeatClass = 'Premium Economy';
              }
              _wasUpgraded = true;
              if (widget.initialLog?.upgradeDate == null || widget.initialLog!.upgradeDate!.isEmpty) {
                _isUpgradeDateUnknown = false;
                _upgradeDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
              }
            });
          }
        }

        if (widget.scrollToSection != null && _sectionKeys.containsKey(widget.scrollToSection)) {
          final key = _sectionKeys[widget.scrollToSection]!;
          if (key.currentContext != null) {
            Scrollable.ensureVisible(
              key.currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    });
  }

  Future<void> _loadAircraftModels() async {
    final String response = await rootBundle.loadString('assets/aircraft_models.json');
    final data = await json.decode(response) as List;
    final models = data.map((e) => e.toString()).toList();
    models.add('Direct Input');
    if(mounted){
      setState(() {
        _aircraftModels = models;
      });
    }
  }

  void _initializeNewLog() {
    setState(() {
      _isDateUnknown = false;
      _isDepartureTimeUnknown = false;
      _isArrivalTimeUnknown = false;
      _isFlightNumberUnknown = false;
      _isAircraftUnknown = true;
      _isAirlineUnknown = false;
      _isDurationUnknown = false;
      _isSeatClassUnknown = false;
      _isTicketPriceUnknown = true;
      _isBookingDateUnknown = true;
      _isDepartureTerminalUnknown = true;
      _isDepartureGateUnknown = true;
      _isArrivalTerminalUnknown = true;
      _isArrivalGateUnknown = true;
      _isVatUnknown = true;

      if (widget.initialAirlineName != null && widget.initialAirlineName!.isNotEmpty) {
        _airlineController.text = widget.initialAirlineName!;
        _isAirlineUnknown = false;
      }

      if (widget.initialIsMileage) {
        _isMileageTicket = true;
        _isTicketPriceUnknown = false;
        if (_airlineController.text.isNotEmpty) {
          _mileageAirlineController.text = _airlineController.text;
        }
      }
    });
  }

  void _populateFieldsForEditing() {
    final log = widget.initialLog!;
    final provider = Provider.of<AirlineProvider>(context, listen: false);

    if (log.itineraryId != null) {
      try {
        _currentItinerary = provider.itineraries.firstWhere((i) => i.id == log.itineraryId);
        _isThroughTicket = true;
        _linkedLogs = _currentItinerary!.flightLogIds.where((id) => id != log.id).map((id) => provider.getFlightLogById(id)).whereType<FlightLog>().toList();
        if (_currentItinerary!.ticketPrice != null) {
          _isTicketPriceUnknown = false;
          _ticketPriceController.text = _currentItinerary!.ticketPrice!.toStringAsFixed(0);
        } else {
          _isTicketPriceUnknown = true;
        }
        _isMileageTicket = _currentItinerary!.isMileageTicket;
        if (_isMileageTicket) {
          _mileageAirlineController.text = log.mileageAirline ?? log.airlineName ?? '';
        }
        if (_currentItinerary!.vat != null) {
          _isVatUnknown = false;
          _vatController.text = _currentItinerary!.vat!.toStringAsFixed(0);
        } else {
          _isVatUnknown = true;
        }
        if (_currentItinerary!.bookingDate != null && _currentItinerary!.bookingDate != 'Unknown') {
          _isBookingDateUnknown = false;
          _bookingDateController.text = _currentItinerary!.bookingDate!;
        } else {
          _isBookingDateUnknown = true;
        }
      } catch (e) {
        log.itineraryId = null;
        _isThroughTicket = false;
      }
    }

    _updateFieldState(log.date, _dateController, (val) => _isDateUnknown = val);
    _isDepartureTimeUnknown = log.scheduledDepartureTime == 'Unknown';
    _isArrivalTimeUnknown = log.scheduledArrivalTime == 'Unknown';
    _updateTimeFieldState(log.scheduledDepartureTime, _departureHoursController, _departureMinutesController, (val) {});
    _updateTimeFieldState(log.scheduledArrivalTime, _arrivalHoursController, _arrivalMinutesController, (val) {});
    _updateFieldState(log.flightNumber, _flightNumberController, (val) => _isFlightNumberUnknown = val);
    _updateFieldState(log.airlineName, _airlineController, (val) => _isAirlineUnknown = val);
    _updateAircraftState(log.aircraft);
    _departureAirportController.text = log.departureIata ?? '';
    _destinationAirportController.text = log.arrivalIata ?? '';
    _isCanceled = log.isCanceled;
    _updateFieldState(log.duration, null, (val) => _isDurationUnknown = val, parseDuration: true);
    _hasDelay = log.delay != null && log.delay!.isNotEmpty;
    if (_hasDelay) _parseDurationString(log.delay, _delayHoursController, _delayMinutesController);
    _updateFieldState(log.departureTerminal, _departureTerminalController, (val) => _isDepartureTerminalUnknown = val);
    _updateFieldState(log.departureGate, _departureGateController, (val) => _isDepartureGateUnknown = val);
    _updateFieldState(log.arrivalTerminal, _arrivalTerminalController, (val) => _isArrivalTerminalUnknown = val);
    _updateFieldState(log.arrivalGate, _arrivalGateController, (val) => _isArrivalGateUnknown = val);
    _updateFieldState(log.seatClass, null, (val) => _isSeatClassUnknown = val);
    if (!_isSeatClassUnknown) _selectedSeatClass = log.seatClass ?? 'Economy';

    if (!_isThroughTicket) {
      _updateFieldState(log.bookingDate, _bookingDateController, (val) => _isBookingDateUnknown = val);
      if (log.ticketPrice != null) {
        _isTicketPriceUnknown = false;
        _ticketPriceController.text = log.ticketPrice!.toStringAsFixed(0);
      } else {
        _isTicketPriceUnknown = true;
      }
      _isMileageTicket = log.isMileageTicket;
      if (_isMileageTicket) {
        _mileageAirlineController.text = log.mileageAirline ?? log.airlineName ?? '';
      }
      if (log.vat != null) {
        _isVatUnknown = false;
        _vatController.text = log.vat!.toStringAsFixed(0);
      } else {
        _isVatUnknown = true;
      }
    }

    if (log.upgradePrice != null) {
      _wasUpgraded = true;
      _isUpgradePriceUnknown = false;
      _upgradePriceController.text = log.upgradePrice!.toStringAsFixed(0);
      _isUpgradeInMiles = log.isUpgradedWithMiles;
      _updateFieldState(log.upgradeDate, _upgradeDateController, (val) => _isUpgradeDateUnknown = val);
      if (_isUpgradeInMiles) {
        _upgradeMileageAirlineController.text = log.upgradeMileageAirline ?? log.airlineName ?? '';
      }
      if (log.upgradeVat != null) {
        _isUpgradeVatUnknown = false;
        _upgradeVatController.text = log.upgradeVat!.toStringAsFixed(0);
      }
    }

    _ticketPhotoPath = log.ticketPhoto;
    _memoController.text = log.memo ?? '';
    _flightLogPhotos = List.from(log.photos ?? []);
    _rating = log.rating;

    setState(() {});
  }

  void _updateAircraftState(String? aircraftModel) {
    if (aircraftModel == null || aircraftModel.isEmpty || aircraftModel == 'Unknown') {
      _isAircraftUnknown = true;
      _selectedAircraft = null;
      _isDirectAircraftInput = false;
      _aircraftController.clear();
    } else {
      _isAircraftUnknown = false;
      if (_aircraftModels.contains(aircraftModel)) {
        _selectedAircraft = aircraftModel;
        _isDirectAircraftInput = false;
      } else {
        _selectedAircraft = 'Direct Input';
        _isDirectAircraftInput = true;
      }
      _aircraftController.text = aircraftModel;
    }
  }

  void _updateFieldState(String? value, TextEditingController? controller, Function(bool) setUnknown, {bool parseDuration = false}) {
    if (value == null || value == 'Unknown' || value.isEmpty) {
      setUnknown(true);
    } else {
      setUnknown(false);
      if (controller != null) controller.text = value;
      if (parseDuration) _parseDurationString(value, _durationHoursController, _durationMinutesController);
    }
  }

  void _updateTimeFieldState(String? timeValue, TextEditingController h, TextEditingController m, Function(bool) setUnknown) {
    if (timeValue == null || timeValue == 'Unknown' || timeValue.isEmpty) {
      setUnknown(true);
      h.clear();
      m.clear();
    } else {
      setUnknown(false);
      final parts = timeValue.split(':');
      if (parts.length == 2) {
        h.text = parts[0];
        m.text = parts[1];
      }
    }
  }

  void _parseDurationString(String? durationStr, TextEditingController hoursController, TextEditingController minutesController) {
    if (durationStr == null) return;
    final parts = durationStr.split(' ');
    for (var part in parts) {
      if (part.endsWith('h')) hoursController.text = part.replaceAll('h', '');
      if (part.endsWith('m')) minutesController.text = part.replaceAll('m', '');
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _departureHoursController.dispose();
    _departureMinutesController.dispose();
    _arrivalHoursController.dispose();
    _arrivalMinutesController.dispose();
    _departureAirportController.dispose();
    _destinationAirportController.dispose();
    _flightNumberController.dispose();
    _airlineController.dispose();
    _aircraftController.dispose();
    _bookingDateController.dispose();
    _ticketPriceController.dispose();
    _durationHoursController.dispose();
    _durationMinutesController.dispose();
    _delayHoursController.dispose();
    _delayMinutesController.dispose();
    _departureTerminalController.dispose();
    _departureGateController.dispose();
    _arrivalTerminalController.dispose();
    _arrivalGateController.dispose();
    _memoController.dispose();
    _vatController.dispose();
    _mileageAirlineController.dispose();
    _upgradeDateController.dispose();
    _upgradePriceController.dispose();
    _upgradeVatController.dispose();
    _upgradeMileageAirlineController.dispose();
    super.dispose();
  }

  Future<void> _findFlight() async {
    if (_isDateUnknown) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a date to search.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }
    if (_isFlightNumberUnknown) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a flight number to search.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final flightInfo = await _aeroDataBoxService.getFlightInfo(_flightNumberController.text, _dateController.text);
      if (flightInfo != null && mounted) {
        setState(() {
          _flightNumberController.text = _flightNumberController.text.toUpperCase();
          _airlineController.text = flightInfo.airlineName; _isAirlineUnknown = false;
          _updateAircraftState(flightInfo.aircraftModel);
          _departureAirportController.text = flightInfo.departureIata;
          _destinationAirportController.text = flightInfo.arrivalIata;
          _updateTimeFieldState(flightInfo.scheduledDepartureTime, _departureHoursController, _departureMinutesController, (val) => _isDepartureTimeUnknown = val);
          _updateTimeFieldState(flightInfo.scheduledArrivalTime, _arrivalHoursController, _arrivalMinutesController, (val) => _isArrivalTimeUnknown = val);
          if (flightInfo.status != null) {
            _isCanceled = flightInfo.status!.toLowerCase() == 'cancelled' || flightInfo.status!.toLowerCase() == 'canceled';
          }
          if (flightInfo.duration != null) {
            _isDurationUnknown = false;
            _parseDurationString(flightInfo.duration, _durationHoursController, _durationMinutesController);
          }
          if (flightInfo.delay != null) {
            _hasDelay = true;
            _parseDurationString(flightInfo.delay, _delayHoursController, _delayMinutesController);
          } else {
            _hasDelay = false;
          }
          if (flightInfo.departureTerminal != null) {
            _isDepartureTerminalUnknown = false;
            _departureTerminalController.text = flightInfo.departureTerminal!;
          }
          if (flightInfo.departureGate != null) {
            _isDepartureGateUnknown = false;
            _departureGateController.text = flightInfo.departureGate!;
          }
          if (flightInfo.arrivalTerminal != null) {
            _isArrivalTerminalUnknown = false;
            _arrivalTerminalController.text = flightInfo.arrivalTerminal!;
          }
          if (flightInfo.arrivalGate != null) {
            _isArrivalGateUnknown = false;
            _arrivalGateController.text = flightInfo.arrivalGate!;
          }
          if (_isMileageTicket) {
            _mileageAirlineController.text = flightInfo.airlineName;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flight info synced!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Flight not found.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _saveFlightLog() {
    if (!_formKey.currentState!.validate()) return;
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);

    if (_isThroughTicket) {
      final currentLogId = widget.initialLog?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
      final allLinkedIds = [currentLogId, ..._linkedLogs.map((log) => log.id)];

      final itinerary = _currentItinerary ?? Itinerary(flightLogIds: []);
      itinerary.flightLogIds = allLinkedIds.toSet().toList();
      itinerary.ticketPrice = _isTicketPriceUnknown ? null : double.tryParse(_ticketPriceController.text);
      itinerary.isMileageTicket = _isMileageTicket;
      itinerary.vat = _isVatUnknown ? null : double.tryParse(_vatController.text);
      itinerary.bookingDate = _isBookingDateUnknown ? 'Unknown' : _bookingDateController.text;

      airlineProvider.addOrUpdateItinerary(itinerary);

      final currentLog = _buildFlightLogObject(itineraryId: itinerary.id);
      if (widget.isEditing) {
        airlineProvider.updateFlightLog(widget.initialLog!, currentLog);
      } else {
        airlineProvider.addDetailedFlightLog(currentLog.airlineName ?? 'Unknown', currentLog);
      }

    } else {
      if (widget.initialLog?.itineraryId != null) {
        final oldItinerary = airlineProvider.itineraries.firstWhere((i) => i.id == widget.initialLog!.itineraryId);
        oldItinerary.flightLogIds.remove(widget.initialLog!.id);
        if (oldItinerary.flightLogIds.length < 2) {
          airlineProvider.removeItinerary(oldItinerary.id);
        } else {
          airlineProvider.addOrUpdateItinerary(oldItinerary);
        }
      }
      final newLog = _buildFlightLogObject();
      if (widget.isEditing) {
        airlineProvider.updateFlightLog(widget.initialLog!, newLog);
      } else {
        airlineProvider.addDetailedFlightLog(newLog.airlineName ?? 'Unknown', newLog);
      }
    }

    if (!widget.isEditing && !_isCanceled) {
      final DateTime? date = DateTime.tryParse(_dateController.text);
      if (date != null) {
        if (_departureAirportController.text.isNotEmpty && _departureAirportController.text != 'Unknown') {
          airportProvider.addVisitEntry(
              _departureAirportController.text,
              year: date.year,
              month: date.month,
              day: date.day
          );
        }
        if (_destinationAirportController.text.isNotEmpty && _destinationAirportController.text != 'Unknown') {
          airportProvider.addVisitEntry(
              _destinationAirportController.text,
              year: date.year,
              month: date.month,
              day: date.day
          );
        }
      }
    }

    Navigator.of(context).pop();
  }

  FlightLog _buildFlightLogObject({String? itineraryId}) {
    String? formatDuration(TextEditingController h, TextEditingController m) {
      if (h.text.isEmpty && m.text.isEmpty) return null;
      return ('${h.text}h ${m.text}m').trim();
    }
    String formatTime(TextEditingController h, TextEditingController m) {
      final hour = h.text.padLeft(2, '0');
      final minute = m.text.padLeft(2, '0');
      return '$hour:$minute';
    }

    return FlightLog(
      id: widget.initialLog?.id,
      flightNumber: _isFlightNumberUnknown ? 'Unknown' : _flightNumberController.text.toUpperCase(),
      date: _isDateUnknown ? 'Unknown' : _dateController.text,
      airlineName: _isAirlineUnknown ? 'Unknown' : _airlineController.text,
      aircraft: _isAircraftUnknown ? 'Unknown' : _aircraftController.text,
      departureIata: _departureAirportController.text.toUpperCase(),
      arrivalIata: _destinationAirportController.text.toUpperCase(),
      scheduledDepartureTime: _isDepartureTimeUnknown ? 'Unknown' : formatTime(_departureHoursController, _departureMinutesController),
      scheduledArrivalTime: _isArrivalTimeUnknown ? 'Unknown' : formatTime(_arrivalHoursController, _arrivalMinutesController),
      duration: _isCanceled || _isDurationUnknown ? 'Unknown' : formatDuration(_durationHoursController, _durationMinutesController),
      delay: _isCanceled || !_hasDelay ? null : formatDuration(_delayHoursController, _delayMinutesController),
      isCanceled: _isCanceled,
      departureTerminal: _isDepartureTerminalUnknown ? 'Unknown' : _departureTerminalController.text,
      departureGate: _isDepartureGateUnknown ? 'Unknown' : _departureGateController.text,
      arrivalTerminal: _isArrivalTerminalUnknown ? 'Unknown' : _arrivalTerminalController.text,
      arrivalGate: _isArrivalGateUnknown ? 'Unknown' : _arrivalGateController.text,
      seatClass: _isSeatClassUnknown ? 'Unknown' : _selectedSeatClass,
      ticketPrice: _isTicketPriceUnknown ? null : double.tryParse(_ticketPriceController.text),
      isMileageTicket: _isMileageTicket,
      mileageAirline: _isMileageTicket ? _mileageAirlineController.text : null,
      vat: _isVatUnknown ? null : double.tryParse(_vatController.text),
      bookingDate: _isBookingDateUnknown ? 'Unknown' : _bookingDateController.text,
      ticketPhoto: _ticketPhotoPath,
      memo: _memoController.text,
      photos: _flightLogPhotos,
      rating: _rating,
      itineraryId: itineraryId,
      upgradePrice: _wasUpgraded && !_isUpgradePriceUnknown ? double.tryParse(_upgradePriceController.text) : null,
      isUpgradedWithMiles: _wasUpgraded && _isUpgradeInMiles,
      upgradeVat: _wasUpgraded && !_isUpgradePriceUnknown ? double.tryParse(_upgradeVatController.text) : null,
      upgradeDate: _wasUpgraded && !_isUpgradeDateUnknown ? _upgradeDateController.text : null,
      upgradeMileageAirline: _wasUpgraded && _isUpgradeInMiles ? _upgradeMileageAirlineController.text : null,
    );
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Widget _buildFastSearchCheckbox() {
    const MaterialColor specialColor = Colors.cyan;
    final bool isFastSearch = _isFastSearch;
    final bool isPremium = context.watch<SubscriptionService>().isPremium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: isFastSearch ? 6 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: isFastSearch ? BorderSide(color: specialColor.shade400, width: 2) : BorderSide.none,
          ),
          color: isFastSearch ? specialColor.withOpacity(0.1) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: CheckboxListTile(
              title: Row(
                children: [
                  Icon(
                    Icons.flash_on,
                    color: isFastSearch ? specialColor.shade700 : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Fast Search',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isFastSearch ? specialColor.shade900 : Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (!isPremium) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.lock,
                      size: 15,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
              value: isFastSearch,
              onChanged: (val) {
                if (!isPremium) {
                  SubscriptionSheet.show(context, triggerContext: 'fast_search_lock');
                  return;
                }
                setState(() {
                  _isFastSearch = val ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.trailing,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (isFastSearch)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 12.0),
            child: Text(
              'Only searching for flights within the last 6 months',
              style: TextStyle(fontSize: 12, color: specialColor.shade700, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusCheckbox(String title, bool value, ValueChanged<bool?>? onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.deepPurple,
            checkColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildMyRatingSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'My Score: ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade700),
                ),
                Text(
                  _rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.amber),
                ),
                const Icon(Icons.star, color: Colors.amber, size: 28),
              ],
            ),
            const SizedBox(height: 16),
            RatingBar.builder(
              initialRating: _rating,
              minRating: 0,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 6.0),
              itemBuilder: (context, index) {
                return Icon(
                  Icons.star_rate_rounded,
                  color: (index < _rating) ? Colors.amber.shade700 : Colors.grey.shade300,
                  size: 36,
                );
              },
              onRatingUpdate: (rating) => setState(() => _rating = rating),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    bool showUpgradeSection = ['Premium Economy', 'Business', 'First'].contains(_selectedSeatClass);

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.note_alt_outlined),
              tooltip: 'Memo & Photos',
              onPressed: _showMemoDialog,
            )
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFastSearchCheckbox(),

                  _buildSectionHeader('Flight Date & Time'),

                  _buildFieldRowWithUnknown(isUnknown: _isDateUnknown, onUnknownChanged: (val) => setState(() => _isDateUnknown = val), child: _buildTextFormField(controller: _dateController, labelText: 'Date', hintText: DateFormat('yyyy-MM-dd').format(DateTime.now()), icon: Icons.calendar_today, readOnly: true, onTap: () => _selectDate(_dateController), enabled: !_isDateUnknown)),
                  const SizedBox(height: 15),

                  _buildFlightNumberField(),
                  const SizedBox(height: 15),

                  if (!_isFastSearch) ...[
                    _buildFieldRowWithUnknown(isUnknown: _isDepartureTimeUnknown, onUnknownChanged: (val) { setState(() => _isDepartureTimeUnknown = val); if (val) { _departureHoursController.clear(); _departureMinutesController.clear(); } }, child: _buildTimeInput('Departure', _departureHoursController, _departureMinutesController, enabled: !_isDepartureTimeUnknown)),
                    const SizedBox(height: 15),
                    _buildFieldRowWithUnknown(isUnknown: _isArrivalTimeUnknown, onUnknownChanged: (val) { setState(() => _isArrivalTimeUnknown = val); if (val) { _arrivalHoursController.clear(); _arrivalMinutesController.clear(); } }, child: _buildTimeInput('Arrival', _arrivalHoursController, _arrivalMinutesController, enabled: !_isArrivalTimeUnknown)),
                    const SizedBox(height: 15),

                    _buildSectionHeader('Route & Flight'),
                    Row(children: [ Expanded(child: _buildTextFormField(controller: _departureAirportController, labelText: 'Departure', hintText: 'ATL', icon: Icons.flight_takeoff, isAirportCode: true)), const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.arrow_forward)), Expanded(child: _buildTextFormField(controller: _destinationAirportController, labelText: 'Arrival', hintText: 'PEK', icon: Icons.flight_land, isAirportCode: true)), ]),
                    const SizedBox(height: 15),

                    // 🚀 [수정] Airline 필드를 검색 다이얼로그 방식으로 변경
                    _buildFieldRowWithUnknown(
                      isUnknown: _isAirlineUnknown,
                      onUnknownChanged: (val) => setState(() => _isAirlineUnknown = val),
                      child: _buildAirlineSelectionField(),
                    ),
                    const SizedBox(height: 15),

                    _buildFieldRowWithUnknown(
                      isUnknown: _isAircraftUnknown,
                      onUnknownChanged: (val) => setState(() {
                        _isAircraftUnknown = val;
                        if (val) {
                          _isDirectAircraftInput = false;
                          _selectedAircraft = null;
                          _aircraftController.clear();
                        }
                      }),
                      child: _buildAircraftField(),
                    ),
                    const SizedBox(height: 15),

                    _buildSectionHeader('Flight Status'),
                    _buildFieldRowWithUnknown(isUnknown: _isDurationUnknown, onUnknownChanged: (val) => setState(() => _isDurationUnknown = val), child: _buildLabeledDurationInput('Duration', _durationHoursController, _durationMinutesController, enabled: !_isDurationUnknown && !_isCanceled)),
                    const SizedBox(height: 15),

                    _buildStatusCheckbox('Delayed Flight', _hasDelay, _isCanceled ? null : (val) => setState(() => _hasDelay = val ?? false)),

                    if (_hasDelay && !_isCanceled) ...[
                      const SizedBox(height: 15),
                      _buildLabeledDurationInput('Delay', _delayHoursController, _delayMinutesController, enabled: true),
                      const SizedBox(height: 15),
                    ],

                    const SizedBox(height: 15),

                    _buildStatusCheckbox('Flight Canceled', _isCanceled, (val) => setState(() => _isCanceled = val ?? false)),

                    const SizedBox(height: 15),
                    _buildTerminalGateSection(),
                    const SizedBox(height: 15),
                  ],

                  _buildSectionHeader('Ticket', key: _sectionKeys['Ticket']),
                  _buildFieldRowWithUnknown(isUnknown: _isTicketPriceUnknown, onUnknownChanged: (val) { setState(() { _isTicketPriceUnknown = val ?? true; if (_isTicketPriceUnknown) { _isVatUnknown = true; _vatController.clear(); _isThroughTicket = false; } }); }, child: _buildTicketPriceField()),

                  CheckboxListTile(
                      title: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Through-ticket'),
                          Text(
                            '(link flights with same price)',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      value: _isThroughTicket,
                      onChanged: _isTicketPriceUnknown ? null : (val) {
                        setState(() {
                          _isThroughTicket = val ?? false;
                          if (!_isThroughTicket) {
                            _linkedLogs.clear();
                            _currentItinerary = null;
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero
                  ),
                  if (_isThroughTicket) _buildLinkedFlightsSection(),
                  if (_isMileageTicket && !_isTicketPriceUnknown) ...[
                    const SizedBox(height: 15),
                    _buildMileageAirlineField(_mileageAirlineController),
                    const SizedBox(height: 15),
                    _buildVatFieldRow(_vatController, _isVatUnknown, (val) => setState(() => _isVatUnknown = val))
                  ],
                  const SizedBox(height: 15),
                  _buildFieldRowWithUnknown(isUnknown: _isBookingDateUnknown, onUnknownChanged: (val) => setState(() => _isBookingDateUnknown = val), child: _buildTextFormField(controller: _bookingDateController, labelText: 'Booking Date', icon: Icons.edit_calendar, readOnly: true, onTap: () => _selectDate(_bookingDateController), enabled: !_isBookingDateUnknown)),
                  const SizedBox(height: 15),
                  _buildFieldRowWithUnknown(isUnknown: _isSeatClassUnknown, onUnknownChanged: (val) => setState(() => _isSeatClassUnknown = val), child: _buildSeatClassDropdown()),
                  if (showUpgradeSection) _buildUpgradeSection(),
                  const SizedBox(height: 20),
                  _buildTicketPhotoPicker(),
                  _buildSectionHeader('My Rating'),
                  _buildMyRatingSection(),
                ],
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
      bottomSheet: _buildBottomButtons(),
    );
  }

  // 🚀 [추가] Airline 선택을 위한 텍스트 필드 빌더
  Widget _buildAirlineSelectionField() {
    return TextFormField(
      controller: _airlineController,
      readOnly: true,
      onTap: _isAirlineUnknown ? null : () => _showAirlineSearchDialog(_airlineController),
      decoration: _buildInputDecoration(
        labelText: 'Airline',
        icon: Icons.business,
        enabled: !_isAirlineUnknown,
      ),
      validator: (value) => (!_isAirlineUnknown && (value == null || value.isEmpty)) ? 'Required' : null,
    );
  }

  Widget _buildUpgradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        CheckboxListTile(
          title: const Text('Seat Upgrade'),
          value: _wasUpgraded,
          onChanged: (val) => setState(() {
            _wasUpgraded = val ?? false;
            if (!_wasUpgraded) {
              _isUpgradePriceUnknown = true;
              _isUpgradeDateUnknown = true;
              _isUpgradeInMiles = false;
              _isUpgradeVatUnknown = true;
              _upgradePriceController.clear();
              _upgradeVatController.clear();
              _upgradeDateController.clear();
              _upgradeMileageAirlineController.clear();
            }
          }),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (_wasUpgraded)
          Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFieldRowWithUnknown(isUnknown: _isUpgradePriceUnknown, onUnknownChanged: (val) => setState(() => _isUpgradePriceUnknown = val), child: _buildUpgradePriceField()),
                  if (_isUpgradeInMiles && !_isUpgradePriceUnknown) ...[
                    const SizedBox(height: 15),
                    _buildMileageAirlineField(_upgradeMileageAirlineController, isUpgrade: true),
                    const SizedBox(height: 15),
                    _buildVatFieldRow(_upgradeVatController, _isUpgradeVatUnknown, (val) => setState(() => _isUpgradeVatUnknown = val)),
                  ],
                  const SizedBox(height: 15),
                  _buildFieldRowWithUnknown(isUnknown: _isUpgradeDateUnknown, onUnknownChanged: (val) => setState(() => _isUpgradeDateUnknown = val), child: _buildTextFormField(controller: _upgradeDateController, labelText: 'Upgrade Date', icon: Icons.edit_calendar, readOnly: true, onTap: () => _selectDate(_upgradeDateController), enabled: !_isUpgradeDateUnknown)),
                ],
              ),
            ),
          )
      ],
    );
  }


  Widget _buildAircraftField() {
    if (_isDirectAircraftInput) {
      return Row(
        children: [
          Expanded(
            child: _buildTextFormField(
              controller: _aircraftController,
              labelText: 'Aircraft (Direct Input)',
              icon: Icons.airplanemode_active,
              enabled: !_isAircraftUnknown,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_drop_down_circle_outlined),
            color: Colors.deepPurple,
            tooltip: 'Select from list',
            onPressed: () {
              setState(() {
                _isDirectAircraftInput = false;
              });
            },
          )
        ],
      );
    } else {
      return DropdownButtonFormField<String>(
        value: _selectedAircraft,
        items: _aircraftModels.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: _isAircraftUnknown ? null : (value) {
          setState(() {
            _selectedAircraft = value;
            if (value == 'Direct Input') {
              _isDirectAircraftInput = true;
            } else {
              _isDirectAircraftInput = false;
              _aircraftController.text = value ?? '';
            }
          });
        },
        decoration: _buildInputDecoration(
          labelText: 'Aircraft',
          icon: Icons.airplanemode_active,
          enabled: !_isAircraftUnknown,
        ),
        isExpanded: true,
      );
    }
  }

  Widget _buildFieldRowWithUnknown({required Widget child, required bool isUnknown, required ValueChanged<bool> onUnknownChanged}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: child),
      Transform.scale(scale: 0.8, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Unknown', style: TextStyle(fontSize: 12)), Checkbox(value: isUnknown, onChanged: (val) => onUnknownChanged(val ?? false), visualDensity: VisualDensity.compact)])),
    ]);
  }

  Widget _buildFlightNumberField() {
    final bool showSearchButton = _isFastSearch || widget.isEditing;

    return _buildFieldRowWithUnknown(
      isUnknown: _isFlightNumberUnknown,
      onUnknownChanged: (val) => setState(() => _isFlightNumberUnknown = val),
      child: Row(children: [
        Expanded(child: _buildTextFormField(controller: _flightNumberController, labelText: 'Flight Number', icon: Icons.confirmation_number, enabled: !_isFlightNumberUnknown)),
        if (showSearchButton) ...[
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _findFlight, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), shape: const CircleBorder(), backgroundColor: Colors.deepPurple), child: const Icon(Icons.search, color: Colors.white)),
        ],
      ]),
    );
  }

  Widget _buildSectionHeader(String title, {Key? key}) {
    return Padding(
        key: key,
        padding: const EdgeInsets.only(top: 28.0, bottom: 12.0),
        child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.deepPurple.shade900,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            )
        )
    );
  }

  Widget _buildTextFormField({required TextEditingController controller, String? labelText, String? hintText, IconData? icon, bool enabled = true, bool readOnly = false, VoidCallback? onTap, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, bool isAirportCode = false}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: isAirportCode
          ? [
        LengthLimitingTextInputFormatter(3),
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
        UpperCaseTextFormatter(),
      ]
          : inputFormatters,
      decoration: _buildInputDecoration(labelText: labelText, hintText: hintText, icon: icon, enabled: enabled),
      validator: (value) => (enabled && (value == null || value.isEmpty)) ? 'Required' : null,
    );
  }

  Widget _buildTimeInput(String label, TextEditingController h, TextEditingController m, {bool enabled = true}) {
    return Row(children: [
      Icon(label == 'Departure' ? Icons.flight_takeoff : Icons.flight_land, color: enabled ? Colors.deepPurple : Colors.grey),
      const SizedBox(width: 10),
      Expanded(child: _buildTextFormField(controller: h, labelText: 'Hour', hintText: '15', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)], enabled: enabled)),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':')),
      Expanded(child: _buildTextFormField(controller: m, labelText: 'Minute', hintText: label == 'Departure' ? '30' : '40', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)], enabled: enabled)),
    ]);
  }

  Widget _buildLabeledDurationInput(String label, TextEditingController h, TextEditingController m, {bool enabled = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: enabled ? Colors.white : Colors.grey.shade200, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(15.0)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: enabled ? Colors.deepPurple : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildTextFormField(controller: h, labelText: 'Hours', hintText: '1', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], enabled: enabled)),
          const SizedBox(width: 10),
          Expanded(child: _buildTextFormField(controller: m, labelText: 'Minutes', hintText: '30', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], enabled: enabled)),
        ]),
      ]),
    );
  }

  Widget _buildTerminalGateSection() {
    return Column(children: [
      const SizedBox(height: 10),
      _buildTerminalGateSectionRow(title: 'Departure', terminalController: _departureTerminalController, isTerminalUnknown: _isDepartureTerminalUnknown, onTerminalUnknownChanged: (val) => setState(() => _isDepartureTerminalUnknown = val), terminalHint: '2', gateController: _departureGateController, isGateUnknown: _isDepartureGateUnknown, onGateUnknownChanged: (val) => setState(() => _isDepartureGateUnknown = val), gateHint: 'L22'),
      const SizedBox(height: 10),
      _buildTerminalGateSectionRow(title: 'Arrival', terminalController: _arrivalTerminalController, isTerminalUnknown: _isArrivalTerminalUnknown, onTerminalUnknownChanged: (val) => setState(() => _isArrivalTerminalUnknown = val), terminalHint: '2E', gateController: _arrivalGateController, isGateUnknown: _isArrivalGateUnknown, onGateUnknownChanged: (val) => setState(() => _isArrivalGateUnknown = val), gateHint: '249'),
    ]);
  }

  Widget _buildTerminalGateSectionRow({ required String title, required TextEditingController terminalController, required bool isTerminalUnknown, required ValueChanged<bool> onTerminalUnknownChanged, required String terminalHint, required TextEditingController gateController, required bool isGateUnknown, required ValueChanged<bool> onGateUnknownChanged, required String gateHint,}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4.0, bottom: 8.0), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54))),
      Row(children: [
        Expanded(child: _buildFieldRowWithUnknown(isUnknown: isTerminalUnknown, onUnknownChanged: onTerminalUnknownChanged, child: _buildTextFormField(controller: terminalController, labelText: 'Ter.', hintText: terminalHint, enabled: !isTerminalUnknown))),
        const SizedBox(width: 10),
        Expanded(child: _buildFieldRowWithUnknown(isUnknown: isGateUnknown, onUnknownChanged: onGateUnknownChanged, child: _buildTextFormField(controller: gateController, labelText: 'Gate', hintText: gateHint, enabled: !isGateUnknown))),
      ]),
    ]);
  }

  Widget _buildSeatClassDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSeatClass,
      items: ['Economy', 'Premium Economy', 'Business', 'First'].map((label) =>
          DropdownMenuItem(
              value: label,
              child: Text(
                label,
                style: TextStyle(
                  color: _seatClassColors[label],
                  fontWeight: FontWeight.bold,
                ),
              )
          )
      ).toList(),
      onChanged: _isSeatClassUnknown ? null : (value) => setState(() => _selectedSeatClass = value ?? 'Economy'),
      decoration: _buildInputDecoration(labelText: 'Seat Class', icon: Icons.airline_seat_recline_normal, enabled: !_isSeatClassUnknown),
    );
  }

  Widget _buildTicketPriceField() {
    return Row(children: [
      Expanded(child: _buildTextFormField(controller: _ticketPriceController, labelText: 'Price', icon: _isMileageTicket ? Icons.star : Icons.monetization_on, keyboardType: TextInputType.number, enabled: !_isTicketPriceUnknown)),
      Text('USD', style: TextStyle(color: _isMileageTicket || _isTicketPriceUnknown ? Colors.grey : null)),
      Switch(
        value: _isMileageTicket,
        onChanged: _isTicketPriceUnknown ? null : (val) {
          setState(() {
            _isMileageTicket = val;
            if (_isMileageTicket) {
              _mileageAirlineController.text = _airlineController.text;
            }
            if (!_isMileageTicket) {
              _isVatUnknown = true;
              _vatController.clear();
            }
          });
        },
      ),
      Text('Miles', style: TextStyle(color: !_isMileageTicket || _isTicketPriceUnknown ? Colors.grey : null)),
    ]);
  }

  Widget _buildUpgradePriceField() {
    return Row(children: [
      Expanded(child: _buildTextFormField(controller: _upgradePriceController, labelText: 'Upgrade Price', icon: _isUpgradeInMiles ? Icons.star : Icons.monetization_on, keyboardType: TextInputType.number, enabled: !_isUpgradePriceUnknown)),
      Text('USD', style: TextStyle(color: _isUpgradeInMiles || _isUpgradePriceUnknown ? Colors.grey : null)),
      Switch(
        value: _isUpgradeInMiles,
        onChanged: _isUpgradePriceUnknown ? null : (val) {
          setState(() {
            _isUpgradeInMiles = val;
            if (_isUpgradeInMiles) {
              _upgradeMileageAirlineController.text = _airlineController.text;
            }
            if (!_isUpgradeInMiles) {
              _isUpgradeVatUnknown = true;
              _upgradeVatController.clear();
            }
          });
        },
      ),
      Text('Miles', style: TextStyle(color: !_isUpgradeInMiles || _isUpgradePriceUnknown ? Colors.grey : null)),
    ]);
  }


  Widget _buildMileageAirlineField(TextEditingController controller, {bool isUpgrade = false}) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _showAirlineSearchDialog(controller),
      decoration: _buildInputDecoration(
        labelText: 'Mileage Program',
        icon: Icons.card_membership,
        enabled: isUpgrade ? !_isUpgradePriceUnknown : !_isTicketPriceUnknown,
      ),
      validator: (value) {
        if ((value == null || value.isEmpty)) {
          final priceUnknown = isUpgrade ? _isUpgradePriceUnknown : _isTicketPriceUnknown;
          final isMiles = isUpgrade ? _isUpgradeInMiles : _isMileageTicket;
          if(isMiles && !priceUnknown) return 'Please select an airline program';
        }
        return null;
      },
    );
  }

  // 🚀 [통일] Airline 및 Mileage Program 검색용 통합 다이얼로그
  Future<void> _showAirlineSearchDialog(TextEditingController controller) async {
    final provider = Provider.of<AirlineProvider>(context, listen: false);
    final allAirlines = provider.airlines.map((a) => a.name).toList();

    final selectedAirline = await showDialog<String>(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredAirlines = allAirlines
                .where((airline) => airline.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return AlertDialog(
              title: const Text('Search Airline'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredAirlines.length,
                        itemBuilder: (context, index) {
                          final airlineName = filteredAirlines[index];
                          return ListTile(
                            title: Text(airlineName),
                            onTap: () {
                              Navigator.of(context).pop(airlineName);
                            },
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
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedAirline != null) {
      setState(() {
        controller.text = selectedAirline;
        // Airline을 선택했을 때 만약 Mileage Ticket 상태라면 Mileage Airline도 자동으로 채워줌
        if (controller == _airlineController && _isMileageTicket) {
          _mileageAirlineController.text = selectedAirline;
        }
      });
    }
  }

  Widget _buildVatFieldRow(TextEditingController controller, bool isUnknown, ValueChanged<bool> onUnknownChanged) {
    return _buildFieldRowWithUnknown(
      isUnknown: isUnknown,
      onUnknownChanged: onUnknownChanged,
      child: Row(children: [
        Expanded(child: _buildTextFormField(controller: controller, labelText: 'VAT', icon: Icons.receipt_long_outlined, keyboardType: TextInputType.number, enabled: !isUnknown)),
        const SizedBox(width: 8),
        Padding(padding: const EdgeInsets.only(right: 8.0), child: Text('USD', style: TextStyle(color: isUnknown ? Colors.grey : Colors.black87, fontSize: 16))),
      ]),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), spreadRadius: 0, blurRadius: 6)]),
      child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'), style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.deepPurple.shade300),
        ))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: _saveFlightLog, child: Text(widget.isEditing ? 'Save Changes' : 'Save Log'), style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.deepPurple.shade600,
          foregroundColor: Colors.white,
          elevation: 3,
        ))),
      ]),
    );
  }

  InputDecoration _buildInputDecoration({String? labelText, String? hintText, IconData? icon, bool enabled = true}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      labelStyle: TextStyle(
        color: enabled ? Colors.deepPurple.shade700 : Colors.grey,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: icon != null ? Icon(icon, color: enabled ? Colors.deepPurple : Colors.grey) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.0),
        borderSide: BorderSide(color: Colors.deepPurple.shade700, width: 2.0),
      ),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade50,
    );
  }

  Future<void> _pickImage(Function(String) onImagePicked) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Photo Library'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
      ]),
    );
    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      onImagePicked(pickedFile.path);
    }
  }

  Widget _buildTicketPhotoPicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ticket Photo', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => _pickImage((path) => setState(() => _ticketPhotoPath = path)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15.0), border: Border.all(color: Colors.grey.shade400, width: 1.5, style: BorderStyle.solid)),
            child: _ticketPhotoPath != null && _ticketPhotoPath!.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(14.0), child: Image.network(_ticketPhotoPath!, fit: BoxFit.cover))
                : const Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 40)),
          ),
        ),
      ),
    ]);
  }

  void _showMemoDialog() {
    final tempMemoController = TextEditingController(text: _memoController.text);
    final tempPhotos = List<String>.from(_flightLogPhotos);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget photoPreview(String path, int index) {
              return Stack(
                children: [
                  Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(path, fit: BoxFit.cover))),
                  Positioned(top: -8, right: -8, child: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20), onPressed: () => setStateDialog(() => tempPhotos.removeAt(index)))),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Memo & Photos'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Memo:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(controller: tempMemoController, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Write notes...')),
                    const SizedBox(height: 20),
                    const Text('Photos:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        GestureDetector(
                          onTap: () => _pickImage((path) => setStateDialog(() => tempPhotos.add(path))),
                          child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.add_a_photo, color: Colors.grey))),
                        ),
                        ...tempPhotos.asMap().entries.map((e) => photoPreview(e.value, e.key)),
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    setState(() {
                      _memoController.text = tempMemoController.text;
                      _flightLogPhotos = tempPhotos;
                    });
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLinkedFlightsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              if (_linkedLogs.isNotEmpty)
                ..._linkedLogs.map((log) => ListTile(
                  leading: const Icon(Icons.flight),
                  title: Text('${log.airlineName} ${log.flightNumber}'),
                  subtitle: Text('${log.departureIata} → ${log.arrivalIata}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _linkedLogs.remove(log);
                      });
                    },
                  ),
                )),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _showLinkFlightDialog,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Add Flight to Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkFlightDialog() {
    final provider = Provider.of<AirlineProvider>(context, listen: false);
    final currentLogId = widget.initialLog?.id;
    final linkedLogIds = _linkedLogs.map((log) => log.id).toSet();
    final availableLogs = provider.allFlightLogs.where((log) {
      return log.id != currentLogId && !linkedLogIds.contains(log.id) && log.itineraryId == null;
    }).toList();

    final Set<FlightLog> selectedLogs = {};

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Flights to Link'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: availableLogs.length,
                  itemBuilder: (context, index) {
                    final log = availableLogs[index];
                    return CheckboxListTile(
                      title: Text('${log.airlineName} ${log.flightNumber}'),
                      subtitle: Text('${log.date} / ${log.departureIata}→${log.arrivalIata}'),
                      value: selectedLogs.contains(log),
                      onChanged: (isSelected) {
                        setStateDialog(() {
                          if (isSelected ?? false) {
                            selectedLogs.add(log);
                          } else {
                            selectedLogs.remove(log);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _linkedLogs.addAll(selectedLogs);
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Link Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}