import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/services/travel_quantifier.dart';

// Implementations avoid provider constructors (Firebase/storage/network).
class _Countries implements CountryProvider {
  @override
  final Map<String, VisitDetails> visitDetails = {};
  @override
  final Map<String, String> countryNameToIsoMap = {};
  @override
  String? get homeCountryIsoA3 => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cities implements CityProvider {
  @override
  final Map<String, CityVisitDetail> visitDetails = {};
  @override
  String? homeCityName;
  @override
  bool isVisited(String cityName) => visitDetails[cityName]?.visitDateRanges.isNotEmpty ?? false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Flights implements AirlineProvider {
  @override
  final List<FlightLog> allFlightLogs = [];
  @override
  int parseDuration(String? value) => value == '2h' ? 120 : 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Airports implements AirportProvider {
  @override
  final Set<String> visitedAirports = {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Countries countries;
  late _Cities cities;
  late _Flights flights;
  late _Airports airports;
  late TravelQuantifier quantifier;
  setUp(() {
    countries = _Countries();
    cities = _Cities();
    flights = _Flights();
    airports = _Airports();
    quantifier = TravelQuantifier(countryProvider: countries, cityProvider: cities,
        airlineProvider: flights, airportProvider: airports);
  });

  test('no records produces no observed travel axes', () {
    expect(quantifier.observedAxes, isEmpty);
  });

  test('wishlist, home and lived city records are not visit evidence', () {
    cities.visitDetails['wish'] = CityVisitDetail(name: 'wish', isWishlisted: true);
    cities.homeCityName = 'home';
    cities.visitDetails['home'] = CityVisitDetail(name: 'home', visitDateRanges: [DateRange()]);
    cities.visitDetails['lived'] = CityVisitDetail(name: 'lived', hasLived: true, visitDateRanges: [DateRange()]);
    expect(quantifier.observedAxes, isEmpty);
  });

  test('a visited city does not invent country/flight evidence', () {
    cities.visitDetails['visited'] = CityVisitDetail(name: 'visited', visitDateRanges: [DateRange()]);
    expect(quantifier.observedAxes, {'cityDistribution'});
  });

  test('repeated visits actually change city distribution', () {
    cities.visitDetails['a'] = CityVisitDetail(name: 'a', visitDateRanges: [DateRange()]);
    cities.visitDetails['b'] = CityVisitDetail(name: 'b', visitDateRanges: [DateRange()]);
    expect(quantifier.quantify().cityDistribution, closeTo(1, 1e-9));
    cities.visitDetails['a']!.visitDateRanges.addAll(List.generate(8, (_) => DateRange()));
    expect(quantifier.quantify().cityDistribution, lessThan(0));
  });

  test('canceled flight and missing duration do not create time evidence', () {
    flights.allFlightLogs.add(FlightLog(flightNumber: 'test', duration: '2h', isCanceled: true));
    expect(quantifier.observedAxes, isEmpty);
    flights.allFlightLogs.add(FlightLog(flightNumber: 'unknown'));
    expect(quantifier.observedAxes, {'airlineDistribution', 'transferFlightScore'});
    flights.allFlightLogs.add(FlightLog(flightNumber: 'timed', duration: '2h'));
    expect(quantifier.observedAxes, contains('airlineTime'));
  });
}
