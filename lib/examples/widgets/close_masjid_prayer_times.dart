import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:masjid_app/examples/map_point.dart';
import 'package:masjid_app/examples/styles/app_styles.dart';
import 'package:masjid_app/examples/utils/analog_clock_builder.dart';
import 'package:masjid_app/examples/utils/get_prayer_times.dart';
import 'package:masjid_app/examples/utils/getter_functions.dart';
import 'package:masjid_app/examples/utils/open_maps_sheet.dart';
import 'package:masjid_app/examples/widgets/drawer_widget.dart';
import 'package:masjid_app/examples/widgets/prayer_time_table.dart';

import 'package:geolocator/geolocator.dart';

class CloseMasjidPrayerTimes extends StatefulWidget {
  const CloseMasjidPrayerTimes({super.key});

  @override
  State<CloseMasjidPrayerTimes> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<CloseMasjidPrayerTimes> {
  var collection = FirebaseFirestore.instance.collection('masjids');
  var prayerCollection = FirebaseFirestore.instance.collection('prayer_time');
  late List<MapPoint> items = [];
  late List<Map<String, dynamic>> prayerItems = [];
  List<Map<String, String>> prayerTimes = [];
  late MapPoint closestMasjid;
  late Future<void> _dataFetching;
  var masjidName = '';
  double? lat;
  double? long;

  Position? userLocation;

  @override
  void initState() {
    super.initState();
    _dataFetching = fetchData();
  }

  Future<void> fetchData() async {
    try {
      var data = await collection.get();
      var prayerData = await prayerCollection.get();
      List<MapPoint> mapPoints = getMapPoints(data.docs);
      List<Map<String, dynamic>> prayerTimes = getPrayerTimes(prayerData.docs);
      setState(() {
        items = mapPoints;
        prayerItems = prayerTimes;
      });
      await getCurrentLocation();
      moveToClosestMasjid();
    } catch (e) {
      if (!context.mounted) return;
      debugPrint("$e");
    }
  }

  Future<void> getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      userLocation = position;
      moveToClosestMasjid();
    });
  }

  List<Map<String, String>> _getPrayerTimesForLocation(MapPoint point) {
    return getPrayerTimesForLocation(prayerItems, point.documentId);
  }

  void moveToClosestMasjid() async {
    // await getCurrentLocation();
    // Get the closest masjid to the user's location
    closestMasjid = findClosestMasjid(
      userLocation!.latitude,
      userLocation!.longitude,
      items,
    );

    // Get the prayer times for the closest masjid
    masjidName = closestMasjid.name;
    lat = closestMasjid.latitude;
    long = closestMasjid.longitude;
    prayerTimes = _getPrayerTimesForLocation(closestMasjid);
  }

  MapPoint findClosestMasjid(
      double userLatitude, double userLongitude, List<MapPoint> masjids) {
    double minDistance = double.infinity;
    MapPoint closestMasjid = masjids.first;

    for (MapPoint masjid in masjids) {
      double distance = calculateDistance(
        userLatitude,
        userLongitude,
        masjid.latitude,
        masjid.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestMasjid = masjid;
      }
    }

    return closestMasjid;
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Radius of the Earth in kilometers

    double dLat = radians(lat2 - lat1);
    double dLon = radians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    double distance = R * c; // Distance in kilometers

    return distance;
  }

  double radians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _dataFetching,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          ); // Show loading indicator
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          return buildUI(); // Build your UI with the fetched data
        }
      },
    );
  }

  Widget buildUI() {
    DrawerWidgets drawerWidgets = DrawerWidgets();
    TextStyle myTextStyle =
        const TextStyle(color: AppStyles.foregroundColorYellow);
    double screenWidth = MediaQuery.of(context).size.width;
    double dynamicFontSize = screenWidth * 0.04;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asosiy'),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 3,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 5),
              Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    color: AppStyles.backgroundColorGreen900),
                margin: const EdgeInsets.all(12.0),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    PrayerTimeTable(
                      prayerTimes: prayerTimes,
                      textStyle: myTextStyle,
                      title: 'Azon Vaqtlari',
                      titleColor: AppStyles.foregroundColorYellow,
                      borderColor: AppStyles.backgroundColorGreen900,
                      buildCells: buildAzonPrayerTimeCells,
                      clockColor: AppStyles.foregroundColorYellow,
                    ),
                    PrayerTimeTable(
                      prayerTimes: prayerTimes,
                      textStyle: myTextStyle,
                      title: 'Takbir Vaqtlari',
                      titleColor: AppStyles.foregroundColorYellow,
                      borderColor: AppStyles.backgroundColorGreen900,
                      buildCells: buildTakbirPrayerTimeCells,
                      clockColor: AppStyles.foregroundColorYellow,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(masjidName,
                                style: TextStyle(
                                    fontSize: dynamicFontSize,
                                    color: AppStyles.foregroundColorYellow)),
                          ),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: FloatingActionButton.small(
                              onPressed: () async {
                                await openMapsSheet(
                                    context, lat, long, masjidName);
                              },
                              backgroundColor:
                                  AppStyles.backgroundColorGreen700,
                              foregroundColor: AppStyles.foregroundColorYellow,
                              child: const Icon(Icons.location_on_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: drawerWidgets.buildDrawer(context),
    );
  }
}
