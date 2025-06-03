// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'auth_screen.dart'; // فقط برای مثال اگر بخواهیم در صورت لاگین بودن مستقیم به صفحه اصلی برویم

// کلید برای ذخیره انتخاب تم
const String themePrefKey = 'app_theme_mode_v1';

// ValueNotifier برای مدیریت تم به صورت سراسری
// (در یک پروژه بزرگتر، این می‌تواند با Provider یا Riverpod مدیریت شود)
final ValueNotifier<ThemeMode> activeThemeMode = ValueNotifier(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // خواندن تم ذخیره شده قبل از اجرای اپ
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedTheme = prefs.getString(themePrefKey);
    if (savedTheme == 'light') {
      activeThemeMode.value = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      activeThemeMode.value = ThemeMode.dark;
    } else {
      activeThemeMode.value = ThemeMode.system; // پیش‌فرض
    }
  } catch (e) {
    print("Error loading theme preference: $e");
    activeThemeMode.value = ThemeMode.system; // در صورت خطا، پیش‌فرض
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // گوش دادن به تغییرات activeThemeMode برای بازسازی MaterialApp در صورت نیاز
    activeThemeMode.addListener(_onThemeModeChanged);
  }

  @override
  void dispose() {
    activeThemeMode.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  void _onThemeModeChanged() {
    if (mounted) {
      setState(() {
        // فقط برای اینکه ویجت بازسازی شود و ThemeMode جدید را از ValueNotifier بگیرد
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // تعریف رنگ‌های پالت شما (مشابه قبل)
    const Color palettePrimary = Color(0xFFBBBDF6);
    const Color paletteSecondary = Color(0xFF9893DA);
    const Color paletteMutedBlueGrey = Color(0xFF797A9E);

    // رنگ‌های پایه تم تیره (مشابه قبل)
    const Color darkBackground = Color(0xFF121212);
    const Color darkSurface = Color(0xFF1E1E1E);
    const Color darkSurfaceVariant = Color(0xFF2C2C2C);
    const Color textOnDark = Colors.white;
    const Color textOnPalettePrimaryDark = darkBackground;

    // تعریف رنگ‌های پایه تم روشن (مثال ساده)
    const Color lightBackground = Color(0xFFF5F5F5); // سفید مایل به خاکستری
    const Color lightSurface = Colors.white;
    const Color lightSurfaceVariant = Color(0xFFEEEEEE); // کمی تیره‌تر از سطح
    const Color textOnLight = Colors.black87;
    const Color textOnPalettePrimaryLight = Colors.white;


    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        primary: palettePrimary,
        onPrimary: textOnPalettePrimaryDark,
        secondary: paletteSecondary,
        onSecondary: textOnPalettePrimaryDark,
        background: darkBackground,
        onBackground: textOnDark,
        surface: darkSurface,
        onSurface: textOnDark,
        error: Colors.redAccent[100]!,
        onError: Colors.black,
        brightness: Brightness.dark,
        surfaceVariant: darkSurfaceVariant,
        onSurfaceVariant: textOnDark.withOpacity(0.8),
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: textOnDark.withOpacity(0.9)),
        titleTextStyle: TextStyle(
          color: textOnDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1.0,
        color: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palettePrimary,
          foregroundColor: textOnPalettePrimaryDark,
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant.withOpacity(0.7),
        hintStyle: TextStyle(color: textOnDark.withOpacity(0.5)),
        labelStyle: TextStyle(color: textOnDark.withOpacity(0.7)),
        prefixIconColor: textOnDark.withOpacity(0.6),
        suffixIconColor: textOnDark.withOpacity(0.6),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 18.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: darkSurface.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: darkSurface.withOpacity(0.8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: palettePrimary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.redAccent[100]!, width: 1.0)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.redAccent[100]!, width: 1.5)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: paletteSecondary,
          textStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkBackground,
        selectedItemColor: palettePrimary,
        unselectedItemColor: textOnDark.withOpacity(0.7),
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textOnDark, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textOnDark, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: textOnDark, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: textOnDark, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textOnDark, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: textOnDark, fontWeight: FontWeight.bold, fontSize: 22),
        titleLarge: TextStyle(color: textOnDark, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(color: textOnDark.withOpacity(0.95), fontWeight: FontWeight.w500, fontSize: 16),
        titleSmall: TextStyle(color: textOnDark.withOpacity(0.9), fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: TextStyle(color: textOnDark.withOpacity(0.9), fontSize: 16),
        bodyMedium: TextStyle(color: textOnDark.withOpacity(0.87), fontSize: 14),
        bodySmall: TextStyle(color: textOnDark.withOpacity(0.75), fontSize: 12),
        labelLarge: TextStyle(color: textOnPalettePrimaryDark, fontWeight: FontWeight.bold, fontSize: 16),
      ).apply(bodyColor: textOnDark.withOpacity(0.87), displayColor: textOnDark),
      iconTheme: IconThemeData(color: textOnDark.withOpacity(0.87)),
      dividerTheme: DividerThemeData(color: textOnDark.withOpacity(0.12), thickness: 0.8),
      sliderTheme: SliderThemeData(
          activeTrackColor: palettePrimary,
          inactiveTrackColor: textOnDark.withOpacity(0.2),
          thumbColor: palettePrimary,
          overlayColor: palettePrimary.withAlpha(40),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0, elevation: 2.0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
          trackHeight: 3.5),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        titleTextStyle: TextStyle(color: textOnDark, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: TextStyle(color: textOnDark.withOpacity(0.87), fontSize: 15),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: paletteMutedBlueGrey.withOpacity(0.9), borderRadius: BorderRadius.circular(5)),
        textStyle: TextStyle(color: textOnDark, fontSize: 12),
        preferBelow: false,
      ),
    );

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        primary: palettePrimary, // می‌توانید برای تم روشن رنگ primary متفاوتی تعریف کنید
        onPrimary: textOnPalettePrimaryLight,
        secondary: paletteSecondary,
        onSecondary: textOnPalettePrimaryLight,
        background: lightBackground,
        onBackground: textOnLight,
        surface: lightSurface,
        onSurface: textOnLight,
        error: Colors.red.shade700,
        onError: Colors.white,
        brightness: Brightness.light,
        surfaceVariant: lightSurfaceVariant,
        onSurfaceVariant: textOnLight.withOpacity(0.7),
      ),
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface, // یا lightBackground
        elevation: 0.5, // سایه ملایم برای تم روشن
        iconTheme: IconThemeData(color: textOnLight.withOpacity(0.8)),
        titleTextStyle: TextStyle(
          color: textOnLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1.0,
        color: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palettePrimary, // رنگ دکمه مشابه تم تیره
          foregroundColor: textOnPalettePrimaryLight,
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceVariant.withOpacity(0.8),
        hintStyle: TextStyle(color: textOnLight.withOpacity(0.5)),
        labelStyle: TextStyle(color: textOnLight.withOpacity(0.7)),
        prefixIconColor: textOnLight.withOpacity(0.6),
        suffixIconColor: textOnLight.withOpacity(0.6),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 18.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: lightSurface.withOpacity(0.6))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: palettePrimary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.red.shade700, width: 1.0)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.red.shade700, width: 1.5)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: paletteSecondary, // رنگ مشابه تم تیره
          textStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: palettePrimary,
        unselectedItemColor: textOnLight.withOpacity(0.6),
        elevation: 0.5,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textOnLight, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textOnLight, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: textOnLight, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: textOnLight, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textOnLight, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: textOnLight, fontWeight: FontWeight.bold, fontSize: 22),
        titleLarge: TextStyle(color: textOnLight, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(color: textOnLight.withOpacity(0.95), fontWeight: FontWeight.w500, fontSize: 16),
        titleSmall: TextStyle(color: textOnLight.withOpacity(0.9), fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: TextStyle(color: textOnLight.withOpacity(0.9), fontSize: 16),
        bodyMedium: TextStyle(color: textOnLight.withOpacity(0.87), fontSize: 14),
        bodySmall: TextStyle(color: textOnLight.withOpacity(0.75), fontSize: 12),
        labelLarge: TextStyle(color: textOnPalettePrimaryLight, fontWeight: FontWeight.bold, fontSize: 16),
      ).apply(bodyColor: textOnLight.withOpacity(0.87), displayColor: textOnLight),
      iconTheme: IconThemeData(color: textOnLight.withOpacity(0.87)),
      dividerTheme: DividerThemeData(color: textOnLight.withOpacity(0.12), thickness: 0.8),
      sliderTheme: SliderThemeData( // مشابه تم تیره، می‌توانید تنظیمات متفاوتی اعمال کنید
          activeTrackColor: palettePrimary,
          inactiveTrackColor: textOnLight.withOpacity(0.2),
          thumbColor: palettePrimary,
          overlayColor: palettePrimary.withAlpha(40),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0, elevation: 2.0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
          trackHeight: 3.5),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        titleTextStyle: TextStyle(color: textOnLight, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: TextStyle(color: textOnLight.withOpacity(0.87), fontSize: 15),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: Colors.grey.shade700.withOpacity(0.9), borderRadius: BorderRadius.circular(5)),
        textStyle: TextStyle(color: Colors.white, fontSize: 12),
        preferBelow: false,
      ),
    );

    return MaterialApp(
      title: 'Music Player',
      theme: lightTheme, // تم پیش‌فرض روشن
      darkTheme: darkTheme, // تم تیره
      themeMode: activeThemeMode.value, // استفاده از ValueNotifier برای تعیین تم
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      // اگر بخواهیم بر اساس لاگین بودن کاربر به صفحه خاصی برویم:
      // home: _prefs.getBool('isLoggedIn') == true ? const MainTabsScreen() : const AuthScreen(),
      // البته این نیاز به انتقال _prefs به اینجا یا روش دیگری برای دسترسی دارد.
    );
  }
}