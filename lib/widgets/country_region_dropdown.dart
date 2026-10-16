import 'package:jidoapp/widgets/country_region_access_gate.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/services/admin_region_repository.dart';

/// Inline region choices. The caller owns the draft and commits it on Apply.
class CountryRegionDropdown extends StatefulWidget {
  final String countryIsoA2;
  final Color color;
  final bool Function(AdminRegion) isVisited;
  final void Function(AdminRegion, bool)? onChanged;

  const CountryRegionDropdown({
    super.key,
    required this.countryIsoA2,
    required this.color,
    required this.isVisited,
    required this.onChanged,
  });

  @override
  State<CountryRegionDropdown> createState() => _CountryRegionDropdownState();
}

class _CountryRegionDropdownState extends State<CountryRegionDropdown> {
  late Future<List<AdminRegion>> _regions;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _regions = AdminRegionRepository.regionsFor(widget.countryIsoA2);
  }

  @override
  void didUpdateWidget(CountryRegionDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryIsoA2 != widget.countryIsoA2) {
      _regions = AdminRegionRepository.regionsFor(widget.countryIsoA2);
      _query = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminRegion>>(
      future: _regions,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final regions = (snapshot.data ?? <AdminRegion>[])
            .where((region) => !region.isWholeArea)
            .toList();
        if (regions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Subdivision boundaries are unavailable for this area.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          );
        }
        return CountryRegionAccessGate(
          countryIsoA2: widget.countryIsoA2,
          builder: (context) => _buildChoices(context, regions),
        );
      },
    );
  }

  Widget _buildChoices(BuildContext context, List<AdminRegion> regions) {
    final filtered = regions
        .where(
          (r) => r.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    final visited = regions.where(widget.isVisited).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              '$visited / ${regions.length} regions selected',
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search regions',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.onChanged == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Loading visit records...'),
            ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No matching regions.'),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final region = filtered[index];
                  return Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      key: ValueKey('${region.stableKey}::${region.name}'),
                      value: widget.isVisited(region),
                      onChanged: widget.onChanged == null
                          ? null
                          : (value) =>
                                widget.onChanged!(region, value ?? false),
                      activeColor: widget.color,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(region.name),
                      subtitle: region.typeLabel.isEmpty
                          ? null
                          : Text(region.typeLabel),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
