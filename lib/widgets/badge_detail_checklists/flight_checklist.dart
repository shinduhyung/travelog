import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/airport_visit_entry.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
// [수정] airlineAllianceCodes 가져오기
import 'package:jidoapp/providers/badge_provider.dart' show airlineAllianceCodes;
import 'package:jidoapp/screens/airlines_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/screens/airline_detail_screen.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class FlightChecklist {
  final Achievement achievement;

  FlightChecklist({
    required this.achievement,
  });

  // ICAO Code -> Name Mapping (UI Display용)
  static const Map<String, String> _icaoToName = {
    // SkyTeam
    "AMX": "Aeroméxico", "AEA": "Air Europa", "AFR": "Air France", "CAL": "China Airlines",
    "CES": "China Eastern", "DAL": "Delta Air Lines", "GIA": "Garuda Indonesia", "KLM": "KLM",
    "KAL": "Korean Air", "MEA": "Middle East Airlines", "SVA": "Saudia", "SAS": "Scandinavian Airlines",
    "ROT": "Tarom", "HVN": "Vietnam Airlines", "VIR": "Virgin Atlantic", "CXA": "Xiamen Airlines",
    "KQA": "Kenya Airways", "ARG": "Aerolineas Argentinas",
    // Star Alliance
    "AEE": "Aegean Airlines", "ACA": "Air Canada", "CCA": "Air China", "AIC": "Air India",
    "ANZ": "Air New Zealand", "ANA": "All Nippon Airways", "AAR": "Asiana Airlines", "AUA": "Austrian Airlines",
    "AVA": "Avianca", "BEL": "Brussels Airlines", "CMP": "Copa Airlines", "CTN": "Croatia Airlines",
    "MSR": "EgyptAir", "ETH": "Ethiopian Airlines", "EVA": "EVA Air", "LOT": "LOT Polish Airlines",
    "DLH": "Lufthansa", "CSZ": "Shenzhen Airlines", "SIA": "Singapore Airlines", "SAA": "South African Airways",
    "SWR": "SWISS International Air Lines", "TAP": "TAP Air Portugal", "THA": "Thai Airways International",
    "THY": "Turkish Airlines", "UAL": "United Airlines",
    // OneWorld
    "ASA": "Alaska Airlines", "AAL": "American Airlines", "BAW": "British Airways", "CPA": "Cathay Pacific",
    "FJI": "Fiji Airways", "FIN": "Finnair", "IBE": "Iberia", "JAL": "Japan Airlines",
    "MAS": "Malaysia Airlines", "OMA": "Oman Air", "QFA": "Qantas", "QTR": "Qatar Airways",
    "RAM": "Royal Air Maroc", "RJA": "Royal Jordanian"
  };

  // --- Helper Methods for Airport Modal ---
  final Color _wineColor = Colors.red.shade800;

  Widget _buildDropdown<T>(
      String hint, T? value, List<T?> items, ValueChanged<T?> onChanged) {
    return DropdownButtonFormField<T>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
          labelText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
      items: items
          .map((item) => DropdownMenuItem<T>(
        value: item as T?,
        child: Text(
          item?.toString() ?? 'Unknown',
          style: TextStyle(
            fontSize: (item == null) ? 11.0 : 15.0,
            color: (item == null) ? Colors.grey.shade600 : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }

  void _showMemoAndPhotoDialog(BuildContext context, String iataCode, {int? useIndex, bool isForLounge = false}) {
    final provider = Provider.of<AirportProvider>(context, listen: false);

    final isPerUseMemo = useIndex != null;
    String initialMemo = '';
    List<String> initialPhotos = [];
    AirportVisitEntry? visitEntry;

    if (isForLounge && isPerUseMemo) {
      visitEntry = provider.getVisitEntries(iataCode)[useIndex - 1];
      initialMemo = visitEntry.loungeMemo ?? '';
      initialPhotos = visitEntry.loungePhotos;
    } else if (isPerUseMemo) {
      initialMemo = '';
      initialPhotos = [];
    } else {
      initialMemo = provider.getMemo(iataCode);
      initialPhotos = provider.getPhotos(iataCode);
    }

    final TextEditingController memoController = TextEditingController(text: initialMemo);
    List<String> currentPhotos = List.from(initialPhotos);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void _pickImage(ImageSource source) async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: source);

              if (pickedFile != null) {
                setStateDialog(() {
                  currentPhotos.add(pickedFile.path);
                });
              }
            }

            Widget _buildPhotoPreview(String photoPath, int index) {
              final file = File(photoPath);
              bool fileExists = file.existsSync();

              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400)
                    ),
                    child: fileExists
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Center(
                      child: Icon(Icons.broken_image, color: Colors.red),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                      onPressed: () {
                        setStateDialog(() {
                          currentPhotos.removeAt(index);
                        });
                      },
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: Text(isForLounge && isPerUseMemo
                  ? 'Lounge Memo & Photos for Visit #${useIndex}'
                  : (isPerUseMemo ? 'Memo & Photos for Use #$useIndex' : 'Memo & Photos for $iataCode')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Memo:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: memoController,
                      maxLines: 5,
                      minLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Write your thoughts here...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Photos:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (BuildContext modalContext) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      ListTile(
                                        leading: const Icon(Icons.photo_library),
                                        title: const Text('Photo Library'),
                                        onTap: () {
                                          Navigator.pop(modalContext);
                                          _pickImage(ImageSource.gallery);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_camera),
                                        title: const Text('Camera'),
                                        onTap: () {
                                          Navigator.pop(modalContext);
                                          _pickImage(ImageSource.camera);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.blue),
                                  Text('Add Photo', style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ...currentPhotos.asMap().entries.map((entry) {
                          return _buildPhotoPreview(entry.value, entry.key);
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    if (isForLounge && isPerUseMemo) {
                      provider.updateVisitEntry(
                        iataCode,
                        useIndex - 1,
                        loungeMemo: memoController.text,
                        loungePhotos: currentPhotos,
                      );
                    } else if (!isPerUseMemo) {
                      provider.updateMemoAndPhotos(
                          iataCode,
                          memoController.text,
                          currentPhotos
                      );
                    }
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

  Widget _buildDateSection(BuildContext context, AirportVisitEntry use, int index, AirportProvider provider) {
    int? year = use.year;
    int? month = use.month;
    int? day = use.day;

    final years = [
      null,
      ...List.generate(80, (i) => DateTime.now().year - i)
    ];
    final months = [null, ...List.generate(12, (i) => i + 1)];
    final days = [null, ...List.generate(31, (i) => i + 1)];

    final iataCode = provider.allAirports.firstWhere((a) => provider.getVisitEntries(a.iataCode).contains(use)).iataCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Visit Date', style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                provider.updateVisitEntry(
                    iataCode,
                    index,
                    year: null,
                    month: null,
                    day: null
                );
              },
              tooltip: 'Clear Date',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildDropdown<int>(
                    'Year',
                    year,
                    years.cast<int?>(),
                        (val) {
                      provider.updateVisitEntry(
                        iataCode,
                        index,
                        year: val,
                      );
                    }
                )
            ),
            const SizedBox(width: 8),
            Expanded(
                child: _buildDropdown<int>(
                    'Month',
                    month,
                    months.cast<int?>(),
                        (val) {
                      provider.updateVisitEntry(
                        iataCode,
                        index,
                        month: val,
                      );
                    }
                )
            ),
            const SizedBox(width: 8),
            Expanded(
                child: _buildDropdown<int>(
                    'Day',
                    day,
                    days.cast<int?>(),
                        (val) {
                      provider.updateVisitEntry(
                        iataCode,
                        index,
                        day: val,
                      );
                    }
                )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUseDetails(BuildContext context, Airport airport, AirportProvider provider) {
    final uses = provider.getVisitEntries(airport.iataCode);
    final currentRating = provider.getRating(airport.iataCode);
    final isHub = provider.isHub(airport.iataCode);
    final isFavorite = provider.isFavorite(airport.iataCode);
    final loungeVisitCount = provider.getLoungeVisitCount(airport.iataCode);
    final averageLoungeRating = provider.getAverageLoungeRating(airport.iataCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Text('My Hub'),
                  Checkbox(
                    value: isHub,
                    onChanged: (bool? value) {
                      provider.updateHubStatus(airport.iataCode, value ?? false);
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Favorite'),
                  Checkbox(
                    value: isFavorite,
                    onChanged: (bool? value) {
                      provider.updateFavoriteStatus(airport.iataCode, value ?? false);
                    },
                  ),
                ],
              ),
              const Divider(height: 10),
              Row(
                children: [
                  Icon(Icons.wine_bar, color: _wineColor),
                  const SizedBox(width: 8),
                  Text('Business Lounge: $loungeVisitCount Visits'),
                ],
              ),
              if (loungeVisitCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 8.0),
                  child: Row(
                    children: [
                      Text('Average Rating: ', style: Theme.of(context).textTheme.bodySmall),
                      Icon(Icons.wine_bar, color: _wineColor, size: 20),
                      Text(
                        ' (${averageLoungeRating.toStringAsFixed(1)})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Rating', style: Theme.of(context).textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.note_alt_outlined, color: Colors.grey),
                onPressed: () => _showMemoAndPhotoDialog(context, airport.iataCode),
                tooltip: 'Add Memo and Photos',
              ),
            ],
          ),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: currentRating,
            minRating: 0,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 28.0,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => const Icon(
              Icons.airplanemode_active,
              color: Colors.blue,
            ),
            onRatingUpdate: (rating) {
              provider.updateRating(airport.iataCode, rating);
            },
          ),
          const Divider(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History (${uses.length} uses)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Use'),
                onPressed: () {
                  provider.addVisitEntry(airport.iataCode);
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (uses.isNotEmpty)
            ...uses.asMap().entries.map((entry) {
              final index = entry.key;
              final use = entry.value;

              final isYearUnknown = use.year == null;
              final isMonthUnknown = use.month == null;
              final isDayUnknown = use.day == null;

              final dateText = (isYearUnknown ? '????' : use.year.toString()) +
                  '/' +
                  (isMonthUnknown ? '??' : use.month!.toString().padLeft(2, '0')) +
                  '/' +
                  (isDayUnknown ? '??' : use.day!.toString().padLeft(2, '0'));

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateSection(context, use, index, provider),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${index + 1}: ',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                dateText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.note_alt_outlined, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showMemoAndPhotoDialog(context, airport.iataCode, useIndex: index + 1),
                                tooltip: 'Add Memo for this Use',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                tooltip: 'Remove this use',
                                onPressed: () {
                                  provider.removeVisitEntry(airport.iataCode, index);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title: const Text('Transfer', style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isTransfer,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isTransfer: value);
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title: const Text('Layover', style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isLayover,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isLayover: value);
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title: const Text('Stopover', style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isStopover,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isStopover: value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(),
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.9,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title: const Text('Lounge Use', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      secondary: Icon(Icons.wine_bar, color: _wineColor, size: 16),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isLoungeUsed,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isLoungeUsed: value);
                                      },
                                    ),
                                  ),
                                ),
                                if (use.isLoungeUsed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: RatingBar.builder(
                                                initialRating: use.loungeRating ?? 0.0,
                                                minRating: 0,
                                                direction: Axis.horizontal,
                                                allowHalfRating: true,
                                                itemCount: 5,
                                                itemSize: 20.0,
                                                itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
                                                itemBuilder: (context, _) => Icon(Icons.wine_bar, color: _wineColor),
                                                onRatingUpdate: (rating) {
                                                  provider.updateVisitEntry(airport.iataCode, index, loungeRating: rating);
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.note_alt_outlined, color: Colors.grey, size: 20),
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _showMemoAndPhotoDialog(
                                                context,
                                                airport.iataCode,
                                                useIndex: index + 1,
                                                isForLounge: true,
                                              ),
                                              tooltip: 'Add Lounge Memo & Photos for this visit',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Builder(
                                            builder: (context) {
                                              final totalMinutes = use.loungeDurationInMinutes ?? 0;
                                              final hours = totalMinutes ~/ 60;
                                              final minutes = totalMinutes % 60;

                                              final hourController = TextEditingController(text: hours == 0 ? '' : hours.toString());
                                              final minuteController = TextEditingController(text: minutes == 0 ? '' : minutes.toString());

                                              hourController.selection = TextSelection.fromPosition(TextPosition(offset: hourController.text.length));
                                              minuteController.selection = TextSelection.fromPosition(TextPosition(offset: minuteController.text.length));

                                              void updateDuration() {
                                                final h = int.tryParse(hourController.text) ?? 0;
                                                final m = int.tryParse(minuteController.text) ?? 0;
                                                final newTotalMinutes = (h * 60) + m;

                                                if (use.loungeDurationInMinutes != newTotalMinutes) {
                                                  provider.updateVisitEntry(
                                                    airport.iataCode,
                                                    index,
                                                    loungeDurationInMinutes: newTotalMinutes > 0 ? newTotalMinutes : null,
                                                  );
                                                }
                                              }

                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller: hourController,
                                                      textAlign: TextAlign.center,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      decoration: const InputDecoration(labelText: 'H', isDense: true, border: OutlineInputBorder()),
                                                      onChanged: (_) => updateDuration(),
                                                    ),
                                                  ),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: Text(':', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller: minuteController,
                                                      textAlign: TextAlign.center,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      decoration: const InputDecoration(labelText: 'M', isDense: true, border: OutlineInputBorder()),
                                                      onChanged: (_) => updateDuration(),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

          if (uses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Center(child: Text('No uses recorded yet. Press "Add Use" to start.')),
            ),
        ],
      ),
    );
  }

  // --- End of Helper Methods ---

  Widget buildFixedTitle(String text) {
    return Container(
      height: 42,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Helper method to build flag widget
  Widget _buildFlag(String countryCode) {
    return SizedBox(
      width: 40,
      height: 28,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          'https://flagcdn.com/w160/${countryCode.toLowerCase()}.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: Icon(Icons.flag_outlined, color: Colors.grey[400], size: 20),
            );
          },
        ),
      ),
    );
  }

  void showAirportDetailsModal(BuildContext context, Airport airport, AirportProvider airportProvider, CountryProvider countryProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext sheetContext) {
        return Consumer2<AirportProvider, CountryProvider>(
          builder: (context, airportProvider, countryProvider, child) {
            final useCount = airportProvider.getVisitCount(airport.iataCode);

            String countryName = airport.country;
            try {
              final matchedCountry = countryProvider.allCountries.firstWhere(
                      (c) => c.isoA2.toUpperCase() == airport.country.toUpperCase()
              );
              countryName = matchedCountry.name;
            } catch (_) {}

            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Column(
                children: [
                  Container(
                    color: Colors.blue.shade800,
                    padding: const EdgeInsets.only(
                      top: 12,
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                              },
                              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${airport.name} (${airport.iataCode})',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                countryName,
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$useCount',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'uses',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildUseDetails(context, airport, airportProvider),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildFlightChecklist(BuildContext context, AirlineProvider airlineProvider, AirportProvider airportProvider) {
    if (achievement.id.startsWith('flights_') || achievement.requiresBusinessClass || achievement.requiresFirstClass) {
      List<FlightLog> displayLogs = airlineProvider.allFlightLogs;

      if (achievement.requiresBusinessClass) {
        displayLogs = displayLogs.where((l) => l.seatClass == 'Business').toList();
      } else if (achievement.requiresFirstClass) {
        displayLogs = displayLogs.where((l) => l.seatClass == 'First').toList();
      }

      if (displayLogs.isEmpty) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.flight_takeoff, size: 48, color: Color(0xFFAB47BC)), // Purple
                const SizedBox(height: 16),
                Text(
                  'No flights recorded yet',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add flight logs to track your journey',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final sortedLogs = List.from(displayLogs)
        ..sort((a, b) {
          final dateA = DateTime.tryParse(a.date);
          final dateB = DateTime.tryParse(b.date);
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: sortedLogs.length,
        itemBuilder: (context, index) {
          final log = sortedLogs[index];

          String dateStr = 'Unknown';
          if (log.date != 'Unknown') {
            final parsedDate = DateTime.tryParse(log.date);
            if (parsedDate != null) {
              dateStr = DateFormat('MMM d, yyyy').format(parsedDate);
            }
          }

          final airline = airlineProvider.airlines.firstWhereOrNull(
                  (a) => a.code == log.airlineCode
          );

          return GestureDetector(
            onTap: airline != null ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AirlineDetailScreen(airlineName: airline.name),
                ),
              );
            } : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: airline != null && airline.code3 != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/avcodes_banners/${airline.code3}.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.flight, color: Color(0xFFAB47BC)); // Purple
                          },
                        ),
                      )
                          : const Icon(Icons.flight, color: Color(0xFFAB47BC)), // Purple
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            airline?.name ?? log.airlineCode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${log.departureIata} → ${log.arrivalIata}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFAB47BC), // Purple
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if ((achievement.id == 'top10_airports' || achievement.id.startsWith('airport_')) && achievement.targetIsoCodes != null) {
      final visitedAirports = airportProvider.visitedAirports;
      final targetAirports = achievement.targetIsoCodes!.toList()..sort();

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: targetAirports.length,
        itemBuilder: (context, index) {
          final iataCode = targetAirports[index];
          final bool isVisited = visitedAirports.contains(iataCode);

          final airport = airportProvider.allAirports.firstWhere(
                (a) => a.iataCode == iataCode,
            orElse: () => airportProvider.allAirports.first,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () {
                  final countryProvider = Provider.of<CountryProvider>(context, listen: false);
                  showAirportDetailsModal(context, airport, airportProvider, countryProvider);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: _buildFlag(airport.country),
                title: buildFixedTitle(airport.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${airport.iataCode} • ${airport.country}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                trailing: isVisited
                    ? const Icon(Icons.check_circle, color: Color(0xFFAB47BC), size: 24) // Purple
                    : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24),
              ),
            ),
          );
        },
      );
    }

    if ((achievement.id == 'top10_airlines' || achievement.id.startsWith('airline_')) && achievement.targetIsoCodes != null) {
      final visitedAirlines = airlineProvider.airlines.where((a) => a.totalTimes > 0).map((a) => a.code).toSet();
      final targetAirlines = achievement.targetIsoCodes!.toList();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: targetAirlines.length,
            itemBuilder: (context, index) {
              final code = targetAirlines[index];
              final bool isVisited = visitedAirlines.contains(code);

              final airline = airlineProvider.airlines.firstWhereOrNull(
                      (a) => a.code == code
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: airline != null ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AirlineDetailScreen(airlineName: airline.name),
                        ),
                      );
                    } : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: airline != null && airline.code3 != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/avcodes_banners/${airline.code3}.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.connecting_airports,
                              color: Color(0xFFAB47BC), // Purple
                              size: 20,
                            );
                          },
                        ),
                      )
                          : const Icon(
                        Icons.connecting_airports,
                        color: Color(0xFFAB47BC), // Purple
                        size: 20,
                      ),
                    ),
                    title: Text(
                      airline?.name ?? code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    trailing: isVisited
                        ? const Icon(Icons.check_circle, color: Color(0xFFAB47BC), size: 24) // Purple
                        : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24),
                  ),
                ),
              );
            },
          ),
        ],
      );
    }
    if (achievement.id.startsWith('airlines_')) {
      final airlines = airlineProvider.airlines
          .where((a) => a.totalTimes > 0)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (airlines.isEmpty) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              children: [
                Text(
                  'No airlines flown yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start your journey!',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: airlines.length,
        itemBuilder: (context, index) {
          final airline = airlines[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AirlineDetailScreen(airlineName: airline.name),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: airline.code3 != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/avcodes_banners/${airline.code3}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.connecting_airports,
                          color: Color(0xFFAB47BC), // Purple
                          size: 20,
                        );
                      },
                    ),
                  )
                      : const Icon(
                    Icons.connecting_airports,
                    color: Color(0xFFAB47BC), // Purple
                    size: 20,
                  ),
                ),
                title: Text(
                  airline.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${airline.totalTimes} flights',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                trailing: const Icon(Icons.check_circle, color: Color(0xFFAB47BC), size: 24), // Purple
              ),
            ),
          );
        },
      );
    }

    if (achievement.id.startsWith('airports_')) {
      final airports = airportProvider.allAirports
          .where((a) => airportProvider.visitedAirports.contains(a.iataCode))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (airports.isEmpty) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              children: [
                Text(
                  'No airports visited yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start your journey!',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: airports.length,
        itemBuilder: (context, index) {
          final airport = airports[index];
          final useCount = airportProvider.getVisitCount(airport.iataCode);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () {
                  final countryProvider = Provider.of<CountryProvider>(context, listen: false);
                  showAirportDetailsModal(context, airport, airportProvider, countryProvider);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: _buildFlag(airport.country),
                title: buildFixedTitle(airport.name),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${airport.iataCode} • $useCount visits',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                trailing: const Icon(Icons.check_circle, color: Color(0xFFAB47BC), size: 24), // Purple
              ),
            ),
          );
        },
      );
    }

    // UPDATED: Alliance Logic with new airlineAllianceCodes (ICAO based)
    if (achievement.id == 'skyteam_20' || achievement.id == 'oneworld_20' || achievement.id == 'staralliance_20') {
      final String allianceFilter;

      if (achievement.id == 'skyteam_20') {
        allianceFilter = 'SkyTeam';
      } else if (achievement.id == 'oneworld_20') {
        allianceFilter = 'OneWorld';
      } else {
        allianceFilter = 'Star Alliance';
      }

      // 1. Get ALL ICAO codes belonging to this alliance
      final allianceMemberCodes = airlineAllianceCodes.entries
          .where((e) => e.value == allianceFilter)
          .map((e) => e.key)
          .toList()
        ..sort((a, b) => (_icaoToName[a] ?? a).compareTo(_icaoToName[b] ?? b)); // 이름 순 정렬

      // 2. Get set of airlines user has visited (using ICAO Code3)
      final visitedAirlineCode3s = airlineProvider.airlines
          .where((a) => a.totalTimes > 0 && a.code3 != null)
          .map((a) => a.code3!)
          .toSet();

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: allianceMemberCodes.length,
        itemBuilder: (context, index) {
          final icaoCode = allianceMemberCodes[index];
          final airlineName = _icaoToName[icaoCode] ?? icaoCode;
          final isVisited = visitedAirlineCode3s.contains(icaoCode);

          // Find airline object to get the logo code if available (Code3 매칭)
          final airline = airlineProvider.airlines.firstWhereOrNull(
                  (a) => a.code3 == icaoCode
          );

          // Fallback: If not found by Code3, try Name (for backward compatibility or display)
          final displayAirline = airline ?? airlineProvider.airlines.firstWhereOrNull((a) => a.name == airlineName);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: (displayAirline != null) ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AirlineDetailScreen(airlineName: displayAirline.name),
                    ),
                  );
                } : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: (displayAirline != null && displayAirline.code3 != null)
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/avcodes_banners/${displayAirline.code3}.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.connecting_airports,
                          color: isVisited ? const Color(0xFFAB47BC) : Colors.grey.shade400, // Purple
                          size: 20,
                        );
                      },
                    ),
                  )
                      : Icon(
                    Icons.connecting_airports,
                    color: isVisited ? const Color(0xFFAB47BC) : Colors.grey.shade400, // Purple
                    size: 20,
                  ),
                ),
                title: Text(
                  airlineName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isVisited ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                subtitle: Text(
                  icaoCode,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
                // Standard Checklist Trailing Icon
                trailing: isVisited
                    ? const Icon(Icons.check_circle, color: Color(0xFFAB47BC), size: 24) // Purple
                    : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24),
              ),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  // Rated Airlines (Airline Reviewer)

  Widget buildRatedAirlineChecklist(BuildContext context, AirlineProvider airlineProvider) {
    final ratedAirlines = airlineProvider.airlines
        .where((a) => a.rating > 0)
        .toList();

    ratedAirlines.sort((a, b) => b.rating.compareTo(a.rating));

    if (ratedAirlines.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.rate_review_outlined,
                size: 60,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No airlines rated yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: ratedAirlines.length,
      itemBuilder: (context, index) {
        final airline = ratedAirlines[index];
        final double rating = airline.rating;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              // ADDED: Navigation to Airline Detail
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AirlineDetailScreen(airlineName: airline.name),
                  ),
                );
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: airline.code3 != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/avcodes_banners/${airline.code3}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.connecting_airports,
                        color: Color(0xFFAB47BC), // Purple
                        size: 20,
                      );
                    },
                  ),
                )
                    : const Icon(
                  Icons.connecting_airports,
                  color: Color(0xFFAB47BC), // Purple
                  size: 20,
                ),
              ),
              title: Text(
                airline.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.check_circle, color: Color(0xFFAB47BC), size: 24), // Purple
            ),
          ),
        );
      },
    );
  }

  Widget buildAirportStatusChecklist(BuildContext context, AirportProvider airportProvider) {
    List<String> targetIataCodes = [];

    if (achievement.requiresAirportHub) {
      targetIataCodes = airportProvider.allAirports
          .where((a) => airportProvider.isHub(a.iataCode))
          .map((a) => a.iataCode)
          .toList();
    } else if (achievement.requiresAirportRating) {
      targetIataCodes = airportProvider.allAirports
          .where((a) => airportProvider.getRating(a.iataCode) > 0)
          .map((a) => a.iataCode)
          .toList();
    }

    targetIataCodes.sort();

    if (targetIataCodes.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                achievement.requiresAirportHub ? Icons.stars : Icons.rate_review_outlined,
                size: 60,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                achievement.requiresAirportHub
                    ? 'No hub airports set yet'
                    : 'No airports rated yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: targetIataCodes.length,
      itemBuilder: (context, index) {
        final iataCode = targetIataCodes[index];

        final airport = airportProvider.allAirports.firstWhere(
              (a) => a.iataCode == iataCode,
          orElse: () => airportProvider.allAirports.first,
        );

        final double rating = airportProvider.getRating(iataCode);
        final countryProvider = Provider.of<CountryProvider>(context, listen: false);

        return GestureDetector(
          onTap: () {
            showAirportDetailsModal(context, airport, airportProvider, countryProvider);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: _buildFlag(airport.country),
                title: Container(
                  height: 42,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${airport.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                subtitle: (rating > 0 && !achievement.requiresAirportHub) ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ) : null,
                trailing: const Icon(Icons.check_circle, color: Color(0xFFAB47BC), size: 24), // Purple
              ),
            ),
          ),
        );
      },
    );
  }
}