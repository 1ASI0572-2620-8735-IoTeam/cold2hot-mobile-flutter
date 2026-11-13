import 'package:material_ui/material_ui.dart';
import '../../core/models/delivery_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/food_buddy_widget.dart';

/// M03 Lista de Pedidos Asignados con preview térmico y mascota alimentaria.
class OrdersScreen extends StatelessWidget {
  final AppState appState;

  const OrdersScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final s = appState.strings;
    final orders = appState.activeOrders;

    return RefreshIndicator(
      onRefresh: appState.loadOrders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _StatusBannerPill(
                online: appState.backendOnline,
                gpsOk: appState.permissions.allRequiredGranted,
                queueCount: appState.offlineQueue.pendingCount,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (appState.isLoading && orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (orders.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 42,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.ordersEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: appState.loadOrders,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(s.isEs ? 'Recargar envíos' : 'Reload orders'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: appState.createDemoOrder,
                      icon: const Icon(Icons.add_box_outlined),
                      label: Text(
                        s.isEs
                            ? 'Crear envío de prueba'
                            : 'Create sample shipment',
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final order in orders) ...[
              _OrderCard(
                order: order,
                language: appState.language,
                pendingLabel: s.ordersPendingTag,
                onTap: () => appState.openOrderDetail(order),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _StatusBannerPill extends StatelessWidget {
  final bool online;
  final bool gpsOk;
  final int queueCount;

  const _StatusBannerPill({
    required this.online,
    required this.gpsOk,
    required this.queueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: online ? AppColors.ok : AppColors.warn,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                online ? 'API Gateway conectado' : 'Modo offline / demo local',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (queueCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warnSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Cola: $queueCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warnStrong,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              gpsOk ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              size: 16,
              color: gpsOk ? AppColors.okStrong : AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final AppLanguage language;
  final String pendingLabel;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.language,
    required this.pendingLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHot = order.thermalMode == ThermalMode.hot;
    final badgeBg = isHot ? AppColors.hotSoft : AppColors.coldSoft;
    final badgeFg = isHot ? AppColors.hotStrong : AppColors.coldStrong;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodBuddyWidget(
                category: order.foodCategory,
                thermalMode: order.thermalMode,
                currentTemp: order.currentTemp,
                minTemp: order.targetMinTemp,
                maxTemp: order.targetMaxTemp,
                previousTemp: order.previousTemp,
                size: 62,
                showCaption: false,
                language: language,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.id,
                          style: AppTheme.mono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${order.targetMinTemp.toStringAsFixed(0)}–${order.targetMaxTemp.toStringAsFixed(0)}°C',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.customerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MiniChip(
                          icon: Icons.inventory_2_outlined,
                          text: order.smartBoxId,
                        ),
                        const SizedBox(width: 8),
                        _MiniChip(
                          icon: Icons.battery_charging_full_rounded,
                          text: '${order.batteryLevel}%',
                        ),
                        const Spacer(),
                        Text(
                          pendingLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: AppColors.ink,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.ink2),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}
