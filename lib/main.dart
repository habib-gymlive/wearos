import 'package:flutter/material.dart';
import 'dart:async';

import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import 'package:workout/workout.dart';

void main() => runApp(const WearSenderApp());

class WearSenderApp extends StatefulWidget {
  const WearSenderApp({Key? key}) : super(key: key);

  @override
  State<WearSenderApp> createState() => _WearSenderAppState();
}

class _WearSenderAppState extends State<WearSenderApp> {
  final _watch = WatchConnectivity();
  final _workout = Workout();

  var _isWorkoutActive = false;
  var _heartRate = 0.0;
  // var _calories = 0.0;
  StreamSubscription? _workoutSubscription;
  StreamSubscription? _deviceCommandSubscription;
  int? remainingRounds;

  @override
  void initState() {
    super.initState();

    _deviceCommandSubscription = _watch.messageStream.listen((event) {
      debugPrint('Received message: $event');
      final command = event['type'] as String;
      if (command == 'start_streaming') {
        remainingRounds = event['rounds'] as int?;
        startStreaming();
      } else if (command == 'end_streaming') {
        endStreaming();
      }
    });
  }

  void startStreaming() async {
    if (!_isWorkoutActive) {
      WakelockPlus.enable();
      await _workout.start(
        exerciseType: ExerciseType.running,
        features: [WorkoutFeature.heartRate, WorkoutFeature.calories],
      );
      _workoutSubscription = _workout.stream.listen((event) {
        if (event.feature == WorkoutFeature.heartRate) {
          setState(() {
            _heartRate = event.value;
          });
          _watch.updateApplicationContext({
            'type': 'heart_rate',
            'data': event.value.toInt(),
          });
        }
        //  else if (event.feature == WorkoutFeature.calories) {
        //   setState(() {
        //     _calories = event.value;
        //   });
        //   _watch.updateApplicationContext({
        //     'type': 'calories',
        //     'data': event.value.toInt(),
        //   });
        // }
      });
      setState(() {
        _isWorkoutActive = true;
      });
    }
  }

  void endStreaming() async {
    if (_isWorkoutActive) {
      WakelockPlus.disable();
      await _workout.stop();
      _workoutSubscription?.cancel();
      setState(() {
        _isWorkoutActive = false;
        _heartRate = 0;
        // _calories = 0;
      });
    }
  }

  @override
  void dispose() {
    _workoutSubscription?.cancel();
    _workout.stop();
    _deviceCommandSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.red)),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    child: Text(
                      _isWorkoutActive
                          ? 'Workout Started'
                          : 'Workout Not Started',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  Text(
                    'Current Stats',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white54),
                  ),
                  Text(
                    '${_heartRate.toStringAsFixed(0)} BPM',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  if (remainingRounds != null &&
                      remainingRounds! >= 0 &&
                      _isWorkoutActive) ...[
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          remainingRounds = remainingRounds! - 1;
                        });
                        _watch.sendMessage({'type': 'next_round'});
                      },
                      child: remainingRounds == 0
                          ? Text('Finish Workout')
                          : Text('Next Round'),
                    ),
                    if (remainingRounds! > 0 && _isWorkoutActive)
                      Text(
                        'Remaining rounds: ${remainingRounds!}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
