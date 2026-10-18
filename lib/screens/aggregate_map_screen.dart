// lib/screens/aggregate_map_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/my_tile_layer.dart';
import 'package:latlong2/latlong.dart';

enum MapFilter { all, visited }

class AggregateMapScreen extends StatefulWidget {
  final String title;
  final List<Landmark> allItems;
  final Set<String> visitedItems;
  final Function(String) onToggleVisited;

  const AggregateMapScreen({
    super.key,
    required this.title,
    required this.allItems,
    required this.visitedItems,
    required this.onToggleVisited,
  });

  @override
  State<AggregateMapScreen> createState() => _AggregateMapScreenState();
}

class _AggregateMapScreenState extends State<AggregateMapScreen> {
  final MapController _mapController = MapController();
  List<Landmark> _visibleItems = [];
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  bool _isMapReady = false;
  MapFilter _mapFilter = MapFilter.visited;
  Landmark? _selectedItem;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterVisibleItems);
    _visibleItems = widget.allItems;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _filterVisibleItems();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onMapChanged(MapPosition position, bool hasGesture) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _filterVisibleItems);
  }

  void _filterVisibleItems() {
    if (!mounted || !_isMapReady) return;
    final bounds = _mapController.camera.visibleBounds;
    final searchQuery = _searchController.text.toLowerCase();

    final newVisibleItems = widget.allItems.where((item) {
      final isInBounds = bounds.contains(LatLng(item.latitude, item.longitude));
      final matchesSearch = item.name.toLowerCase().contains(searchQuery);
      return isInBounds && matchesSearch;
    }).toList();

    // [수정] rank -> global_rank
    newVisibleItems.sort((a, b) => a.global_rank.compareTo(b.global_rank));
    if (!listEquals(_visibleItems, newVisibleItems)) {
      setState(() => _visibleItems = newVisibleItems);
    }
  }

  Widget _buildInfoPopup(Landmark item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _selectedItem = null),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.title))),
      body: Column(
        children: [
          Expanded(flex: 3, child: _buildMap(widget.visitedItems)),
          Expanded(flex: 4, child: _buildChecklistSection(widget.visitedItems)),
        ],
      ),
    );
  }

  Widget _buildMap(Set<String> visitedItems) {
    final itemsForMapPins = _mapFilter == MapFilter.visited
        ? widget.allItems.where((item) => visitedItems.contains(item.name)).toList()
        : widget.allItems;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(30, 0),
            initialZoom: 0,
            onPositionChanged: _onMapChanged,
            onMapReady: () {
              if (mounted) {
                setState(() {
                  _isMapReady = true;
                  _filterVisibleItems();
                });
              }
            },
            onTap: (_, __) => setState(() => _selectedItem = null),
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(const LatLng(-90, -180), const LatLng(90, 180)),
            ),
          ),
          children: [
            const MyTileLayer(),
            MarkerLayer(
              markers: itemsForMapPins.map((item) {
                final isVisited = visitedItems.contains(item.name);

                IconData markerIcon = Icons.account_balance;

                // [수정] 유네스코 색상 로직 제거하고 단순화
                Color markerColor = isVisited ? Theme.of(context).primaryColor : Colors.grey;

                return Marker(
                  width: 40, height: 40,
                  point: LatLng(item.latitude, item.longitude),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedItem = item),
                    child: Tooltip(
                      message: item.name,
                      child: Icon(
                        markerIcon,
                        color: markerColor,
                        size: 15,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 2.0)],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selectedItem != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_selectedItem!.latitude, _selectedItem!.longitude),
                    width: 200, height: 50,
                    child: _buildInfoPopup(_selectedItem!),
                  )
                ],
              )
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Card(
            elevation: 2,
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label:  Text(tr('All')),
                    selected: _mapFilter == MapFilter.all,
                    onSelected: (selected) {
                      if (selected) setState(() => _mapFilter = MapFilter.all);
                    },
                    showCheckmark: false,
                    labelStyle: TextStyle(fontSize: 11, color: _mapFilter == MapFilter.all ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface),
                    selectedColor: Theme.of(context).primaryColor,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 2),
                  ChoiceChip(
                    label:  Text(tr('Visited')),
                    selected: _mapFilter == MapFilter.visited,
                    onSelected: (selected) {
                      if (selected) setState(() => _mapFilter = MapFilter.visited);
                    },
                    showCheckmark: false,
                    labelStyle: TextStyle(fontSize: 11, color: _mapFilter == MapFilter.visited ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface),
                    selectedColor: Theme.of(context).primaryColor,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistSection(Set<String> visitedItems) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: tr('Search ${widget.title}'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                  : null,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _visibleItems.length,
            itemBuilder: (context, index) {
              final item = _visibleItems[index];
              final isVisited = visitedItems.contains(item.name);

              void showLandmarkInfoDialog() {
                final bool hasOverview = item.overview != null && item.overview!.trim().isNotEmpty;
                final bool hasHistory = item.history_significance != null && item.history_significance!.trim().isNotEmpty;
                final bool hasHighlights = item.highlights != null && item.highlights!.trim().isNotEmpty;

                String infoText = '';
                if (hasOverview) {
                  infoText += 'OVERVIEW\n\n${item.overview!}\n\n';
                }
                if (hasHistory) {
                  infoText += 'HISTORY & SIGNIFICANCE\n\n${item.history_significance!}\n\n';
                }
                if (hasHighlights) {
                  infoText += 'HIGHLIGHTS\n\n${item.highlights!}';
                }

                if (infoText.isEmpty) {
                  infoText = 'No detailed information available.';
                }

                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(item.name),
                      content: SingleChildScrollView(
                        child: Text(tr(infoText.trim())),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child:  Text(tr('close')),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              }

              return ListTile(
                title: Text(item.name),
                subtitle: Text(tr(item.countriesIsoA3.join(', '))),
                onTap: () {
                  widget.onToggleVisited(item.name);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: showLandmarkInfoDialog,
                      tooltip: tr('View Info'),
                    ),
                    Checkbox(
                      value: isVisited,
                      onChanged: (bool? value) {
                        widget.onToggleVisited(item.name);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}