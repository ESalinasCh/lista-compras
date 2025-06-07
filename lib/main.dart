import 'package:compras/splash_screen.dart';
import 'package:compras/ui/screens/chart_stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/providers/app_providers.dart';
import 'models/product.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/add_product_screen.dart';
import 'ui/screens/stats_screen.dart';
import 'ui/screens/detailed_stats_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);

  await Hive.initFlutter();
  Hive.registerAdapter(ProductAdapter());
  // Open the box for the active shopping list
  await Hive.openBox<Product>('products');
  // Open the box for the permanent purchase history
  await Hive.openBox<Product>('purchaseHistory');

  runApp(ProviderScope(child: CompraFacilApp()));
}

class CompraFacilApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CompraFácil',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (_) => SplashScreen(),
        '/home': (_) => HomeScreen(),
        '/add': (context) {
          final productToEdit =
              ModalRoute.of(context)?.settings.arguments as Product?;
          return AddProductScreen(productToEdit: productToEdit);
        },
        '/stats': (_) => StatsScreen(),
        '/detailed-stats': (_) => DetailedStatsScreen(),
        '/charts-stats': (_) => ChartsStatsScreen(),
      },
    );
  }
}
