import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';

/// Default pickup warehouse: Merkato, Addis Ababa.
const merkatoWarehouse = LatLng(9.03056, 38.73889);

/// Lets the supplier set the universal warehouse pin by tapping a map.
Future<LatLng?> showWarehouseLocationPicker(
  BuildContext context, {
  LatLng? initial,
}) {
  return showDialog<LatLng>(
    context: context,
    builder: (_) => _WarehouseLocationPicker(initial: initial),
  );
}

class _WarehouseLocationPicker extends StatefulWidget {
  const _WarehouseLocationPicker({this.initial});

  final LatLng? initial;

  @override
  State<_WarehouseLocationPicker> createState() =>
      _WarehouseLocationPickerState();
}

class _WarehouseLocationPickerState extends State<_WarehouseLocationPicker> {
  final MapController _map = MapController();
  late LatLng _selected = widget.initial ?? merkatoWarehouse;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _select(LatLng point) {
    setState(() => _selected = point);
    _map.move(point, _map.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final height = media.height < 620 ? media.height * 0.82 : 560.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 620,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: SupplierColors.seed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warehouse_outlined,
                      color: SupplierColors.seed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Warehouse location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Tap the map to place your pickup point. Merkato is the default.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: SupplierColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _selected,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, point) => _select(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.suq.supplier',
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selected,
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.warehouse,
                          size: 40,
                          color: SupplierColors.seed,
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selected.latitude.toStringAsFixed(5)}, '
                      '${_selected.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SupplierColors.muted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Use this pin'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
