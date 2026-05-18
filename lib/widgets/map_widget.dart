import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatelessWidget {
  final GoogleMapController? controller;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final CameraPosition initialPosition;
  final Function(GoogleMapController) onMapCreated;
  
  const MapWidget({
    super.key,
    this.controller,
    required this.markers,
    required this.polylines,
    required this.initialPosition,
    required this.onMapCreated,
  });
  
  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: initialPosition,
      markers: markers,
      polylines: polylines,
      onMapCreated: onMapCreated,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      compassEnabled: true,
    );
  }
}