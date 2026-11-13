import 'package:material_ui/material_ui.dart';
import '../../core/models/delivery_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/food_buddy_widget.dart';
import '../../shared/widgets/route_map_card.dart';

/// M04 Detalle del Pedido y Mapa de Ruta antes de iniciar enlace BLE con la SmartBox.
class OrderDetailView extends StatelessWidget {
  final AppState appState;
  final DeliveryOrder order;

  const OrderDetailView({
    super.key,
    required this.appState,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final s = appState.strings;
    final isHot = order.thermalMode == ThermalMode.hot;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                FoodBuddyWidget(
                  category: order.foodCategory,
                  thermalMode: order.thermalMode,
                  currentTemp: order.currentTemp,
                  minTemp: order.targetMinTemp,
                  maxTemp: order.targetMaxTemp,
                  previousTemp: order.previousTemp,
                  size: 76,
                  language: appState.language,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.id,
                        style: AppTheme.mono(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.restaurantName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${isHot ? 'Caliente' : 'Frío'} · ${order.targetMinTemp.toStringAsFixed(0)}–${order.targetMaxTemp.toStringAsFixed(0)}°C',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isHot
                              ? AppColors.hotStrong
                              : AppColors.coldStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        RouteMapCard(
          destination: order.destinationCoord,
          courierPosition: appState.currentGps,
          destinationLabel: order.customerAddress,
          loadNetworkTiles: appState.enablePlatformPlugins,
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailLine(label: s.customerLabel, value: order.customerName),
                const Divider(color: AppColors.line, height: 22),
                _DetailLine(label: s.addressLabel, value: order.customerAddress),
                const Divider(color: AppColors.line, height: 22),
                _DetailLine(
                  label: s.smartBoxLabel,
                  value: '${order.smartBoxId} · MAC ${order.smartBoxMac}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.coldSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.coldStrong.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bluetooth_rounded,
                color: AppColors.coldStrong,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.bleRequiredHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('m04_connect_smartbox_btn'),
          onPressed: appState.proceedToBleScan,
          icon: const Icon(Icons.bluetooth_searching_rounded),
          label: Text(s.connectSmartBoxCta),
        ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
