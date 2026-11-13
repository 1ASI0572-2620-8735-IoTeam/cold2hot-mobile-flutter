import 'package:material_ui/material_ui.dart';
import '../../core/models/delivery_models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/food_buddy_widget.dart';

enum _HistoryPeriod { all, today, week, month }

/// M14 Historial de Entregas con filtros temporales y auditoría rápida.
class HistoryScreen extends StatefulWidget {
  final AppState appState;

  const HistoryScreen({super.key, required this.appState});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryPeriod _period = _HistoryPeriod.all;

  List<DeliveryOrder> get _filtered {
    final now = DateTime.now();
    return widget.appState.historyOrders.where((o) {
      final dt = o.deliveredAt ?? o.createdAt;
      switch (_period) {
        case _HistoryPeriod.all:
          return true;
        case _HistoryPeriod.today:
          return dt.year == now.year && dt.month == now.month && dt.day == now.day;
        case _HistoryPeriod.week:
          return now.difference(dt).inDays <= 7;
        case _HistoryPeriod.month:
          return now.difference(dt).inDays <= 30;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final isEs = widget.appState.language == AppLanguage.es;

    return Column(
      children: [
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _FilterChip(
                label: isEs ? 'Todos' : 'All',
                selected: _period == _HistoryPeriod.all,
                onTap: () => setState(() => _period = _HistoryPeriod.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: isEs ? 'Hoy' : 'Today',
                selected: _period == _HistoryPeriod.today,
                onTap: () => setState(() => _period = _HistoryPeriod.today),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: isEs ? 'Esta semana' : 'This week',
                selected: _period == _HistoryPeriod.week,
                onTap: () => setState(() => _period = _HistoryPeriod.week),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: isEs ? 'Este mes' : 'This month',
                selected: _period == _HistoryPeriod.month,
                onTap: () => setState(() => _period = _HistoryPeriod.month),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    isEs
                        ? 'Sin entregas registradas en este período.'
                        : 'No deliveries recorded for this period.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final o = items[idx];
                    final breach = o.thermalStatus == ThermalStatus.breach;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            FoodBuddyWidget(
                              category: o.foodCategory,
                              thermalMode: o.thermalMode,
                              currentTemp: o.currentTemp,
                              minTemp: o.targetMinTemp,
                              maxTemp: o.targetMaxTemp,
                              size: 52,
                              showCaption: false,
                              language: widget.appState.language,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        o.id,
                                        style: AppTheme.mono(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: breach
                                              ? AppColors.dangerSoft
                                              : AppColors.okSoft,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          breach
                                              ? 'Con desvío'
                                              : 'Custodia intacta',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: breach
                                                ? AppColors.dangerStrong
                                                : AppColors.okStrong,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    o.customerName,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${o.customerAddress} · Final ${o.currentTemp.toStringAsFixed(1)}°C',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.bg,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.ink2,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      side: const BorderSide(color: AppColors.line),
      shape: const StadiumBorder(),
    );
  }
}
