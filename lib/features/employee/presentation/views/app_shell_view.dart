import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_bottom_nav_bar.dart';

class AppShellView extends StatefulWidget {
  final Widget homeView;
  final Widget activityView;
  final Widget attendanceView;
  final Widget sitesView;
  final Widget profileView;

  const AppShellView({
    super.key,
    required this.homeView,
    required this.activityView,
    required this.attendanceView,
    required this.sitesView,
    required this.profileView,
  });

  @override
  State<AppShellView> createState() => _AppShellViewState();
}

class _AppShellViewState extends State<AppShellView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      widget.homeView,
      widget.activityView,
      widget.attendanceView,
      widget.sitesView,
      widget.profileView,
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
