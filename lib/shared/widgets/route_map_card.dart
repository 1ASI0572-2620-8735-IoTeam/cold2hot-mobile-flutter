import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/delivery_models.dart';
import '../../core/theme/app_theme.dart';

/// Tarjeta de mapa real con OpenStreetMap (`flutter_map`) que traza la ruta
/// entre la ubicación GPS actual del repartidor y la dirección de entrega.
class RouteMapCard extends StatelessWidget {
  final GeoPoint destination;
  final GeoPoint? courierPosition;
  final String destinationLabel;
  final double height;
  final bool loadNetworkTiles;

  const RouteMapCard({
    super.key,
    required this.destination,
    this.courierPosition,
    required this.destinationLabel,
    this.height = 190,
    this.loadNetworkTiles = true,
  });

  @override
  Widget build(BuildContext context) {
    final destLatLng = LatLng(destination.lat, destination.lng);
    final courierLatLng = courierPosition != null
        ? LatLng(courierPosition!.lat, courierPosition!.lng)
        : LatLng(destination.lat - 0.0085, destination.lng - 0.0095);

    final midLat = (destLatLng.latitude + courierLatLng.latitude) / 2;
    final midLng = (destLatLng.longitude + courierLatLng.longitude) / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.bgAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(midLat, midLng),
                initialZoom: 13.6,
                backgroundColor: AppColors.bgAlt,
              ),
              children: [
                if (loadNetworkTiles)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ioteam.cold2hot.cold2hot_mobile_app',
                    maxNativeZoom: 19,
                  ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [courierLatLng, destLatLng],
                      color: AppColors.hot,
                      strokeWidth: 3.5,
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: courierLatLng,
                      width: 38,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    Marker(
                      point: destLatLng,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.hot,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.navigation_rounded,
                      size: 16,
                      color: AppColors.hotStrong,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        destinationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      courierPosition != null ? 'GPS Vivo' : 'Ruta ref.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: courierPosition != null
                                ? AppColors.okStrong
                                : AppColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
