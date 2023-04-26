import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

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
  bool _usePlatformInstance = false;
  Position? _position;
  bool _serviceEnabled = false;
  LocationSettings? _locationSettings;
  StreamSubscription<Position>? _streamSubscription;

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
      }).listen((event) {
        print(event.toJson());
        // 人工的に速度と方位を修正計算結果
        double speed = event.speed;
        double heading = event.heading;

        // 人工的に速度や方位を計算するため、前回の位置情報が必要です。
        //　精度を確認して、前の精度より高くの値で(Android)、また速度はマイナス(iOS)、精度悪くなった時、人工計算で修正する
        if (_position != null &&
            (event.accuracy > _position!.accuracy || event.speed < 0)) {
          // 新しい位置と前回の位置の距離
          var distance = Geolocator.distanceBetween(_position!.latitude,
              _position!.longitude, event.latitude, event.longitude);

          // 精度悪くなった時、移動距離10m不満、位置情報更新されない
          if (distance < event.accuracy || distance < 10) {
            speed = _position!.speed;
            heading = _position!.heading;
            print(
                'GPS signal might be lost, but moving distance is within accracy range, using artificial speed ($speed) and heading ($heading) from last time instead.');
          } else {
            // 新しい位置と前回の位置の経過時間
            var movingTimeInSeconds = event.timestamp!
                    .difference(_position!.timestamp!)
                    .inMilliseconds /
                Duration.millisecondsPerSecond;

            // 速度を計算する
            speed = distance / movingTimeInSeconds * 3.6;

            // 方位を計算する
            heading = Geolocator.bearingBetween(_position!.latitude,
                _position!.longitude, event.latitude, event.longitude);

            // 計算結果を確認し、不合理の結果を捨てて
            if (speed > _position!.speed) {
              speed = _position!.speed;
              heading = _position!.heading;
            }

            print(
                'GPS signal might be lost, using artificial calculation speed ($speed) and heading ($heading) instead.');
          }
        }

        _position = Position(
            longitude: event.longitude,
            latitude: event.latitude,
            timestamp: event.timestamp,
            accuracy: event.accuracy,
            altitude: event.altitude,
            heading: heading,
            speed: speed,
            speedAccuracy: event.accuracy,
            floor: event.floor,
            isMocked: event.isMocked);

        setState(() {});
      });
    } else {
      _streamSubscription?.cancel();
      _position = null;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Latitude: ${_position?.latitude.toStringAsFixed(4) ?? 0}',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Logitude: ${_position?.longitude.toStringAsFixed(4) ?? 0}',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Accuracy: ${_position?.accuracy.toStringAsFixed(2) ?? 0} m',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Speed: ${((_position?.speed ?? 0) * 3.6).floor()} Km',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Spead Accuracy: ${_position?.speedAccuracy.toStringAsFixed(2) ?? 0}',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Heading: ${_position?.heading.floor() ?? 0}',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Update Time: ${DateFormat("HH:mm:ss").format(_position?.timestamp?.toLocal() ?? DateTime.now())}',
              style: Theme.of(context).textTheme.headline5,
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
