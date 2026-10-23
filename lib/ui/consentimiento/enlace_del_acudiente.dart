/// La puerta por la que entra un acudiente.
///
/// **Esta es la pieza que faltaba.** La feature 004 construyó el formulario, el
/// mecanismo de solicitud y la puerta que retiene los datos, y los tres nunca
/// se tocaron entre sí fuera de las pruebas: no había ruta que entendiera el
/// enlace, así que el correo que un acudiente recibiera no llevaba a ninguna
/// parte (decisión D10 de la feature 006).
///
/// Lo que hace distinta a esta pantalla del resto de la app:
///
/// **No exige haber entrado.** El acudiente no tiene cuenta y no va a crearse
/// una para decir que sí. Esa es toda la razón de que el mecanismo use un token
/// de un solo uso en lugar de una sesión.
///
/// **Se abre antes que nada.** Si la app arranca con este enlace, lo que se ve
/// es el formulario, no la pantalla de acceso. Mandar a un padre a una pantalla
/// de «entra a tu entrenamiento» sería mandarlo a otra app.
library;

import 'package:flutter/material.dart';

/// El token que viene en el enlace, si viene.
///
/// El servidor envía `/consentimiento?t=…`, así que se lee del navegador. No
/// hace falta una librería de rutas para esto, y meter una sería pagar mucho
/// por leer un parámetro.
String? tokenDelEnlace([Uri? desde]) {
  final url = desde ?? Uri.base;

  // El camino puede venir como `/consentimiento` o, en una PWA servida desde
  // una subcarpeta, terminado en él.
  final esDeConsentimiento = url.path.endsWith('/consentimiento') ||
      url.path.endsWith('/consentimiento/') ||
      url.fragment.startsWith('/consentimiento');

  if (!esDeConsentimiento) return null;

  final token = url.queryParameters['t']?.trim();
  return (token == null || token.isEmpty) ? null : token;
}

/// Lo que se le enseña a un acudiente cuyo enlace no sirve.
///
/// **No se dice cuál de los tres motivos fue** —no coincide, venció, ya se
/// usó—. Distinguirlos le diría a quien prueba enlaces cuáles existieron
/// alguna vez, que es la razón por la que el servidor tampoco lo distingue.
class EnlaceQueNoSirve extends StatelessWidget {
  const EnlaceQueNoSirve({super.key, this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autorización')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 40),
              const SizedBox(height: 12),
              Text(
                'Este enlace ya no sirve',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                mensaje ??
                    'Puede que haya vencido o que ya se haya usado. Pídale al '
                        'entrenador que le envíe uno nuevo: el anterior no se '
                        'puede reutilizar, y eso es a propósito.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que ve el acudiente cuando ya autorizó.
class AutorizacionRegistrada extends StatelessWidget {
  const AutorizacionRegistrada({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autorización')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                'Queda registrada su autorización',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Ya puede cerrar esta página. Puede retirar esta autorización '
                'cuando quiera, desde este mismo enlace y sin pasar por el '
                'entrenador.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
