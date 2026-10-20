/// El aviso de progreso guardado.
///
/// FR-017: ante un registro escrito sin conexión se muestra un estado explícito
/// que indica que quedó guardado y que se enviará cuando haya internet.
///
/// **Lo que nunca se le muestra al nadador**: un error de red, un código de
/// estado, un contador de reintentos o un botón de «reintentar». El reintento es
/// trabajo de la app, y alguien mojado al borde de una piscina no está para
/// diagnosticar conectividad.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/tema/avisos.dart';

class AvisoSincronizacion extends StatelessWidget {
  const AvisoSincronizacion({super.key, required this.estado});

  final EstadoNadador estado;

  @override
  Widget build(BuildContext context) {
    // Sin pendientes no ocupa pantalla: el estado de sincronización no estorba
    // cuando no hace falta.
    if (!estado.hayPendientes) return const SizedBox.shrink();

    // **Tono de éxito, no de error.**
    //
    // «Guardado, se enviará cuando tengas internet» es una buena noticia:
    // significa que la bandeja de salida de la feature 003 hizo su trabajo y
    // que el nadador no perdió nada. Lo que no hay es señal, y eso no es culpa
    // suya ni un fallo de la app.
    //
    // El icono sí sigue siendo el de la nube tachada, que es lo que describe el
    // caso mejor que un visto (garantía V12).
    return const Aviso(
      tono: TonoDeAviso.exito,
      icono: Icons.cloud_off_outlined,
      mensaje: avisoProgresoGuardado,
    );
  }
}

/// Cuándo se sincronizó por última vez.
///
/// La lectura sin conexión solo cubre lo que ya se descargó alguna vez
/// (decisión D1), así que el nadador tiene derecho a saber si lo que lee está
/// al día. No es un aviso de error: es información.
class UltimaSincronizacion extends StatelessWidget {
  const UltimaSincronizacion({super.key, required this.estado});

  final EstadoNadador estado;

  @override
  Widget build(BuildContext context) {
    final cuando = estado.ultimaSincronizacion;
    final estilo = Theme.of(context).textTheme.bodySmall;

    if (cuando == null) {
      return Text('Sin sincronizar todavía', style: estilo);
    }

    final dia = '${cuando.day.toString().padLeft(2, '0')}/'
        '${cuando.month.toString().padLeft(2, '0')}';
    final hora = '${cuando.hour.toString().padLeft(2, '0')}:'
        '${cuando.minute.toString().padLeft(2, '0')}';

    return Text('Al día hasta el $dia a las $hora', style: estilo);
  }
}
