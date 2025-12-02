import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colombo = LatLng(6.9271, 79.8612);
    final kandy = LatLng(7.2906, 80.6337);

    return Scaffold(
      appBar: AppBar(title: const Text('Route Map')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: colombo,
          initialZoom: 8.5,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [colombo, kandy],
                strokeWidth: 4,
                color: Colors.blueAccent,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: colombo,
                width: 80,
                height: 80,
                child: const Icon(Icons.location_on, color: Colors.green, size: 40),
              ),
              Marker(
                point: kandy,
                width: 80,
                height: 80,
                child: const Icon(Icons.flag, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
