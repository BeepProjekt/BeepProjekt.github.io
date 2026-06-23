import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'main.dart';
import 'models.dart';

enum ReactionState { initial, waiting, triggered, result, tooEarly }

class ReactionTestPage extends StatefulWidget {
  const ReactionTestPage({super.key});

  @override
  ReactionTestPageState createState() => ReactionTestPageState();
}

class ReactionTestPageState extends State<ReactionTestPage> {
  ReactionState _reactionState = ReactionState.initial;
  RangeValues _intervalRange = const RangeValues(1, 5);
  final Stopwatch _stopwatch = Stopwatch();
  int _reactionTime = 0;
  Timer? _timer;
  final Random _random = Random();
  final HistoryService _historyService = HistoryService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  void _startTest() {
    setState(() {
      _reactionState = ReactionState.waiting;
    });

    final min = _intervalRange.start * 1000;
    final max = _intervalRange.end * 1000;
    final randomDelay = min == max ? min : min + _random.nextInt((max - min).toInt());

    _timer = Timer(Duration(milliseconds: randomDelay.toInt()), () async {
      if (!mounted) return;
      final soundProvider = Provider.of<SoundProvider>(context, listen: false);
      final asset = soundProvider.reactionSoundAsset;
      if (asset != null) {
        await _audioPlayer.play(AssetSource(asset), mode: PlayerMode.lowLatency);
      }
      HapticFeedback.lightImpact();

      setState(() {
        _reactionState = ReactionState.triggered;
        _stopwatch.start();
      });
    });
  }

  void _onTap() {
    if (_reactionState == ReactionState.triggered) {
      _stopwatch.stop();
      _timer?.cancel();
      setState(() {
        _reactionTime = _stopwatch.elapsedMilliseconds;
        _reactionState = ReactionState.result;
        _historyService.addHistoryItem(HistoryItem(
          activityType: 'Reaction',
          dateTime: DateTime.now(),
          details: {'time': _reactionTime},
        ));
      });
      _stopwatch.reset();
    } else if (_reactionState == ReactionState.waiting) {
      _timer?.cancel();
      setState(() {
        _reactionState = ReactionState.tooEarly;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _reactionState = ReactionState.initial;
          });
        }
      });
    }
  }

  void _resetTest() {
    _timer?.cancel();
    _stopwatch.stop();
    _stopwatch.reset();
    setState(() {
      _reactionState = ReactionState.initial;
      _reactionTime = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content;

    switch (_reactionState) {
      case ReactionState.initial:
        content = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Interval: ${_intervalRange.start.toInt()} - ${_intervalRange.end.toInt()} seconds',
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
              onPressed: _startTest,
              child: const Text('START'),
            ),
          ],
        );
        break;
      case ReactionState.waiting:
        content = const Center(
          child: Text('Wait for the color change...'),
        );
        break;
      case ReactionState.triggered:
        content = Container();
        break;
      case ReactionState.result:
        content = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_reactionTime ms',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _resetTest,
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
        break;
      case ReactionState.tooEarly:
        content = const Center(
          child: Text(
            'TOO EARLY! - RESETTING',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        );
        break;
    }

    return GestureDetector(
      onTap: _onTap,
      child: Container(
        color: _reactionState == ReactionState.triggered
            ? theme.colorScheme.primary
            : theme.scaffoldBackgroundColor,
        child: content,
      ),
    );
  }
}
