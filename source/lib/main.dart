import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'timer_screen.dart';
import 'reaction_screen.dart';
import 'mental_drill_screen.dart';
import 'theme_settings.dart';
import 'agility_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  final soundProvider = SoundProvider();
  await soundProvider.loadSound();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => soundProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class HistoryService {
  static const _historyKey = 'history';

  Future<void> addHistoryItem(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.add(item);
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString(_historyKey);
    if (historyString == null) {
      return [];
    }
    final List<dynamic> historyJson = jsonDecode(historyString);
    return historyJson.map((json) => HistoryItem.fromJson(json)).toList();
  }

  Future<void> deleteHistoryItem(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.removeWhere(
      (h) => h.dateTime == item.dateTime && h.activityType == item.activityType,
    );
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  Future<void> deleteMultipleHistoryItems(List<HistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    for (var item in items) {
      history.removeWhere(
        (h) =>
            h.dateTime == item.dateTime && h.activityType == item.activityType,
      );
    }
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}

class SoundProvider extends ChangeNotifier {
  static const _soundKey = 'selected_sound';
  String _selectedSound = 'Default (Tactical)';
  final AudioPlayer _audioPlayer = AudioPlayer();

  String get selectedSound => _selectedSound;

  final Map<String, String> _soundMap = {
    'Default (Tactical)': 'classic.mp3',
    'Classic': 'classic.mp3',
    'Sharp': 'sharp.mp3',
    'Sonar': 'sonar.mp3',
    'Metal Strike': 'clang.mp3',
    'Commando': 'commando.mp3',
  };

  Future<void> setSound(String sound) async {
    _selectedSound = sound;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundKey, sound);
    notifyListeners();
    await playPreview();
  }

  String? get timerSoundAsset {
    if (_selectedSound == 'Silent') return null;
    if (_selectedSound == 'Default (Tactical)') return 'classic.mp3';
    return _soundMap[_selectedSound];
  }

  String? get reactionSoundAsset {
    if (_selectedSound == 'Silent') return null;
    if (_selectedSound == 'Default (Tactical)') return 'sharp.mp3';
    return _soundMap[_selectedSound];
  }

  Future<void> playPreview() async {
    final asset = _soundMap[_selectedSound];
    if (asset != null) {
      await _audioPlayer.play(AssetSource(asset), mode: PlayerMode.lowLatency);
    }
  }

  Future<void> loadSound() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedSound = prefs.getString(_soundKey) ?? 'Default (Tactical)';
    notifyListeners();
  }
}

class TacticalTheme {
  final String name;
  final Color backgroundColor;
  final Color accentColor;
  final Color surfaceColor;

  TacticalTheme({
    required this.name,
    required this.backgroundColor,
    required this.accentColor,
    required this.surfaceColor,
  });
}

final List<TacticalTheme> tacticalThemes = [
  TacticalTheme(
    name: 'Stealth',
    backgroundColor: Colors.black,
    accentColor: Colors.red.shade900,
    surfaceColor: const Color(0xFF1E1E1E),
  ),
  TacticalTheme(
    name: 'Desert',
    backgroundColor: const Color(0xFFC2B280),
    accentColor: const Color(0xFF4B3621),
    surfaceColor: const Color(0xFFE0D6B8),
  ),
  TacticalTheme(
    name: 'Urban',
    backgroundColor: const Color(0xFF424242),
    accentColor: const Color(0xFF90CAF9),
    surfaceColor: const Color(0xFF545454),
  ),
  TacticalTheme(
    name: 'High-Vis',
    backgroundColor: const Color(0xFF000000),
    surfaceColor: const Color(0xFF121212),
    accentColor: const Color(0xFFFFFF00),
  ),
  TacticalTheme(
    name: 'Cyber',
    backgroundColor: const Color(0xFF121212),
    accentColor: const Color.fromARGB(255, 0, 150, 62),
    surfaceColor: const Color(0xFF1E1E1E),
  ),
];

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFF01FFAA);
  TacticalTheme? _tacticalTheme;
  bool _isSystemAccent = false;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  TacticalTheme? get tacticalTheme => _tacticalTheme;
  bool get isSystemAccent => _isSystemAccent;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('themeMode') ?? 'system';
    if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    final colorVal = prefs.getInt('accentColor');
    if (colorVal != null) {
      _accentColor = Color(colorVal);
    }

    final themeName = prefs.getString('tacticalTheme');
    if (themeName != null) {
      _tacticalTheme = tacticalThemes.firstWhere(
        (t) => t.name == themeName,
        orElse: () => tacticalThemes.first,
      );
    }

    _isSystemAccent = prefs.getBool('isSystemAccent') ?? false;
    if (_isSystemAccent) {
      _tacticalTheme = null;
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _tacticalTheme = null; // Clear tactical theme when changing theme mode
    final prefs = await SharedPreferences.getInstance();
    String themeStr = 'system';
    if (mode == ThemeMode.dark) themeStr = 'dark';
    if (mode == ThemeMode.light) themeStr = 'light';
    await prefs.setString('themeMode', themeStr);
    await prefs.remove('tacticalTheme');
    notifyListeners();
  }

  void setAccentColor(Color color) async {
    _accentColor = color;
    _isSystemAccent = false;
    _tacticalTheme = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColor', color.value);
    await prefs.setBool('isSystemAccent', false);
    await prefs.remove('tacticalTheme');
    notifyListeners();
  }

  void enableSystemAccent() async {
    _isSystemAccent = true;
    _tacticalTheme = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSystemAccent', true);
    await prefs.remove('tacticalTheme');
    await prefs.remove('accentColor');
    notifyListeners();
  }

  void setTacticalTheme(TacticalTheme theme) async {
    _tacticalTheme = theme;
    _isSystemAccent = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tacticalTheme', theme.name);
    await prefs.setBool('isSystemAccent', false);
    notifyListeners();
  }

  void clearTacticalTheme() async {
    _tacticalTheme = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tacticalTheme');
    notifyListeners();
  }

  ThemeData getThemeData(BuildContext context,
      {ColorScheme? lightDynamic, ColorScheme? darkDynamic}) {
    if (_tacticalTheme != null) {
      final Color bg = _tacticalTheme!.backgroundColor;
      final Color surface = _tacticalTheme!.surfaceColor;
      final Color accent = _tacticalTheme!.accentColor;

      final bool isHighVis =
          _tacticalTheme!.name.toLowerCase().contains('high-vis') ||
              _tacticalTheme!.name.toLowerCase().contains('contrast');

      final Color effectiveOnBackground = isHighVis ? Colors.white : Colors.white;
      final Color effectiveOnPrimary = isHighVis ? Colors.black : Colors.black;

      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.dark(
          primary: accent,
          onPrimary: effectiveOnPrimary,
          secondary: accent,
          surface: surface,
          background: bg,
          onBackground: effectiveOnBackground,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: effectiveOnPrimary,
            minimumSize: const Size(160, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: const StadiumBorder(),
          ),
        ),
      );
    }

    final bool isDark;
    if (_themeMode == ThemeMode.system) {
      isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      isDark = _themeMode == ThemeMode.dark;
    }

    if (_isSystemAccent) {
      if (isDark && darkDynamic != null) {
        return _buildThemeFromColorScheme(darkDynamic);
      }
      if (!isDark && lightDynamic != null) {
        return _buildThemeFromColorScheme(lightDynamic);
      }
    }

    if (isDark) {
      final colorScheme = ColorScheme.dark(
        primary: accentColor,
        onPrimary: Colors.black,
        secondary: accentColor,
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
        onBackground: Colors.white,
      );
      return _buildThemeFromColorScheme(colorScheme);
    } else {
      final colorScheme = ColorScheme.light(
        primary: accentColor,
        onPrimary: Colors.white,
        secondary: accentColor,
        surface: Colors.white,
        background: const Color(0xFFF5F5F5),
        onBackground: Colors.black,
      );
      return _buildThemeFromColorScheme(colorScheme);
    }
  }

  ThemeData _buildThemeFromColorScheme(ColorScheme colorScheme) {
    return ThemeData(
      brightness: colorScheme.brightness,
      scaffoldBackgroundColor: colorScheme.background,
      colorScheme: colorScheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(160, 52),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final themeData = themeProvider.getThemeData(
              context,
              lightDynamic: lightDynamic,
              darkDynamic: darkDynamic,
            );

            return MaterialApp(
              title: 'Tactical Drill',
              theme: themeData,
              home: const MainNavigationPage(),
            );
          },
        );
      },
    );
  }
}

class MainNavigationPage extends StatelessWidget {
  const MainNavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Beep!'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.timer)),
              Tab(icon: Icon(Icons.bolt)),
              Tab(icon: Icon(Icons.calculate)),
              Tab(icon: Icon(Icons.open_with)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BeepTimerPage(),
            ReactionTestPage(),
            MentalDrillPage(),
            AgilityDrillPage(),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Appearance & Themes'),
            leading: const Icon(Icons.palette),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ThemeSettingsPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('View History'),
            leading: const Icon(Icons.history),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('App Sounds'),
            leading: const Icon(Icons.volume_up),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SoundSettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SoundSettingsPage extends StatelessWidget {
  const SoundSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final soundProvider = Provider.of<SoundProvider>(context);
    final soundOptions = [
      'Silent',
      'Default (Tactical)',
      'Classic',
      'Sharp',
      'Sonar',
      'Metal Strike',
      'Commando',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sound Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Sounds',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...soundOptions.map((sound) {
            return RadioListTile<String>(
              title: Text(sound),
              value: sound,
              groupValue: soundProvider.selectedSound,
              onChanged: (String? value) {
                if (value != null) {
                  soundProvider.setSound(value);
                }
              },
            );
          }),
        ],
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HistoryService _historyService = HistoryService();
  late Future<List<HistoryItem>> _historyFuture;
  bool _isMultiSelectMode = false;
  final Set<HistoryItem> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = _historyService.getHistory();
    });
  }

  void _clearHistory() async {
    await _historyService.clearHistory();
    _loadHistory();
  }

  void _deleteSelected() async {
    await _historyService.deleteMultipleHistoryItems(_selectedItems.toList());
    setState(() {
      _selectedItems.clear();
      _isMultiSelectMode = false;
    });
    _loadHistory();
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      _selectedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isMultiSelectMode ? '${_selectedItems.length} selected' : 'History',
        ),
        actions: [
          if (_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _clearHistory,
            ),
          IconButton(
            icon: Icon(_isMultiSelectMode ? Icons.cancel : Icons.select_all),
            onPressed: _toggleMultiSelectMode,
          ),
        ],
      ),
      body: FutureBuilder<List<HistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No history yet.'));
          }
          final history = snapshot.data!
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final isSelected = _selectedItems.contains(item);
              final formattedDate = DateFormat.yMMMd().add_jm().format(
                item.dateTime,
              );
              String subtitle;
              if (item.activityType == 'Reaction') {
                subtitle =
                    'Reaction: ${item.details['time']} ms\n$formattedDate';
              } else if (item.activityType == 'Mental Drill') {
                final difficulty = item.details['difficulty'] ?? 'N/A';
                subtitle =
                    '${item.details['totalQuestions']} questions, interval: ${item.details['intervalRange']}, difficulty: $difficulty\n$formattedDate';
              } else if (item.activityType == 'Agility Drill') {
                subtitle =
                    '${item.details['TotalCommands']} commands, interval: ${item.details['Interval']}\nDirections: ${item.details['Directions']}\n$formattedDate';
              } else {
                subtitle =
                    '${item.details['totalBeeps']} beeps, interval: ${item.details['intervalRange']}\n$formattedDate';
              }
              return ListTile(
                onTap: () {
                  if (_isMultiSelectMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedItems.remove(item);
                      } else {
                        _selectedItems.add(item);
                      }
                    });
                  }
                },
                onLongPress: () {
                  if (!_isMultiSelectMode) {
                    _toggleMultiSelectMode();
                    setState(() {
                      _selectedItems.add(item);
                    });
                  }
                },
                leading: _isMultiSelectMode
                    ? Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      )
                    : null,
                title: Text(item.activityType),
                subtitle: Text(subtitle),
                isThreeLine: true,
                trailing: !_isMultiSelectMode
                    ? IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await _historyService.deleteHistoryItem(item);
                          _loadHistory();
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
