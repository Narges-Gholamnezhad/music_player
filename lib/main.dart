// lib/main.dart
import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // تعریف رنگ‌های پالت شما
    const Color palettePrimary = Color(0xFFBBBDF6);   // روشن‌ترین بنفش/آبی
    const Color paletteSecondary = Color(0xFF9893DA);  // بنفش/آبی روشن
    const Color paletteMutedBlueGrey = Color(0xFF797A9E);
    // const Color paletteDarkerGreyBlue = Color(0xFF72727E); // استفاده محدودتر
    // const Color paletteDarkestGreyPurple = Color(0xFF625F63); // استفاده محدودتر

    // تعریف رنگ‌های پایه تم تیره
    const Color darkBackground = Color(0xFF121212); // مشکی استاندارد متریال
    const Color darkSurface = Color(0xFF1E1E1E);    // سطح کمی روشن‌تر از پس‌زمینه
    const Color darkSurfaceVariant = Color(0xFF2C2C2C); // تنوع بیشتر برای سطوح

    // رنگ‌های متن و آیکون
    const Color textOnDark = Colors.white;           // متن سفید روی پس‌زمینه/سطوح تیره
    const Color textOnPalettePrimary = darkBackground; // متن تیره روی primary روشن
    const Color textOnPaletteSecondary = darkBackground;// متن تیره روی secondary روشن


    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme(
          primary: palettePrimary,
          onPrimary: textOnPalettePrimary,
          secondary: paletteSecondary,
          onSecondary: textOnPaletteSecondary,
          background: darkBackground,
          onBackground: textOnDark,
          surface: darkSurface,
          onSurface: textOnDark,
          error: Colors.redAccent[100]!, // قرمز روشن برای خطا روی تم تیره
          onError: Colors.black, // متن مشکی روی خطای روشن
          brightness: Brightness.dark,
          surfaceVariant: darkSurfaceVariant,
          onSurfaceVariant: textOnDark.withOpacity(0.8), // متن کمی کم‌رنگ‌تر روی surfaceVariant
        ),
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: darkBackground, // یا darkSurface برای کمی تمایز
          elevation: 0, // بدون سایه
          iconTheme: IconThemeData(color: textOnDark.withOpacity(0.9)),
          titleTextStyle: TextStyle(
            color: textOnDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1.0,
          color: darkSurface, // رنگ کارت‌ها
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: palettePrimary,
            foregroundColor: textOnPalettePrimary,
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            textStyle: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkSurfaceVariant.withOpacity(0.7), // رنگ داخل فیلدهای متنی
          hintStyle: TextStyle(color: textOnDark.withOpacity(0.5)),
          labelStyle: TextStyle(color: textOnDark.withOpacity(0.7)),
          prefixIconColor: textOnDark.withOpacity(0.6),
          suffixIconColor: textOnDark.withOpacity(0.6),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 16.0, horizontal: 18.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: darkSurface.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: darkSurface.withOpacity(0.8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: palettePrimary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.redAccent[100]!, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.redAccent[100]!, width: 1.5),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: paletteSecondary, // استفاده از رنگ ثانویه پالت شما
            textStyle:
            const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: darkBackground, // همرنگ AppBar
          selectedItemColor: palettePrimary,
          unselectedItemColor: textOnDark.withOpacity(0.7),
          elevation: 0,
          selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
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
          bodyMedium: TextStyle(color: textOnDark.withOpacity(0.87), fontSize: 14), // کمی روشن‌تر برای خوانایی بهتر
          bodySmall: TextStyle(color: textOnDark.withOpacity(0.75), fontSize: 12),
          labelLarge: TextStyle(color: textOnPalettePrimary, fontWeight: FontWeight.bold, fontSize: 16),
          labelMedium: TextStyle(color: textOnPalettePrimary.withOpacity(0.9)),
          labelSmall: TextStyle(color: textOnPalettePrimary.withOpacity(0.8)),
        ).apply(
          bodyColor: textOnDark.withOpacity(0.87),
          displayColor: textOnDark,
        ),
        iconTheme: IconThemeData(color: textOnDark.withOpacity(0.87)),
        dividerTheme: DividerThemeData(
            color: textOnDark.withOpacity(0.12), thickness: 0.8), // خط جداکننده خیلی کمرنگ
        sliderTheme: SliderThemeData(
            activeTrackColor: palettePrimary,
            inactiveTrackColor: textOnDark.withOpacity(0.2), // بسیار کمرنگ
            thumbColor: palettePrimary,
            overlayColor: palettePrimary.withAlpha(40), // شفافیت بیشتر برای overlay
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
          decoration: BoxDecoration(
            color: paletteMutedBlueGrey.withOpacity(0.9), // استفاده از یکی دیگر از رنگ‌های پالت شما
            borderRadius: BorderRadius.circular(5),
          ),
          textStyle: TextStyle(color: textOnDark, fontSize: 12), // متن روشن روی tooltip
          preferBelow: false,
        ),
        // اضافه کردن رنگ برای آیکون‌های خاص در صورت نیاز
        // chipTheme: ChipThemeData(
        //   backgroundColor: paletteMutedBlueGrey.withOpacity(0.3),
        //   selectedColor: paletteSecondary,
        //   labelStyle: TextStyle(color: textOnDark.withOpacity(0.8)),
        //   secondaryLabelStyle: TextStyle(color: textOnPaletteSecondary),
        //   iconTheme: IconThemeData(color: textOnDark.withOpacity(0.7))
        // )
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}