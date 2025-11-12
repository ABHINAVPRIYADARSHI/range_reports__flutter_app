import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboards/range_dashboard.dart';
import 'screens/reports/daily_report_form.dart';

class Routes {
  static const String login = '/';
  static const String register = '/register';
  static const String home = '/home';
  static const String rangeDashboard = '/dash/range';
  static const String reportForm = '/report/form';

  static final Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    home: (_) => const HomeScreen(),
    rangeDashboard: (_) => const RangeDashboard(),
    reportForm: (_) => const DailyReportFormScreen(),
  };
}
