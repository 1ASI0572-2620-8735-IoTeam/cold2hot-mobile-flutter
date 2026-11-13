import 'package:material_ui/material_ui.dart';
import '../../core/state/app_state.dart';
import '../delivery/active_delivery_screen.dart';
import '../history/history_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends StatefulWidget {
  final AppState appState;

  const HomeShell({super.key, required this.appState});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Regla del Cap. V: durante una entrega activa se oculta el BottomNavigationBar.
    if (widget.appState.currentOrder != null) {
      return ActiveDeliveryScreen(appState: widget.appState);
    }

    final s = widget.appState.strings;
    final titles = [s.ordersTitle, s.historyTitle, s.profileTitle];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tabIndex]),
        actions: [
          IconButton(
            tooltip: s.isEs ? 'Actualizar' : 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: widget.appState.loadOrders,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          OrdersScreen(appState: widget.appState),
          HistoryScreen(appState: widget.appState),
          ProfileScreen(appState: widget.appState),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping_rounded),
            label: s.navOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history_rounded),
            label: s.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: s.navProfile,
          ),
        ],
      ),
    );
  }
}
