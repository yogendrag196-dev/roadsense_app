import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roadsense_app/core/theme.dart';
import 'package:roadsense_app/core/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppTheme defines consistent palettes for light and dark modes', () {
    expect(AppTheme.primaryTeal, const Color(0xFF0E7C7B));
    expect(AppTheme.secondaryAmber, const Color(0xFFD98E04));
    expect(AppTheme.dangerousRed, const Color(0xFFD32F2F));

    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(AppTheme.lightTheme.brightness, Brightness.light);
  });

  test('ThemeModeNotifier cycle order transitions smoothly', () async {
    final notifier = ThemeModeNotifier();
    expect(notifier.state, ThemeMode.dark);

    await notifier.setThemeMode(ThemeMode.light);
    expect(notifier.state, ThemeMode.light);

    await notifier.toggleTheme();
    expect(notifier.state, ThemeMode.dark);

    await notifier.toggleTheme();
    expect(notifier.state, ThemeMode.light);
  });

  testWidgets('Theme adaptive colors resolve accurately in context', (tester) async {
    Color? resolvedDarkCard;
    Color? resolvedLightCard;

    await tester.pumpWidget(
      Theme(
        data: AppTheme.lightTheme,
        child: Builder(
          builder: (context) {
            resolvedLightCard = AppTheme.getCardColor(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolvedLightCard, AppTheme.lightCardColor);

    await tester.pumpWidget(
      Theme(
        data: AppTheme.darkTheme,
        child: Builder(
          builder: (context) {
            resolvedDarkCard = AppTheme.getCardColor(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolvedDarkCard, AppTheme.darkCardColor);
  });
}
