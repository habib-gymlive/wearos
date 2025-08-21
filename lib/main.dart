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
  StreamSubscription? _deviceCommandSubscription;
  int? remainingRounds;

  @override
  void initState() {
    super.initState();
    _workout.stream
        .handleError((error) {
          debugPrint('error: $error');
        })
        .listen((event) {
          debugPrint('event: $event');
          if (event.feature == WorkoutFeature.heartRate) {
            setState(() {
              _heartRate = event.value;
            });
            _watch.sendMessage({
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
    _deviceCommandSubscription = _watch.messageStream.listen((event) {
      debugPrint('Received message: $event');
      final command = event['type'] as String;
      if (command == 'start_streaming') {
        startStreaming(event['rounds'] as int?);
      } else if (command == 'end_streaming') {
        endStreaming();
      }
    });
  }

  void startStreaming(int? rounds) async {
    if (!_isWorkoutActive) {
      try {
        setState(() {
          _isWorkoutActive = true;
          remainingRounds = rounds;
        });
        final supported = await _workout.getSupportedExerciseTypes();
        final preferred = [
          ExerciseType.exerciseClass,
          ExerciseType.workout,
          ExerciseType.walking,
          ExerciseType.running,
        ];
        final chosen = preferred.firstWhere(
          (t) => supported.contains(t),
          orElse: () =>
              supported.isNotEmpty ? supported.first : ExerciseType.workout,
        );
        await _workout.start(
          exerciseType: chosen,
          features: [WorkoutFeature.heartRate],
        );

        WakelockPlus.enable();
      } catch (e) {
        debugPrint('Error starting workout: $e');
        setState(() {
          _isWorkoutActive = false;
        });
      }
    }
  }

  void endStreaming() async {
    if (_isWorkoutActive) {
      print('endStreaming');
      WakelockPlus.disable();
      await _workout.stop();
      setState(() {
        _isWorkoutActive = false;
        _heartRate = 0;
        // _calories = 0;
      });
    }
  }

  @override
  void dispose() {
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
