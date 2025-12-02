import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../data/models/route_model.dart';

class RoutingEngineProvider extends ChangeNotifier {
  List<RouteModel> _routes = [];
  bool _isLoading = false;

  List<RouteModel> get routes => _routes;
  bool get isLoading => _isLoading;

  Future<void> fetchRoutes() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Replace IP with your system IP or 10.0.2.2 for Android emulator
      final url = Uri.parse('http://10.0.2.2:5001/api/routing/generate');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _routes = (data['routes'] as List)
            .map((routeJson) => RouteModel.fromJson(routeJson))
            .toList();
      } else {
        _routes = [];
      }
    } catch (e) {
      debugPrint("❌ Error fetching routes: $e");
      _routes = [];
    }

    _isLoading = false;
    notifyListeners();
  }
}
