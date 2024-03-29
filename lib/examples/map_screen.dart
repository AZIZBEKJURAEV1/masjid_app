import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:masjid_app/examples/data/user_data.dart';
import 'package:masjid_app/examples/styles/app_styles.dart';
import 'package:masjid_app/examples/utils/get_prayer_times.dart';
import 'package:masjid_app/examples/utils/getter_functions.dart';
// ignore: unused_import
import 'package:masjid_app/examples/utils/upload_masjids_to_firestore.dart';
// ignore: unused_import
import 'package:masjid_app/examples/utils/upload_prayer_times_to_firestore.dart';
import 'package:masjid_app/examples/views/add_masjid_view.dart';
import 'package:masjid_app/examples/widgets/clusterized_icon_painter.dart';
import 'package:masjid_app/examples/widgets/modal_body_view.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:masjid_app/examples/map_point.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async' show Future;

typedef LocationLayerInitCallback = Future<void> Function();

class MapScreen extends StatefulWidget {
  final LocationLayerInitCallback? onLocationLayerInit;
  const MapScreen({super.key, this.onLocationLayerInit});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final YandexMapController _mapController;
  late TextEditingController searchController;
  var _mapZoom = 0.0;

  var collection = FirebaseFirestore.instance.collection('masjids');
  var prayerCollection = FirebaseFirestore.instance.collection('prayer_time');
  late List<MapPoint> items = [];
  late List<Map<String, dynamic>> prayerItems = [];
  List<MapPoint> originalItems = [];
  List<MapObject> mapObject = [];
  Point? newMasjidPoint;
  bool isLoaded = false;
  bool isSearchMode = false;
  bool isNightModeAnabled = false;
  bool mapTapped = false;
  bool isTyping = false;
  bool isNotFound = false;
  bool isMapLoading = false;
  int? _currentOpenModalIndex;
  dynamic initialPosition;

  final animation =
      const MapAnimation(type: MapAnimationType.smooth, duration: 2.0);

  @override
  void initState() {
    isMapLoading = true;
    searchController = TextEditingController();
    _initLocationLayer();
    super.initState();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<MapPoint> getFilteredItems(String searchText) {
    if (searchText.isEmpty) {
      return originalItems;
    } else {
      return originalItems
          .where((item) =>
              item.name.toLowerCase().contains(searchText.toLowerCase()))
          .toList();
    }
  }

  Future<void> _initLocationLayer() async {
    try {
      var data = await collection.get();
      var prayerData = await prayerCollection.get();
      List<MapPoint> mapPoints = getMapPoints(data.docs);
      List<Map<String, dynamic>> prayerTimes = getPrayerTimes(prayerData.docs);
      setState(() {
        items = mapPoints;
        originalItems = mapPoints;
        prayerItems = prayerTimes;
        isLoaded = true;
      });
      // await getCurrentLocation();
    } catch (e) {
      if (!context.mounted) return;
      debugPrint("check this error $e");
    }
  }

  Future<void> onLocationLayerInit() async {
    await _initLocationLayer();
  }

  ClusterizedPlacemarkCollection _getClusterizedCollection({
    required List<PlacemarkMapObject> placemarks,
  }) {
    return ClusterizedPlacemarkCollection(
        mapId: const MapObjectId('clusterized-1'),
        placemarks: placemarks,
        radius: 50,
        minZoom: 15,
        onClusterAdded: (self, cluster) async {
          return cluster.copyWith(
            appearance: cluster.appearance.copyWith(
              opacity: 1.0,
              icon: PlacemarkIcon.single(
                PlacemarkIconStyle(
                  image: BitmapDescriptor.fromBytes(
                    await ClusterIconPainter(cluster.size)
                        .getClusterIconBytes(),
                  ),
                ),
              ),
            ),
          );
        },
        onClusterTap: (self, cluster) async {
          await _mapController.moveCamera(
            animation: const MapAnimation(
                type: MapAnimationType.linear, duration: 0.3),
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: cluster.placemarks.first.point,
                zoom: _mapZoom + 1,
              ),
            ),
          );
        });
  }

  List<PlacemarkMapObject> _getPlacemarkObjects(BuildContext context) {
    return items.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      return PlacemarkMapObject(
        mapId: MapObjectId('MapObject $index'),
        point: Point(latitude: point.latitude, longitude: point.longitude),
        opacity: 1,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: BitmapDescriptor.fromAssetImage(
              'assets/mosque.png',
            ),
            scale: 0.25,
          ),
        ),
        onTap: (_, __) {
          // Check if another modal is already open
          if (_currentOpenModalIndex != null) {
            Navigator.pop(context); // Close the currently open modal
            // If the tapped marker is the same as the open one, clear the index
            if (_currentOpenModalIndex == index) {
              _currentOpenModalIndex = null;
              return;
            }
          }
          showModalBottomSheet(
            showDragHandle: true,
            context: context,
            builder: (context) => ModalBodyView(
              point: point,
              prayerTimes: _getPrayerTimesForLocation(point),
              onLocationLayerInit: onLocationLayerInit,
            ),
          ).whenComplete(() {
            _currentOpenModalIndex = null;
          });
          _currentOpenModalIndex = index;
        },
      );
    }).toList();
  }

  List<Map<String, String>> _getPrayerTimesForLocation(MapPoint point) {
    return getPrayerTimesForLocation(prayerItems, point.documentId);
  }

  Future<void> getCurrentLocation() async {
    Position? position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      initialPosition =
          Point(latitude: position.latitude, longitude: position.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    double listViewHeight = items.length * 65.0;
    listViewHeight = listViewHeight.clamp(65.0, 207.0);
    // final currentUserProvider = Provider.of<CurrentUserProvider>(context);
    final currUser = UserData.getUserEmail();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: isSearchMode
            ? TextField(
                onChanged: (text) {
                  setState(() {
                    items = getFilteredItems(text);
                    isTyping = true;
                    isNotFound = items.isEmpty ? true : false;
                  });
                },
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Qidirmoq...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.black12)),
                style: const TextStyle(color: Colors.black),
              )
            : FittedBox(
                child: mapTapped
                    ? const Text('Xaritadan manzilni tanlang')
                    : const Text('MasjidGo')),
        actions: [
          currUser != null && isSearchMode == false
              ? IconButton(
                  onPressed: () {
                    setState(() {
                      mapTapped = !mapTapped;
                    });
                  },
                  icon: mapTapped
                      ? const Icon(Icons.cancel_sharp)
                      : const Icon(Icons.add_location_alt))
              : Container(),
          IconButton(
            icon: isSearchMode
                ? const Icon(Icons.close)
                : const Icon(Icons.search),
            onPressed: () {
              setState(() {
                if (isSearchMode) {
                  if (searchController.text.isNotEmpty) {
                    searchController.text = '';
                  } else {
                    isSearchMode = false;
                  }
                } else {
                  isSearchMode = true;
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          YandexMap(
            onMapTap: (point) {
              mapTapped ? addMark(point: point) : null;
              _initLocationLayer();
            },
            onMapCreated: (controller) async {
              await getCurrentLocation();
              _mapController = controller;
              // await uploadMasjidsToFirestore();
              // await uploadPrayerTimesToFirestore();
              await _mapController.moveCamera(
                initialPosition != null
                    ? CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: initialPosition,
                          zoom: 13,
                        ),
                      )
                    : CameraUpdate.newCameraPosition(
                        const CameraPosition(
                          target: Point(latitude: 41.2995, longitude: 69.2401),
                          zoom: 13,
                        ),
                      ),
                animation: const MapAnimation(),
              );
              setState(() {
                isMapLoading = false;
              });
            },
            onCameraPositionChanged: (cameraPosition, _, __) {
              setState(() {
                _mapZoom = cameraPosition.zoom;
              });
            },
            nightModeEnabled: isNightModeAnabled,
            // mapObjects: mapTapped ? mapObject : _getPlacemarkObjects(context),
            mapObjects: mapTapped
                ? mapObject
                : [
                    _getClusterizedCollection(
                      placemarks: _getPlacemarkObjects(context),
                    ),
                  ],
            onUserLocationAdded: (view) async {
              return view.copyWith(
                  pin: view.pin.copyWith(
                      icon: PlacemarkIcon.single(PlacemarkIconStyle(
                    image: BitmapDescriptor.fromAssetImage('assets/user.png'),
                    scale: 1,
                  ))),
                  arrow: view.arrow.copyWith(
                      icon: PlacemarkIcon.single(PlacemarkIconStyle(
                          image: BitmapDescriptor.fromAssetImage(
                              'assets/arrow.png')))),
                  accuracyCircle: view.accuracyCircle
                      .copyWith(fillColor: Colors.blue.withOpacity(0.5)));
            },
          ),
          Positioned(
            bottom: 475.0,
            right: 5,
            child: FloatingActionButton.small(
              backgroundColor: AppStyles.backgroundColorWhite,
              foregroundColor: AppStyles.foregroundColorBlack,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onPressed: () async {
                setState(() {
                  isNightModeAnabled = !isNightModeAnabled;
                });
              },
              child: isNightModeAnabled
                  ? const Icon(Icons.nightlight_outlined)
                  : const Icon(Icons.nightlight_rounded),
            ),
          ),
          Positioned(
            bottom: 400.0,
            right: 5,
            child: FloatingActionButton.small(
              backgroundColor: AppStyles.backgroundColorWhite,
              foregroundColor: AppStyles.foregroundColorBlack,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onPressed: () async {
                await _mapController.moveCamera(CameraUpdate.zoomIn());
              },
              child: const Icon(Icons.add),
            ),
          ),
          Positioned(
            bottom: 350.0,
            right: 5,
            child: FloatingActionButton.small(
              backgroundColor: AppStyles.backgroundColorWhite,
              foregroundColor: AppStyles.foregroundColorBlack,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onPressed: () async {
                await _mapController.moveCamera(CameraUpdate.zoomOut());
              },
              child: const Icon(Icons.remove),
            ),
          ),
          mapTapped
              ? Positioned(
                  bottom: 42.5,
                  right: MediaQuery.of(context).size.width / 3,
                  child: SizedBox(
                    width: 140,
                    height: 50,
                    child: FloatingActionButton(
                      backgroundColor: AppStyles.backgroundColorGreen700,
                      foregroundColor: AppStyles.foregroundColorYellow,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      onPressed: () async {
                        await onTanlashButtonPressed();
                      },
                      child: const Text('Tanlash'),
                    ),
                  ),
                )
              : Container(),
          Positioned(
            bottom: 40.0,
            right: 5,
            child: FloatingActionButton(
              tooltip: 'Your location',
              onPressed: () async {
                await _mapController.moveCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: initialPosition,
                        zoom: 13,
                      ),
                    ),
                    animation: const MapAnimation(
                        type: MapAnimationType.linear, duration: 0.6));

                // final locationPermissionIsGranted =
                //     await Permission.location.request().isGranted;

                // if (locationPermissionIsGranted) {
                //   await _mapController.toggleUserLayer(
                //       visible: true, autoZoomEnabled: true);
                // } else {
                //   WidgetsBinding.instance.addPostFrameCallback((_) {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content: Text('No access to user location'),
                //       ),
                //     );
                //   });
                // }
              },
              backgroundColor: AppStyles.backgroundColorGreen700,
              foregroundColor: AppStyles.foregroundColorYellow,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          IgnorePointer(
            ignoring: !isSearchMode,
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  isSearchMode = !isSearchMode;
                });
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          isTyping && searchController.text.isNotEmpty
              ? Positioned(
                  top: 0,
                  width: MediaQuery.of(context).size.width,
                  height: listViewHeight,
                  child: isNotFound
                      ? Container(
                          color: AppStyles.backgroundColorWhite,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Bunday masjid mavjud emas!',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Container(
                          color: AppStyles.backgroundColorWhite,
                          child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                  horizontalTitleGap: 3.0,
                                  title: Text(items[index].name),
                                  leading: const Icon(
                                    Icons.location_on_sharp,
                                    size: 32,
                                  ),
                                  onTap: () => cameraMover(
                                      items[index].latitude,
                                      items[index].longitude));
                            },
                          ),
                        ))
              : Container(),
          isMapLoading
              ? const Positioned.fill(
                  child: Center(
                  child: CircularProgressIndicator.adaptive(),
                ))
              : Container(),
        ],
      ),
    );
  }

  Future<void> cameraMover(double latitude, double longitude) async {
    final Point point = Point(latitude: latitude, longitude: longitude);
    await _mapController.moveCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: point)),
    );
    setState(() {
      isTyping = false;
      isSearchMode = false;
    });
    await _initLocationLayer();
  }

  void addMark({required Point point}) {
    newMasjidPoint = point;
    final myLocationMarker = PlacemarkMapObject(
      isDraggable: true,
      opacity: 1,
      mapId: const MapObjectId('currentLocation'),
      point: point,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage(
            'assets/mosque.png',
          ),
          scale: 0.35,
        ),
      ),
    );
    mapObject.add(myLocationMarker);
  }

  Future<void> onTanlashButtonPressed() async {
    // Check if newMasjidPoint is not null
    if (newMasjidPoint != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddMasjidView(
            newMasjidPoint: newMasjidPoint,
            onLocationLayerInit: onLocationLayerInit,
          ),
        ),
      );
    }
  }
}
