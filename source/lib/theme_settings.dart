import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'main.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final List<Color> accentColors = [
      const Color(0xFF01FFAA),
      Colors.red,
      Colors.blue,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance & Themes')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Theme Mode',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: Text(
              'System Default',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            value: ThemeMode.system,
            groupValue: themeProvider.tacticalTheme != null ? null : themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeProvider.clearTacticalTheme();
                themeProvider.setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(
              'Light Mode',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            value: ThemeMode.light,
            groupValue: themeProvider.tacticalTheme != null ? null : themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeProvider.clearTacticalTheme();
                themeProvider.setThemeMode(value);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(
              'Dark Mode',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            value: ThemeMode.dark,
            groupValue: themeProvider.tacticalTheme != null ? null : themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                themeProvider.clearTacticalTheme();
                themeProvider.setThemeMode(value);
              }
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Tactical Themes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          ...tacticalThemes.map((theme) {
            return RadioListTile<TacticalTheme>(
              title: Text(
                theme.name,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              value: theme,
              groupValue: themeProvider.tacticalTheme,
              onChanged: (TacticalTheme? value) {
                if (value != null) {
                  themeProvider.setTacticalTheme(value);
                }
              },
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Accent Color',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => themeProvider.enableSystemAccent(),
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(
                      Icons.color_lens,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                ...accentColors.map((color) {
                  final isSelected =
                      !themeProvider.isSystemAccent &&
                      themeProvider.accentColor == color &&
                      themeProvider.tacticalTheme == null;
                  return GestureDetector(
                    onTap: () => themeProvider.setAccentColor(color),
                    child: CircleAvatar(
                      backgroundColor: color,
                      radius: 25,
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color:
                                  ThemeData.estimateBrightnessForColor(color) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
