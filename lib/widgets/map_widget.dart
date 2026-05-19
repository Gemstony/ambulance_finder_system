import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapWidget extends StatelessWidget {
  final MapController? controller;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final LatLng initialCenter;
  final double initialZoom;
  final bool showMyLocationButton;
  final VoidCallback? onMyLocationPressed;

  const MapWidget({
    super.key,
    this.controller,
    required this.markers,
    required this.polylines,
    required this.initialCenter,
    this.initialZoom = 14,
    this.showMyLocationButton = true,
    this.onMyLocationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ambulance_finder.app',
            ),
            MarkerLayer(markers: markers),
            PolylineLayer(polylines: polylines),
          ],
        ),
        if (showMyLocationButton)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: onMyLocationPressed,
              child: const Icon(Icons.my_location),
            ),
          ),
      ],
    );
  }
}
