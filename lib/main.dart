import 'package:flutter/material.dart';
import 'screens/generator_screen.dart';
import 'screens/history_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  runApp(const GiftCertApp());
}

class GiftCertApp extends StatelessWidget {
  const GiftCertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Сертификат',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF2C1A0E),
          onPrimary: Color(0xFFF5EFE7),
          secondary: Color(0xFFC8A97E),
          onSecondary: Color(0xFF2C1A0E),
          error: Color(0xFFB00020),
          onError: Colors.white,
          surface: Color(0xFFF5EFE7),
          onSurface: Color(0xFF2C1A0E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5EFE7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C1A0E),
          foregroundColor: Color(0xFFC8A97E),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 20,
            color: Color(0xFFC8A97E),
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFAF6F1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4C5B0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4C5B0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC8A97E), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF7A6152), fontFamily: 'Montserrat'),
          hintStyle: const TextStyle(color: Color(0xFFBBAAA0), fontFamily: 'Montserrat'),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C1A0E),
            foregroundColor: const Color(0xFFC8A97E),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontFamily: 'PlayfairDisplay', color: Color(0xFF2C1A0E)),
          titleLarge: TextStyle(fontFamily: 'PlayfairDisplay', color: Color(0xFF2C1A0E)),
          titleMedium: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF2C1A0E)),
          bodyMedium: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF4A3A2B)),
          bodySmall: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF7A6152)),
        ),
        useMaterial3: true,
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    GeneratorScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF2C1A0E),
        indicatorColor: const Color(0xFFC8A97E).withOpacity(0.25),
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined, color: Color(0xFF8C7560)),
            selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFFC8A97E)),
            label: 'Создать',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, color: Color(0xFF8C7560)),
            selectedIcon: Icon(Icons.history, color: Color(0xFFC8A97E)),
            label: 'История',
          ),
        ],
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
