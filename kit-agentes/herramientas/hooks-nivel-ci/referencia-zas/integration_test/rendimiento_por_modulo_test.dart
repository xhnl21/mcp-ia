// integration_test/rendimiento_por_modulo_test.dart
//
// Rendimiento por módulo con la app real, la sesión guardada en el
// dispositivo y el backend de verdad. Por cada módulo mide:
//   - apertura_ms: del toque hasta que no queda ningún indicador de carga
//     (incluye la animación de entrada y las peticiones al backend);
//   - fotogramas (watchPerformance): tiempo de build y de raster por
//     fotograma (promedio, p90, p99, peor) y fotogramas fuera de presupuesto,
//     al abrir y al desplazar.
//
// Necesita una sesión abierta en el dispositivo. En modo profile (en debug
// los fotogramas no sirven):
//
//   flutter drive --profile --no-dds --keep-app-running \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/rendimiento_por_modulo_test.dart \
//     -d <dispositivo> --flavor dev --dart-define-from-file .env.dev
//
// `--keep-app-running` evita que `flutter drive` desinstale la app al
// terminar (se perdería la sesión). El informe queda en
// build/integration_response_data.json.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zas/main.dart' as app;
import 'package:zas/presentation/cubits/auth/login_cubit.dart';
import 'package:zas/presentation/cubits/auth/login_state.dart';
import 'package:zas/presentation/widgets/skeletons/skeleton_box.dart';

/// Tiempo máximo para que un módulo termine de cargar.
const _limite = Duration(seconds: 20);

/// Tiempo que se observa la sesión en el dashboard al terminar
/// (`--dart-define=RENDIMIENTO_OBSERVAR_S=0` para no esperar).
const _observacion = Duration(
  seconds: int.fromEnvironment('RENDIMIENTO_OBSERVAR_S', defaultValue: 90),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('rendimiento por módulo', (tester) async {
    // Un toque que no llega a su destino falla, en vez de tocar lo que haya
    // encima (así se cerró la sesión tocando «Cerrar Sesión»).
    WidgetController.hitTestWarningShouldBeFatal = true;
    final apertura = <String, int>{};
    // La app instala su propio manejador de errores y una excepción no
    // haría fallar la prueba: cada módulo se aísla y su error se anota.
    final errores = <String, String>{};
    // Vigía de la sesión: cada cambio de autenticación con el paso que se
    // estaba haciendo, para encontrar qué la cierra durante la prueba.
    final sesion = <Map<String, Object?>>[];
    var paso = 'arranque';
    StreamSubscription<LoginState>? vigia;
    void guardar() => binding.reportData = {
      ...?binding.reportData,
      'apertura_ms': apertura,
      'errores': errores,
      'sesion': sesion,
    };
    void vigilarSesion() {
      final login = tester
          .element(find.byType(Navigator).first)
          .read<LoginCubit>();
      var autenticado = login.state.isAuthenticated;
      void anotar(String evento, LoginState estado) {
        sesion.add({
          'hora': DateTime.now().toIso8601String(),
          'paso': paso,
          'evento': evento,
          'mensaje': estado.sessionExpiredMessage,
        });
        debugPrint('Rendimiento: sesión $evento durante «$paso»');
      }

      anotar(autenticado ? 'abierta' : 'cerrada', login.state);
      vigia = login.stream.listen((estado) {
        if (estado.isAuthenticated == autenticado) return;
        autenticado = estado.isAuthenticated;
        anotar(autenticado ? 'abierta' : 'cerrada', estado);
      });
    }

    /// Espera hasta que no haya indicadores de carga durante 300 ms y
    /// devuelve los milisegundos desde [reloj]; -1 si pasa [_limite].
    Future<int> esperarCarga(Stopwatch reloj) async {
      var quietos = 0;
      await tester.pump(const Duration(milliseconds: 100));
      while (reloj.elapsed < _limite) {
        final cargando =
            find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
            find.byType(SkeletonBox).evaluate().isNotEmpty;
        quietos = cargando ? 0 : quietos + 1;
        if (quietos >= 3) return reloj.elapsedMilliseconds - 300;
        await tester.pump(const Duration(milliseconds: 100));
      }
      return -1;
    }

    Future<void> desplazar() async {
      // Solo una lista que se pueda tocar: la primera del árbol puede ser la
      // de la pantalla de abajo, tapada por la que se abrió.
      final listas = find.byType(Scrollable).hitTestable();
      if (listas.evaluate().isEmpty) return;
      await tester.fling(listas.first, const Offset(0, -600), 3000);
      await tester.pump(const Duration(seconds: 1));
      await tester.fling(listas.first, const Offset(0, 600), 3000);
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> medir(String modulo, Future<void> Function() abrir) async {
      debugPrint('Rendimiento: midiendo $modulo');
      paso = 'abrir $modulo';
      try {
        await binding.watchPerformance(() async {
          final reloj = Stopwatch()..start();
          await abrir();
          apertura[modulo] = await esperarCarga(reloj);
          paso = 'desplazar $modulo';
          await desplazar();
        }, reportKey: modulo);
      } catch (e) {
        errores[modulo] = '$e';
      }
      guardar();
    }

    Future<void> tocar(Finder destino) async {
      // En pantallas bajas (Redmi Note 8), «Seguridad» quedaba tapada por
      // «Cerrar Sesión» y el toque cerraba la sesión: se lleva a la vista.
      await tester.ensureVisible(destino);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(destino);
      await tester.pump();
    }

    // maybePop y no el Atrás del sistema: en el dashboard, un Atrás de más
    // cierra la app.
    Future<void> volver() async {
      paso = 'volver desde ${paso.split(' ').last}';
      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await tester.pump(const Duration(seconds: 1));
    }

    /// Vuelve al dashboard (donde está el botón del menú lateral).
    Future<void> alInicio() async {
      for (
        var i = 0;
        i < 5 && find.byIcon(Icons.menu).evaluate().isEmpty;
        i++
      ) {
        await volver();
      }
    }

    Future<void> menuLateral(String opcion) async {
      await tocar(find.byIcon(Icons.menu));
      await tester.pump(const Duration(milliseconds: 600));
      await tocar(find.text(opcion));
    }

    // Arranque hasta el dashboard listo.
    await medir('inicio', () async {
      await app.main();
      final reloj = Stopwatch()..start();
      while (find.byIcon(Icons.menu).evaluate().isEmpty &&
          reloj.elapsed < _limite) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    vigilarSesion();

    await medir('historial', () => tocar(find.text('Historial').last));
    await medir('nueva_venta', () => tocar(find.text('Nueva venta').last));
    await alInicio();

    // Los del menú lateral van antes de Configuración, que es la parte más
    // larga del recorrido.
    await medir('pagar_suscripcion', () => menuLateral('Pagar suscripción'));
    await medir('soporte_chats', () => tocar(find.text('Soporte')));
    await alInicio();

    await medir('soporte_tecnico', () => menuLateral('Soporte técnico'));
    await alInicio();

    await medir('configuracion', () => tocar(find.text('Ajustes').last));
    for (final (modulo, opcion) in const [
      ('perfil_comercio', 'Perfil del comercio'),
      ('perfil_usuario', 'Perfil de usuario'),
      ('cuentas_cobro', 'Cuentas de cobro'),
      ('sonido_notificaciones', 'Sonido y notificaciones'),
      ('moneda_tasa', 'Moneda y tasa'),
      ('usuarios', 'Usuarios y permisos'),
      ('grupos_cajitas', 'Grupos de Cajitas'),
      ('seguridad', 'Seguridad'),
    ]) {
      if (find.text(opcion).evaluate().isEmpty) continue;
      await medir(modulo, () => tocar(find.text(opcion)));
      await volver();
    }
    await alInicio();

    // La sesión se cerró en el Redmi unos minutos después de entrar: se
    // observa un rato más en el dashboard para ver si se cierra sola.
    paso = 'observar en el dashboard';
    final observar = Stopwatch()..start();
    while (observar.elapsed < _observacion) {
      await tester.pump(const Duration(seconds: 1));
    }
    await vigia?.cancel();
    guardar();
    expect(errores, isEmpty, reason: 'Módulos que no se pudieron medir');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
