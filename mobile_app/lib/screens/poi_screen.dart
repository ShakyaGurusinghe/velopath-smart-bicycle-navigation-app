import 'package:flutter/material.dart';
import 'package:mobile_app/screens/poi_map_screen.dart';
import 'package:mobile_app/screens/add_poi_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';

class PoiScreen extends StatefulWidget {
  const PoiScreen({super.key});

  @override
  State<PoiScreen> createState() => _PoiScreenState();
}

class _PoiScreenState extends State<PoiScreen> {
  // Data
  List<dynamic> pois = [];
  List<dynamic> filteredPois = [];
  bool isLoading = true;
  int loyaltyPoints = 0;

  // Filters
  String selectedDistrict = "All";
  String selectedTier = "All";
  String searchQuery = "";
  bool showLowQuality = false;

  LatLng? myLocation;

  final double displayRadiusKm = 5.0;
  final Distance distance = const Distance();

  @override
  void initState() {
    super.initState();
    initAll();
  }

  Future<void> initAll() async {
    await getMyLocation(silent: true);
    await fetchPOIs();
  }

  // ✅ FIX 1: sends district param to backend
  Future<void> fetchPOIs() async {
    if (mounted) setState(() => isLoading = true);

    final districtParam = selectedDistrict != "All"
        ? "?district=${Uri.encodeComponent(selectedDistrict)}"
        : "";
    final url = "${ApiConfig.rankedPois}$districtParam";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        pois = List<dynamic>.from(data['pois']);

        for (var poi in pois) {
          poi['district'] ??= "Other";
          poi['tier'] ??= "low";
        }

        applyFilters();
      } else {
        throw Exception('Failed to load POIs (status ${response.statusCode})');
      }
    } catch (e) {
      debugPrint("Error fetching POIs: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching POIs: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void applyFilters() {
    final q = searchQuery.toLowerCase();

    final filtered = pois.where((poi) {
      final amenity = (poi['amenity'] ?? "").toString().toLowerCase();
      final name    = (poi['name']    ?? "").toString().toLowerCase();
      final tier    = (poi['tier']    ?? "low").toString();

      final matchesSearch     = amenity.contains(q) || name.contains(q);
      final matchesTierFilter = selectedTier == "All" || tier == selectedTier;
      final matchesVisibility = showLowQuality || tier != "low";

      // ✅ FIX 3: proximity only active when "All" districts selected
      // When a specific district is chosen, skip proximity check
      bool matchesProximity = true;
      if (myLocation != null && selectedDistrict == "All") {
        final latRaw = poi['lat'];
        final lonRaw = poi['lon'];

        double? poiLat;
        double? poiLon;

        if (latRaw is String) poiLat = double.tryParse(latRaw);
        if (lonRaw is String) poiLon = double.tryParse(lonRaw);
        if (latRaw is num) poiLat = latRaw.toDouble();
        if (lonRaw is num) poiLon = lonRaw.toDouble();

        if (poiLat != null && poiLon != null) {
          final distKm =
              distance(LatLng(poiLat, poiLon), myLocation!) / 1000.0;
          matchesProximity = distKm <= displayRadiusKm;
        } else {
          matchesProximity = false;
        }
      }

      return matchesSearch &&
          matchesTierFilter &&
          matchesVisibility &&
          matchesProximity;
    }).toList();

    if (!mounted) return;
    setState(() => filteredPois = filtered);
  }

  Future<void> getMyLocation({bool silent = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!silent && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      if (!mounted) return;
      setState(
          () => myLocation = LatLng(position.latitude, position.longitude));
      applyFilters();
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _tierIcon(String tier) {
    switch (tier) {
      case 'high':
        return Icons.star_rounded;
      case 'medium':
        return Icons.star_half_rounded;
      default:
        return Icons.star_border_rounded;
    }
  }

  Widget _buildPoiCard(Map<String, dynamic> poi) {
    final name          = poi['name']          ?? "Unnamed";
    final amenity       = poi['amenity']       ?? "";
    final district      = poi['district']      ?? "";
    final tier          = (poi['tier']         ?? "low").toString();
    final adjustedScore = poi['adjustedScore'] ?? 0;
    final voteCount     = poi['vote_count']    ?? 0;

    final color = _tierColor(tier);
    final icon  = _tierIcon(tier);

    return Card(
      elevation: tier == 'high' ? 3 : tier == 'medium' ? 1.5 : 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: tier == 'high'
            ? BorderSide(color: Colors.green.withOpacity(0.4), width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tier.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "$amenity • $district",
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "⭐ $adjustedScore  👥 $voteCount",
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        onTap: () async {
          if (myLocation == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please enable "Use My Location" first.')),
            );
            return;
          }

          final updatedPoi = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => POIMapScreen(
                startPoint: myLocation!,
                selectedPoi: poi,
                onLoyaltyUpdated: (points) {
                  setState(() => loyaltyPoints += points);
                },
              ),
            ),
          );

          if (updatedPoi != null) {
            setState(() {
              final index =
                  pois.indexWhere((p) => p['id'] == updatedPoi['id']);
              if (index != -1) {
                pois[index] = updatedPoi;
                applyFilters();
              }
            });
          }
        },
      ),
    );
  }

  int get _lowQualityTotal =>
      pois.where((p) => (p['tier'] ?? 'low') == 'low').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 30, 128, 176),
        title: const Text(
          "Places to visit",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 18, 96, 145),
        child: const Icon(Icons.add_location_alt),
        onPressed: () async {
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPOIScreen()),
          );
          if (added == true) fetchPOIs();
        },
      ),
      body: Column(
        children: [
          // ── Row 1: District dropdown + Location button ────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedDistrict,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "District",
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      "All",
                      "Colombo",
                      "Gampaha",
                      "Kalutara",
                      "Kandy",
                      "Matale",
                      "Nuwara Eliya",
                      "Galle",
                      "Matara",
                      "Hambantota",
                      "Jaffna",
                      "Kilinochchi",
                      "Mannar",
                      "Vavuniya",
                      "Mullaitivu",
                      "Batticaloa",
                      "Ampara",
                      "Trincomalee",
                      "Kurunegala",
                      "Puttalam",
                      "Anuradhapura",
                      "Polonnaruwa",
                      "Badulla",
                      "Monaragala",
                      "Ratnapura",
                      "Kegalle",
                    ]
                        .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    // ✅ FIX 2: calls fetchPOIs() to re-fetch with district
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => selectedDistrict = val);
                      fetchPOIs();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text("My Location",
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                  ),
                  onPressed: () => getMyLocation(silent: false),
                ),
              ],
            ),
          ),

          // ── Row 2: Tier dropdown ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: DropdownButtonFormField<String>(
              value: selectedTier,
              decoration: const InputDecoration(
                labelText: "Quality Tier",
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: "All",
                  child: Row(children: [
                    const Icon(Icons.layers,
                        size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 6),
                    const Text("All Tiers"),
                  ]),
                ),
                DropdownMenuItem(
                  value: "high",
                  child: Row(children: [
                    Icon(Icons.star_rounded,
                        size: 16, color: Colors.green[600]),
                    const SizedBox(width: 6),
                    const Text("High Quality"),
                  ]),
                ),
                DropdownMenuItem(
                  value: "medium",
                  child: Row(children: [
                    const Icon(Icons.star_half_rounded,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    const Text("Medium Quality"),
                  ]),
                ),
                DropdownMenuItem(
                  value: "low",
                  child: Row(children: [
                    const Icon(Icons.star_border_rounded,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text("Low Quality"),
                  ]),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() => selectedTier = val);
                applyFilters();
              },
            ),
          ),

          // ── Row 3: Search field ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by type (hospital, school…)",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) {
                searchQuery = val.toLowerCase();
                applyFilters();
              },
            ),
          ),

          // ── Row 4: Hidden count + Show/Hide toggle ────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_off,
                          size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        "$_lowQualityTotal low-quality hidden",
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    showLowQuality
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 15,
                    color: Colors.blueGrey,
                  ),
                  label: Text(
                    showLowQuality ? "Hide low quality" : "Show all",
                    style: const TextStyle(
                        fontSize: 12, color: Colors.blueGrey),
                  ),
                  onPressed: () {
                    setState(() => showLowQuality = !showLowQuality);
                    applyFilters();
                  },
                ),
              ],
            ),
          ),

          // ── Result count ──────────────────────────────────────────
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${filteredPois.length} place${filteredPois.length == 1 ? '' : 's'} found"
                  "${selectedDistrict != 'All' ? ' in $selectedDistrict' : ''}",
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ),

          // ── POI list ──────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color.fromARGB(255, 21, 98, 153)))
                : filteredPois.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              selectedDistrict != "All"
                                  ? "No POIs found in $selectedDistrict."
                                  : "No POIs found.",
                              style:
                                  TextStyle(color: Colors.grey[500]),
                            ),
                            if (!showLowQuality && _lowQualityTotal > 0)
                              TextButton(
                                onPressed: () {
                                  setState(
                                      () => showLowQuality = true);
                                  applyFilters();
                                },
                                child: const Text(
                                    "Show low quality POIs too?"),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: filteredPois.length,
                        itemBuilder: (context, index) {
                          final poi = Map<String, dynamic>.from(
                              filteredPois[index]);
                          return _buildPoiCard(poi);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}