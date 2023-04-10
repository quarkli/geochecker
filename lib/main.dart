import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'GeoChecker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _usePlatformInstance = false;
  bool _replaceSpeed = false;
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
        if (_replaceSpeed &&
            _position != null &&
            (event.speed < 0 || event.heading < 0)) {
          double second = _calcDurationInSec(_position!, event);
          if (second < 1) {
            return;
          } else {
            _position = _replacedPosition(_position!, event);
          }
        } else {
          _position = event;
        }
        setState(() {});
      });
    } else {
      _streamSubscription?.cancel();
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        leading: Switch(
            value: _replaceSpeed,
            onChanged: ((value) {
              setState(() {
                _replaceSpeed = value;
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
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Latitude: ${_position?.latitude ?? 0}',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Logitude: ${_position?.longitude ?? 0}',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Accuracy: ${_position?.accuracy.floor() ?? 0} m',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Speed: ${((_position?.speed ?? 0) * 3.6).floor() ?? 0} Km',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Spead Accuracy: ${_position?.speedAccuracy ?? 0}',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Heading: ${_position?.heading.floor() ?? 0}',
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              'Update Time: ${(_position?.timestamp?.hour ?? 0) + 9}:${_position?.timestamp?.minute ?? 0}:${_position?.timestamp?.second ?? 0}',
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

  static Position _replacedPosition(Position last, Position current) {
    double second = _calcDurationInSec(last, current);
    double speed;
    if (current.speed < 0) {
      // 短期間に連続する場合は単純算出で1000km/hを超える値となるため制限
      speed = second > 3 ? _calcSpeed(last, current) : last.speed;
    } else {
      speed = current.speed;
    }

    double heading =
        current.heading < 0 ? _calcHeading(last, current) : current.heading;
    return Position(
        longitude: current.longitude,
        latitude: current.latitude,
        timestamp: current.timestamp,
        accuracy: current.accuracy,
        altitude: current.altitude,
        heading: heading,
        speed: speed,
        speedAccuracy: current.speedAccuracy,
        floor: current.floor,
        isMocked: current.isMocked);
  }

  static double _calcDurationInSec(Position start, Position end) {
    DateTime? from = start.timestamp;
    DateTime? to = end.timestamp;
    if (from != null && to != null) {
      int microSec = to.difference(from).inMicroseconds.abs();
      return microSec.toDouble() / Duration.microsecondsPerSecond;
    }

    return 0;
  }

  static double _calcSpeed(Position start, Position end) {
    double second = _calcDurationInSec(start, end);
    double meter = Geolocator.distanceBetween(
        start.latitude, start.longitude, end.latitude, end.longitude);
    return second > 0 ? meter.abs() / second : 0;
  }

  static double _calcHeading(Position start, Position end) {
    double bearing = Geolocator.bearingBetween(
        start.latitude, start.longitude, end.latitude, end.longitude);
    return bearing < 0 ? bearing + 360 : bearing;
  }
}
