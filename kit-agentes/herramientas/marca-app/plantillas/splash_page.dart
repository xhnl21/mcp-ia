import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Splash animado generado con la skill marca-app.
///
/// Reproduce `assets/branding/splash.mp4` sin sonido y llama a [onFinished]
/// al terminar. Mientras carga muestra el primer cuadro (sin parpadeo desde el
/// splash nativo). Si el video falla o tarda más de [maxDuration], avanza
/// igual: el splash nunca bloquea la app. No usa setState.
///
/// Requisitos: `video_player` en dependencies y en pubspec.yaml:
///   assets:
///     - assets/branding/splash.mp4
///     - assets/branding/splash_primer_cuadro.png
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onFinished, this.controllerFactory});

  /// Qué hacer al terminar (por ejemplo, `context.go('/')` con go_router).
  final VoidCallback onFinished;

  /// Crea el controlador; se reemplaza en las pruebas.
  final VideoPlayerController Function()? controllerFactory;

  static const videoAsset = 'assets/branding/splash.mp4';
  static const firstFrameAsset = 'assets/branding/splash_primer_cuadro.png';
  static const videoAspectRatio = 720 / 1280; // video.ancho / video.alto
  static const background = Color(0xFF081830); // colores.fondo_splash
  static const maxDuration = Duration(seconds: 6);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final VideoPlayerController _controller =
      widget.controllerFactory?.call() ??
      VideoPlayerController.asset(SplashPage.videoAsset);
  Timer? _safetyTimer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _safetyTimer = Timer(SplashPage.maxDuration, _finish);
    _controller.addListener(_onVideoUpdate);
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      await _controller.play();
    } catch (_) {
      _finish();
    }
  }

  void _onVideoUpdate() {
    final value = _controller.value;
    // El reproductor puede detenerse unos ms antes de la duración exacta.
    final ended =
        value.isCompleted ||
        (value.isInitialized &&
            value.duration > Duration.zero &&
            value.position >=
                value.duration - const Duration(milliseconds: 150));
    if (value.hasError || ended) _finish();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _safetyTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SplashPage.background,
      body: Center(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            return AspectRatio(
              aspectRatio: value.isInitialized
                  ? value.aspectRatio
                  : SplashPage.videoAspectRatio,
              child: value.isInitialized && value.position > Duration.zero
                  ? VideoPlayer(_controller)
                  : Image.asset(
                      SplashPage.firstFrameAsset,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            );
          },
        ),
      ),
    );
  }
}
