import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

const geocodeUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
const trailerStr = '.json?access_token=';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoChecker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'GeoChecker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _usePlatformInstance = true;
  Position? _position;
  bool _serviceEnabled = false;
  LocationSettings? _locationSettings;
  StreamSubscription<Position>? _streamSubscription;
  bool _replace = false;
  double _oldAccuracy = 0;
  double _movingDistance = 0;
  double _movingPeriod = 0;
  String _location = '';
  bool _geoDecoder = true;
  double _refreshRate = 0;
  double _gpsSpeed = 0;

  @override
  void initState() {
    _locationSettings = defaultTargetPlatform == TargetPlatform.android
        ? _getAndroidLocationSettings()
        : _getAppleLocationSettings();
    super.initState();
  }

  void _geolocatorEnable() async {
    if (!await _checkSystemLocationSettings()) return;
    _serviceEnabled = !_serviceEnabled;

    if (_serviceEnabled) {
      final positionStream = _usePlatformInstance
          ? GeolocatorPlatform.instance
              .getPositionStream(locationSettings: _locationSettings)
          : Geolocator.getPositionStream(locationSettings: _locationSettings);
      _streamSubscription = positionStream.handleError((error) {
        print(error);
      }).listen((event) async {
        print(event.toJson());

        double speed = _gpsSpeed = (event.speed * 10).roundToDouble() / 10.0;
        double heading = event.heading;

        if (_position != null) {
          _oldAccuracy = _position!.accuracy;

          double updatePeriod = event.timestamp!
                  .difference(_position!.timestamp!)
                  .abs()
                  .inMicroseconds /
              Duration.microsecondsPerSecond;
          _refreshRate = 1 / updatePeriod;

          if (event.speed < 0 && updatePeriod < 2) {
            return;
          } else {
            if ((event.accuracy > _position!.accuracy ||
                    event.accuracy > 200) &&
                speed <= 0) {
              heading = Geolocator.bearingBetween(_position!.latitude,
                  _position!.longitude, event.latitude, event.longitude);

              double positionDistance = Geolocator.distanceBetween(
                  _position!.latitude,
                  _position!.longitude,
                  event.latitude,
                  event.longitude);

              if ((positionDistance * 10 / event.accuracy).round() > 0) {
                positionDistance = positionDistance / event.accuracy;
              }

              if (_movingDistance == 0) {
                _movingDistance += positionDistance;
                _movingPeriod += updatePeriod;
              } else {
                _movingDistance += positionDistance;
                _movingPeriod += updatePeriod;
                speed = _movingDistance / _movingPeriod;
              }

              _replace = true;

              print('Replace speed ($speed) and heading ($heading).');
            } else {
              _replace = false;
              _movingDistance = 0;
              _movingPeriod = 0;
            }
          }
        }

        if (_geoDecoder) {
          final response = await http.get(Uri.parse(
              '$geocodeUrl/${event.longitude},${event.latitude}$trailerStr'));

          if (response.statusCode == 200) {
            try {
              var geodata = jsonDecode(response.body);
              // print(geodata);
              _location = geodata['features'][0]['properties']['address'];
            } catch (_) {
              try {
                var geodata = jsonDecode(response.body);
                _location = geodata['features'][0]['text'];
              } catch (_) {}
            }
          }
        }

        if (speed < 0) {
          _replace = true;
        }

        _position = Position(
            longitude: event.longitude,
            latitude: event.latitude,
            timestamp: event.timestamp,
            accuracy: event.accuracy,
            altitude: event.altitude,
            heading: heading < 0 && speed < 0 ? 0 : (heading + 360) % 360,
            speed: speed < 0 ? 0 : speed,
            speedAccuracy: event.accuracy,
            floor: event.floor,
            isMocked: event.isMocked);

        setState(() {});
      });
    } else {
      _streamSubscription?.cancel();
      _position = null;
      _replace = false;
      _movingDistance = 0;
      _movingPeriod = 0;
      _oldAccuracy = 0;
      _refreshRate = 0;
      _gpsSpeed = 0;
      _location = '';
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.title),
        leading: Switch(
            value: _geoDecoder,
            onChanged: ((value) {
              setState(() {
                _geoDecoder = value;
              });
            })),
        actions: [
          Switch(
              value: _usePlatformInstance,
              onChanged: (value) {
                if (_serviceEnabled) {
                  _streamSubscription?.cancel();
                  _serviceEnabled = !_serviceEnabled;
                  setState(() {});
                }
                setState(() {
                  _usePlatformInstance = value;
                });
              })
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  'Latitude',
                  style: Theme.of(context)
                      .textTheme
                      .headline5
                      ?.copyWith(color: Colors.black54),
                ),
                Text(
                  'Longitude',
                  style: Theme.of(context)
                      .textTheme
                      .headline5
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  '${_position?.latitude.toStringAsFixed(7) ?? 0}',
                  style: Theme.of(context)
                      .textTheme
                      .headline6
                      ?.copyWith(color: Colors.black54),
                ),
                Text(
                  '${_position?.longitude.toStringAsFixed(7) ?? 0}',
                  style: Theme.of(context)
                      .textTheme
                      .headline6
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
            Text(
              _location.isEmpty ? '' : '$_location付近',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.black45),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              'Speed: ${((_position?.speed ?? 0) * 3.6).round()} (${(_gpsSpeed * 3.6).round()}) km/h',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: _replace ? Colors.red : Colors.blue),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Heading: ',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: _replace ? Colors.red : Colors.blue),
                ),
                Transform.rotate(
                  angle: (_position?.heading ?? 0) * pi / 180,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: const EdgeInsets.all(0.0),
                      icon: Icon(
                        Icons.navigation,
                        color: _replace ? Colors.red : Colors.blue,
                        size: 36,
                      ),
                      onPressed: null,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'GPS data /',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.blue),
                ),
                Text(
                  '/ Calculated result',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.red),
                ),
              ],
            ),
            Text(
              'Moving distance: ${_movingDistance.round()} m',
              style: Theme.of(context).textTheme.headline6?.copyWith(
                  color: _movingDistance < 100 ? Colors.black54 : Colors.red),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              'Accuracy: ${_oldAccuracy.toStringAsFixed(2)} -> ${_position?.accuracy.toStringAsFixed(2) ?? 0.toStringAsFixed(2)} m',
              style: Theme.of(context).textTheme.headline6?.copyWith(
                  color: _oldAccuracy < (_position?.accuracy ?? 0)
                      ? Colors.red
                      : Colors.green),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Accuracy better /',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.green),
                ),
                Text(
                  '/ Accuracy wrorse',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.red),
                ),
              ],
            ),
            Text(
              'Last update: ${DateFormat("HH:mm:ss").format(_position?.timestamp?.toLocal() ?? DateTime(0))} @${_refreshRate.toStringAsFixed(3)}Hz',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: !_serviceEnabled ? Colors.green : Colors.red,
        onPressed: _geolocatorEnable,
        child: const Icon(Icons.gps_fixed),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  /// Androidの位置情報設定を取得する。
  LocationSettings _getAndroidLocationSettings() {
    return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: null,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Need GPS permission',
          notificationTitle: 'Permission Required',
          enableWakeLock: false,
        ));
  }

  /// iOSの位置情報設定を取得する。
  LocationSettings _getAppleLocationSettings() {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: 10,
      pauseLocationUpdatesAutomatically: false,
      // Only set to true if our app will be started up in the background.
      showBackgroundLocationIndicator: true,
    );
  }

  Future<bool> _checkSystemLocationSettings() async {
    final isLocationServiceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      return false;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    return true;
  }
}
