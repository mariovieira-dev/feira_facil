import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_purchase_screen.dart';
import 'screens/shopping_list_screen.dart';
import 'screens/reports_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase com as opções padrão para a plataforma atual
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Carrega os dados de data/hora em português (necessário para o DateFormat 'pt_BR')
  await initializeDateFormatting('pt_BR', null);
  runApp(const FeiraFacilApp());
}

class FeiraFacilApp extends StatelessWidget {
  const FeiraFacilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final user = snapshot.data;

        return ChangeNotifierProvider(
          // Recria o provider (e o app todo) quando o usuário muda
          key: ValueKey(user?.uid ?? 'sem-login'),
          create: (_) {
            final provider = AppProvider();
            if (user != null) provider.initialize();
            return provider;
          },
          child: MaterialApp(
            title: 'Feira Fácil',
            debugShowCheckedModeBanner: false,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              // ... mantenha o seu tema exatamente como está
            ),
            home: user == null
                ? const LoginScreen()
                : const MainNavigationScreen(),
          ),
        );
      },
    );
  }
}
  

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = [
    const HomeScreen(),
    const NewPurchaseScreen(isTab: true),
    const ShoppingListScreen(),
    const ReportsScreen(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Início',
    ),
    NavigationDestination(
      icon: Icon(Icons.add_shopping_cart_outlined),
      selectedIcon: Icon(Icons.add_shopping_cart),
      label: 'Nova Compra',
    ),
    NavigationDestination(
      icon: Icon(Icons.list_alt_outlined),
      selectedIcon: Icon(Icons.list_alt),
      label: 'Lista',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Relatórios',
    ),
  ];

  void onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: _destinations,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
