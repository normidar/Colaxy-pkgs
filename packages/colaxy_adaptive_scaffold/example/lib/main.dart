import 'package:flutter/material.dart';
import 'package:colaxy_adaptive_scaffold/colaxy_adaptive_scaffold.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive Scaffold Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: AdaptiveScaffold(
        items: [
          NavigationItem(
            name: 'Home',
            icon: const Icon(Icons.home),
            page: const HomePage(),
          ),
          NavigationItem(
            name: 'Search',
            icon: const Icon(Icons.search),
            page: const SearchPage(),
          ),
          NavigationItem(
            name: 'Notifications',
            icon: const Icon(Icons.notifications),
            page: const NotificationsPage(),
          ),
          NavigationItem(
            name: 'Profile',
            icon: const Icon(Icons.person),
            page: const ProfilePage(),
          ),
          NavigationItem(
            name: 'Settings',
            icon: const Icon(Icons.settings),
            page: const SettingsPage(),
          ),
        ],
        initialIndex: 0,
        aspectRatioThreshold: 1.2,
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// Example pages
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home, size: 100, color: Colors.blue[300]),
          const SizedBox(height: 16),
          Text(
            'Home Page',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Welcome to the adaptive scaffold example!'),
        ],
      ),
    );
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 100, color: Colors.green[300]),
          const SizedBox(height: 16),
          Text(
            'Search Page',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Search for content here'),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 100, color: Colors.orange[300]),
          const SizedBox(height: 16),
          Text(
            'Profile Page',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('View your profile information'),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications, size: 100, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Notifications Page',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('View your notifications here'),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 100, color: Colors.purple[300]),
          const SizedBox(height: 16),
          Text(
            'Settings Page',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Configure your app settings'),
        ],
      ),
    );
  }
}
