import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'main.dart';
import 'models.dart';

enum TimerState { stopped, running, paused }

class BeepTimerPage extends StatefulWidget {
  const BeepTimerPage({super.key});

  @override
  BeepTimerPageState createState() => BeepTimerPageState();
}

class BeepTimerPageState extends State<BeepTimerPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  RangeValues _intervalRange = const RangeValues(1, 10);
  TimerState _timerState = TimerState.stopped;
  Timer? _timer;
  final Random _random = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _beepCount = 0;
  bool _isGoVisible = false;
  final HistoryService _historyService = HistoryService();

  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonAnimation;
  late AnimationController _circleAnimationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _buttonAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _circleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _buttonAnimationController.dispose();
    _circleAnimationController.dispose();
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_beepCount > 0) {
        _saveSession();
      }
    }
  }

  void _saveSession() {
    _historyService.addHistoryItem(
      HistoryItem(
        activityType: 'Beep Session',
        dateTime: DateTime.now(),
        details: {
          'totalBeeps': _beepCount,
          'intervalRange': '${_intervalRange.start.toInt()} - ${_intervalRange.end.toInt()} seconds',
        },
      ),
    );
  }

  void _start() {
    setState(() {
      _timerState = TimerState.running;
      if (_beepCount != 0 && _timerState == TimerState.stopped) {
        _beepCount = 0;
      }
    });
    _startTimer();
  }

  void _stop() {
    setState(() {
      _timerState = TimerState.paused;
      _timer?.cancel();
    });
  }
  
  void _resume() {
    setState(() {
      _timerState = TimerState.running;
    });
    _startTimer();
  }

  void _reset() {
    if (_beepCount > 0) {
      _saveSession();
    }
    _timer?.cancel();
    setState(() {
      _timerState = TimerState.stopped;
      _beepCount = 0;
    });
  }


  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(
      Duration(
        seconds:
            _random.nextInt(
              (_intervalRange.end - _intervalRange.start).toInt() + 1,
            ) +
            _intervalRange.start.toInt(),
      ),
      () {
        _beep();
        if (_timerState == TimerState.running) _startTimer();
      },
    );
  }

  void _beep() async {
    if (!mounted) return;
    setState(() {
      _beepCount++;
      _isGoVisible = true;
    });

    final soundProvider = Provider.of<SoundProvider>(context, listen: false);
    final asset = soundProvider.timerSoundAsset;
    if (asset != null) {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource(asset),
        mode: PlayerMode.lowLatency,
      );
    }

    HapticFeedback.lightImpact();
    _circleAnimationController.forward().then((_) {
      _circleAnimationController.reverse().then((_) {
        if(mounted){
          setState(() {
            _isGoVisible = false;
          });
        }
      });
    });
  }
  
  Widget _buildButtons() {
    switch (_timerState) {
      case TimerState.running:
        return ScaleTransition(
          scale: _buttonAnimation,
          child: ElevatedButton(
            onPressed: _stop,
            child: const Text('STOP'),
          ),
        );
      case TimerState.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _resume,
              child: const Text('RESUME'),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: _reset,
              child: const Text('RESET'),
            ),
          ],
        );
      case TimerState.stopped:
        return ElevatedButton(
          onPressed: _start,
          child: const Text('START'),
        );
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final circleAnimation = ColorTween(
      begin: theme.cardColor,
      end: theme.colorScheme.primary,
    ).animate(_circleAnimationController);

    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedBuilder(
              animation: circleAnimation,
              builder: (context, child) {
                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: circleAnimation.value,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: _isGoVisible
                        ? Text(
                            'GO!',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Beeps: $_beepCount',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text(
              'Interval Range: ${_intervalRange.start.toInt()} - ${_intervalRange.end.toInt()} seconds',
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
              onChanged: _timerState != TimerState.stopped
                  ? null
                  : (values) {
                      setState(() {
                        _intervalRange = values;
                      });
                    },
            ),
            const SizedBox(height: 30),
            _buildButtons(),
          ],
        ),
      );
  }
}
