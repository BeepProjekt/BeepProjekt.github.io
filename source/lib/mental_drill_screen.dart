import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'main.dart';
import 'models.dart';

// MODIFIED: Added 'paused' state
enum DrillState { stopped, running, paused }

class MentalDrillPage extends StatefulWidget {
  const MentalDrillPage({super.key});

  @override
  State<MentalDrillPage> createState() => _MentalDrillPageState();
}

class _MentalDrillPageState extends State<MentalDrillPage>
    with WidgetsBindingObserver {
  DrillState _drillState = DrillState.stopped;
  RangeValues _intervalRange = const RangeValues(1, 10);
  int _difficulty = 1; // 1 to 4 digits
  Timer? _timer;
  final Random _random = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final HistoryService _historyService = HistoryService();

  String _question = '';
  String _answer = '';
  bool _showAnswer = false;
  int _drillCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_drillCount > 0) {
      _saveSession();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_drillState == DrillState.running) {
        // MODIFIED: Pause the drill instead of stopping it completely.
        _pauseDrill();
      }
    }
  }

  void _saveSession() {
    if (_drillCount == 0) return;
    _historyService.addHistoryItem(
      HistoryItem(
        activityType: 'Mental Drill',
        dateTime: DateTime.now(),
        details: {
          'totalQuestions': _drillCount,
          'intervalRange':
              '${_intervalRange.start.toInt()} - ${_intervalRange.end.toInt()} seconds',
          'difficulty': '$_difficulty Digits'
        },
      ),
    );
  }

  void _startDrill() {
    setState(() {
      _drillState = DrillState.running;
      _drillCount = 0;
      _showAnswer = false;
    });
    _generateProblem();
    _scheduleNextAnswer();
  }

  // ADDED: Pause functionality for the "STOP" button
  void _pauseDrill() {
    _timer?.cancel();
    setState(() {
      _drillState = DrillState.paused;
    });
  }

  // ADDED: Resume functionality for the "RESUME" button
  void _resumeDrill() {
    setState(() {
      _drillState = DrillState.running;
    });
    // The question is already on screen, just need to restart the timer to show the answer
    _scheduleNextAnswer();
  }
  
  // ADDED: Reset functionality for the "RESET" button
  void _resetDrill() {
    _timer?.cancel();
    _saveSession(); // Save progress before resetting
    setState(() {
      _drillState = DrillState.stopped;
      _question = '';
      _answer = '';
      _showAnswer = false;
      _drillCount = 0;
    });
  }

  void _generateProblem() {
    final operator = ['+', '-', '×', '÷'][_random.nextInt(4)];
    int max = pow(10, _difficulty).toInt();

    int num1 = 0, num2 = 0, answer = 0;

    switch (operator) {
      case '÷':
        answer = 2 + _random.nextInt((max / 2).floor() - 1);
        int maxDivisor = (max / answer).floor();
        if (maxDivisor > 1) {
          num2 = 2 + _random.nextInt(maxDivisor - 1);
        } else {
          num2 = 1;
        }
        num1 = answer * num2;
        break;
      case '×':
        if (_difficulty <= 2) {
          num1 = 2 + _random.nextInt((max / 2).floor());
          num2 = 2 + _random.nextInt((max / num1).floor());
        } else {
          num1 = 2 + _random.nextInt(max.floor());
          num2 = 2 + _random.nextInt(98); // Between 2 and 99
        }
        answer = num1 * num2;
        break;
      case '-':
        num1 = _random.nextInt(max) + 1;
        num2 = _random.nextInt(num1) + 1;
        answer = num1 - num2;
        break;
      case '+':
        num1 = _random.nextInt(max);
        num2 = _random.nextInt(max - num1);
        answer = num1 + num2;
        break;
    }

    setState(() {
      _question = '$num1 $operator $num2';
      _answer = answer.toString();
    });
  }

  void _scheduleNextAnswer() {
    _timer?.cancel();
    final delay =
        _random.nextInt((_intervalRange.end - _intervalRange.start).toInt() + 1) +
            _intervalRange.start.toInt();
    _timer = Timer(Duration(seconds: delay), () {
      _showTheAnswer();
    });
  }

  void _showTheAnswer() async {
    if (!mounted || _drillState != DrillState.running) return;

    final soundProvider = Provider.of<SoundProvider>(context, listen: false);
    final asset = soundProvider.timerSoundAsset;
    if (asset != null) {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(asset), mode: PlayerMode.lowLatency);
    }
    HapticFeedback.lightImpact();

    setState(() {
      _showAnswer = true;
      _drillCount++;
    });

    // Hide answer and show next question after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (_drillState == DrillState.running) {
        setState(() {
          _showAnswer = false;
        });
        _generateProblem();
        _scheduleNextAnswer();
      }
    });
  }
  
  // MODIFIED: Updated the control buttons based on the new states
  Widget _buildControls() {
    if (_drillState == DrillState.running) {
      return ElevatedButton(
        onPressed: _pauseDrill,
        child: const Text('STOP'),
      );
    } else if (_drillState == DrillState.paused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _resumeDrill,
            child: const Text('RESUME'),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: _resetDrill,
            child: const Text('RESET'),
          ),
        ],
      );
    } else { // Stopped
      return Column(
        children: [
          const Text('Difficulty (Digits)'),
          Slider(
            value: _difficulty.toDouble(),
            min: 1,
            max: 4,
            divisions: 3,
            label: _difficulty.toString(),
            onChanged: (value) {
              setState(() {
                _difficulty = value.round();
              });
            },
          ),
          Text(
            'Answer Interval: ${_intervalRange.start.toInt()} - ${_intervalRange.end.toInt()} seconds',
          ),
          RangeSlider(
            values: _intervalRange,
            min: 1,
            max: 60,
            divisions: 59,
            labels: RangeLabels(
              _intervalRange.start.round().toString(),
              _intervalRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() {
                _intervalRange = values;
              });
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _startDrill,
            child: const Text('START DRILL'),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // MODIFIED: Show the question even when paused
    final bool showQuestion = _drillState == DrillState.running || _drillState == DrillState.paused;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Questions: $_drillCount',
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onBackground),
            ),
            const SizedBox(height: 40),
            Container(
              height: 150,
              alignment: Alignment.center,
              child: showQuestion
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _question,
                          style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.onBackground),
                        ),
                        const SizedBox(height: 20),
                        if (_showAnswer)
                          Text(
                            '= $_answer',
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    )
                  : Text("Press 'Start Drill' to begin", style: TextStyle(color: theme.colorScheme.onBackground)),
            ),
            const SizedBox(height: 40),
            _buildControls(),
          ],
        ),
      ),
    );
  }
}
