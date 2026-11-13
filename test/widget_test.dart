import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cold2hot_mobile/core/iot/offline_sync_queue.dart';
import 'package:cold2hot_mobile/core/models/delivery_models.dart';
import 'package:cold2hot_mobile/core/state/app_state.dart';
import 'package:cold2hot_mobile/main.dart';
import 'package:cold2hot_mobile/shared/widgets/food_buddy_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FoodBuddyWidget thermal mood logic', () {
    test('hot food cools down and freezes below minTemp', () {
      expect(
        FoodBuddyWidget.computeMood(
          mode: ThermalMode.hot,
          currentTemp: 70,
          minTemp: 65,
          maxTemp: 80,
          previousTemp: 70,
        ),
        BuddyMood.optimal,
      );
      expect(
        FoodBuddyWidget.computeMood(
          mode: ThermalMode.hot,
          currentTemp: 66,
          minTemp: 65,
          maxTemp: 80,
          previousTemp: 68,
        ),
        BuddyMood.cooling,
      );
      expect(
        FoodBuddyWidget.computeMood(
          mode: ThermalMode.hot,
          currentTemp: 59,
          minTemp: 65,
          maxTemp: 80,
          previousTemp: 61,
        ),
        BuddyMood.frozen,
      );
    });

    test('cold food warms up and melts above maxTemp', () {
      expect(
        FoodBuddyWidget.computeMood(
          mode: ThermalMode.cold,
          currentTemp: -13,
          minTemp: -16,
          maxTemp: -8,
          previousTemp: -13,
        ),
        BuddyMood.optimal,
      );
      expect(
        FoodBuddyWidget.computeMood(
          mode: ThermalMode.cold,
          currentTemp: -9.5,
          minTemp: -16,
          maxTemp: -8,
          previousTemp: -11,
        ),
        BuddyMood.warming,
      );
      expect(
        FoodBuddyWidget.computeMood(
          mode: ThermalMode.cold,
          currentTemp: -4,
          minTemp: -16,
          maxTemp: -8,
          previousTemp: -7,
        ),
        BuddyMood.melting,
      );
    });
  });

  group('IoT Store-and-Forward & RSSI helpers', () {
    test('OfflineSyncQueue persists and flushes FIFO items', () async {
      final queue = OfflineSyncQueue();
      await queue.enqueue('telemetry', {'temperature': 68.5});
      await queue.enqueue('tamper', {'lidOpen': true});
      expect(queue.pendingCount, 2);

      int calls = 0;
      final flushed = await queue.flush((item) async {
        calls++;
        return calls == 1; // Falla en el segundo para validar retención FIFO
      });

      expect(flushed, 1);
      expect(queue.pendingCount, 1);
      expect(queue.items.first.kind, 'tamper');
    });

    test('BleDeviceInfo estimates realistic distance from RSSI', () {
      const near = BleDeviceInfo(
        id: 'SB-014',
        name: 'Cold2Hot-SB-014',
        macAddress: 'AA:BB:CC',
        rssi: -59,
      );
      const far = BleDeviceInfo(
        id: 'SB-022',
        name: 'Cold2Hot-SB-022',
        macAddress: 'DD:EE:FF',
        rssi: -79,
      );
      expect(near.estimatedDistanceMeters, closeTo(1.0, 0.05));
      expect(far.estimatedDistanceMeters, greaterThan(near.estimatedDistanceMeters));
    });
  });

  group('Mobile M01–M13 end-to-end & legal gate', () {
    testWidgets('enforces T&C, completes M01 -> M13 flow cleanly', (
      WidgetTester tester,
    ) async {
      final state = AppState(enablePlatformPlugins: false);
      addTearDown(state.dispose);

      await tester.pumpWidget(Cold2HotOperatorApp(appState: state));
      await tester.pump();

      // 1. M01: Bloqueo sin aceptar Términos y Condiciones
      await tester.ensureVisible(find.byKey(const Key('login_submit_btn')));
      await tester.tap(find.byKey(const Key('login_submit_btn')));
      await tester.pump();

      expect(state.isAuthenticated, isFalse);
      expect(find.textContaining('Términos y Condiciones'), findsWidgets);

      // 2. M01 -> M03: Aceptar T&C e iniciar sesión
      await tester.ensureVisible(find.byKey(const Key('terms_checkbox')));
      await tester.tap(find.byKey(const Key('terms_checkbox')));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('login_submit_btn')));
      await tester.tap(find.byKey(const Key('login_submit_btn')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.isAuthenticated, isTrue);
      expect(find.text('#C2H-10482'), findsOneWidget);

      // 3. M03 -> M04: Detalle de orden + mapa
      await tester.tap(find.text('#C2H-10482'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.currentStep, DeliveryStep.orderDetail);

      // 4. M04 -> M05: Escaneo BLE simulado
      await tester.ensureVisible(find.byKey(const Key('m04_connect_smartbox_btn')));
      await tester.tap(find.byKey(const Key('m04_connect_smartbox_btn')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.currentStep, DeliveryStep.bleConnect);
      await tester.pump(const Duration(milliseconds: 800));

      await tester.tap(find.text('Enlazar').first);
      await tester.pump(const Duration(milliseconds: 700));
      expect(state.currentStep, DeliveryStep.inTransit);

      // 5. M06 -> M07: Simulación de apertura de tapa sin OTP
      await state.simulateLidState(lidOpen: true, packagePresent: false);
      await tester.pump();
      expect(find.text(state.strings.alertTamperTitle), findsOneWidget);

      // 6. M06 -> M08: OTP incorrecto suma intento y correcto desbloquea M10
      await tester.ensureVisible(find.byKey(const Key('m06_arrive_otp_btn')));
      await tester.tap(find.byKey(const Key('m06_arrive_otp_btn')));
      await tester.pump();
      expect(state.currentStep, DeliveryStep.otpUnlock);

      for (final d in ['1', '1', '1', '1', '1', '1']) {
        await tester.tap(find.text(d).last);
      }
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('m08_unlock_btn')));
      await tester.tap(find.byKey(const Key('m08_unlock_btn')));
      await tester.pump();
      expect(state.otpAttempts, 1);

      await tester.tap(find.text('C'));
      for (final d in ['4', '8', '2', '7', '1', '9']) {
        await tester.tap(find.text(d).last);
      }
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('m08_unlock_btn')));
      await tester.tap(find.byKey(const Key('m08_unlock_btn')));
      await tester.pump();
      expect(state.currentStep, DeliveryStep.boxUnlocked);

      // 7. M10 -> M11 -> M12 -> M13: Foto de evidencia y cierre
      await tester.tap(find.byKey(const Key('m10_take_photo_btn')));
      await tester.pump();
      expect(state.currentStep, DeliveryStep.captureEvidence);

      await tester.ensureVisible(find.byKey(const Key('m11_demo_capture_btn')));
      await tester.tap(find.byKey(const Key('m11_demo_capture_btn')));
      await tester.pump();
      expect(state.currentStep, DeliveryStep.reviewEvidence);

      await tester.ensureVisible(find.byKey(const Key('m12_confirm_send_btn')));
      await tester.tap(find.byKey(const Key('m12_confirm_send_btn')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(state.currentStep, DeliveryStep.completed);

      await tester.ensureVisible(find.byKey(const Key('m13_finish_btn')));
      await tester.tap(find.byKey(const Key('m13_finish_btn')));
      await tester.pump(const Duration(milliseconds: 80));
      expect(state.currentOrder, isNull);
    });

    testWidgets('Demo button opens legal terms if unchecked and signs right in', (
      WidgetTester tester,
    ) async {
      final state = AppState(enablePlatformPlugins: false);
      addTearDown(state.dispose);

      await tester.pumpWidget(Cold2HotOperatorApp(appState: state));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('login_demo_btn')));
      await tester.tap(find.byKey(const Key('login_demo_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('Aceptar términos y continuar'), findsOneWidget);
      await tester.ensureVisible(find.text('Aceptar términos y continuar'));
      await tester.tap(find.text('Aceptar términos y continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(state.isAuthenticated, isTrue);
      expect(state.termsAccepted, isTrue);
      expect(state.user?.email, 'admin@mirestaurante.pe');
      expect(find.text('#C2H-10482'), findsOneWidget);
    });
  });
}
