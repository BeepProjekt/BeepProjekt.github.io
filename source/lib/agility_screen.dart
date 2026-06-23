import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'main.dart';

enum DrillState { stopped, running, paused }

class AgilityDrillPage extends StatefulWidget {
  const AgilityDrillPage({super.key});

  @override
  State<AgilityDrillPage> createState() => _AgilityDrillPageState();
}

class _AgilityDrillPageState extends State<AgilityDrillPage>
    with TickerProviderStateMixin {
  final HistoryService _historyService = HistoryService();
  DrillState _drillState = DrillState.stopped;
  RangeValues _intervalRange = const RangeValues(3, 8);
  final List<String> _directions = [
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SW',
    'W',
    'NW',
    'UP',
    'DOWN',
  ];
  final Set<String> _enabledDirections = {'N', 'E', 'S', 'W'};
  String? _currentDirection;
  int _commandCount = 0;
  final Random _random = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _drillTimer;
  Timer? _timer;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _displayTimer;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _drillTimer?.cancel();
    _displayTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String formatTime(int milliseconds) {
    final secs = milliseconds ~/ 1000;
    final minutes = (secs ~/ 60).toString().padLeft(2, '0');
    final seconds = (secs % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleDirection(String direction) {
    setState(() {
      if (_enabledDirections.contains(direction)) {
        if (_enabledDirections.length > 1) _enabledDirections.remove(direction);
      } else {
        _enabledDirections.add(direction);
      }
    });
  }

  void _saveSession() {
    if (_commandCount > 0 || _stopwatch.elapsedMilliseconds > 0) {
      final intervals = '${_intervalRange.start.toInt()}-${_intervalRange.end.toInt()}s';
      final directionsStr = _enabledDirections.join(', ');
      
      _historyService.addHistoryItem(
        HistoryItem(
          activityType: 'Agility Drill',
          dateTime: DateTime.now(),
          details: {
            'Interval': intervals,
            'Directions': directionsStr,
            'TotalCommands': _commandCount,
            'elapsedTime': formatTime(_stopwatch.elapsedMilliseconds),
          },
        ),
      );
    }
  }

  void _startDrill() {
    setState(() {
      _drillState = DrillState.running;
      _currentDirection = null; // Show READY first
    });
    _stopwatch.start();
    _startDisplayTimer();

    final randomInterval =
        _random.nextInt(
          _intervalRange.end.toInt() - _intervalRange.start.toInt() + 1,
        ) +
        _intervalRange.start.toInt();
    _drillTimer = Timer(Duration(seconds: randomInterval), _nextCommand);
  }

  void _pauseDrill() {
    _drillTimer?.cancel();
    _stopwatch.stop();
    _displayTimer?.cancel();
    setState(() {
      _drillState = DrillState.paused;
    });
  }

  void _resumeDrill() {
    setState(() {
      _drillState = DrillState.running;
      _currentDirection = null; // Show READY first
    });
    _stopwatch.start();
    _startDisplayTimer();

    final randomInterval =
        _random.nextInt(
          _intervalRange.end.toInt() - _intervalRange.start.toInt() + 1,
        ) +
        _intervalRange.start.toInt();
    _drillTimer = Timer(Duration(seconds: randomInterval), _nextCommand);
  }

  void _resetDrill() {
    _drillTimer?.cancel();
    _displayTimer?.cancel();
    _stopwatch.stop();
    _saveSession(); // Save metrics securely
    _stopwatch.reset();
    
    setState(() {
      _drillState = DrillState.stopped;
      _currentDirection = null;
      _commandCount = 0;
    });
  }

  void _startDisplayTimer() {
    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_stopwatch.isRunning) {
        setState(() {});
      }
    });
  }

  void _nextCommand() async {
    if (_drillState != DrillState.running) return;

    final directions = _enabledDirections.toList();
    if (directions.isEmpty) {
      _pauseDrill();
      return;
    }

    setState(() {
      _currentDirection = directions[_random.nextInt(directions.length)];
      _commandCount++;
    });

    // Correct audio mapping using the asset path helper from SoundProvider
    try {
      final soundProvider = Provider.of<SoundProvider>(context, listen: false);
      final assetFile = soundProvider.timerSoundAsset; // 👈 Extracts the exact '.mp3' file filename
      
      if (assetFile != null) {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource(assetFile));
      }
    } catch (e) {
      print("Error playing agility beep: $e");
    }

    // 1-second flash logic
    Timer(const Duration(seconds: 1), () {
      if (mounted && _drillState == DrillState.running) {
        setState(() {
          _currentDirection = null;
        });
      }
    });

    final randomInterval =
        _random.nextInt(
          _intervalRange.end.toInt() - _intervalRange.start.toInt() + 1,
        ) +
        _intervalRange.start.toInt();

    _drillTimer?.cancel();
    _drillTimer = Timer(Duration(seconds: randomInterval), _nextCommand);
  }

  Widget _buildButtons() {
    switch (_drillState) {
      case DrillState.running:
        return ElevatedButton(
          onPressed: _pauseDrill,
          child: const Text('STOP'),
        );
      case DrillState.paused:
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
      case DrillState.stopped:
        return ElevatedButton(
          onPressed: _startDrill,
          child: const Text('START'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_drillState == DrillState.stopped)
                  _buildSettings()
                else
                  _buildDrillView(),
                const SizedBox(height: 40),
                _buildButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrillView() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Commands: $_commandCount', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        Text(
          formatTime(_stopwatch.elapsedMilliseconds),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFeatures: [const FontFeature.tabularFigures()],
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 200,
          alignment: Alignment.center,
          child: _currentDirection != null
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    _currentDirection!,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              : const Text('READY', style: TextStyle(fontSize: 48)),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Interval: ${_intervalRange.start.toInt()} - ${_intervalRange.end.toInt()} seconds',
          style: theme.textTheme.titleLarge,
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
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: _directions.map((direction) {
            final isSelected = _enabledDirections.contains(direction);
            return FilterChip(
              label: Text(
                direction,
                style: TextStyle(
                  color: isSelected ? theme.colorScheme.onPrimary : null,
                ),
              ),
              selected: isSelected,
              onSelected: (bool selected) => _toggleDirection(direction),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: theme.colorScheme.primary,
              checkmarkColor: theme.colorScheme.onPrimary,
            );
          }).toList(),
        ),
      ],
    );
  }
}
