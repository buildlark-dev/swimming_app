/// Lo que el nadador ve al abrir la app.
///
/// Su sesión del día, con los objetivos y las tres partes, y debajo el sitio
/// donde responder. Funciona **sin señal**: todo lo que pinta sale de lo que ya
/// está en el dispositivo (FR-005).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/calculo/sesion_del_dia.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/notacion/renderizador.dart';
import 'package:natacion_app/ui/nadador/aviso_sincronizacion.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/formulario_registro.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/tema/tipografia.dart';
import 'package:provider/provider.dart';

class PantallaSesionDelDia extends StatelessWidget {
  const PantallaSesionDelDia({super.key, this.selector});

  /// Quién está usando la app como nadador.
  ///
  /// Se inyecta en lugar de construirse aquí para que esta pantalla no sepa de
  /// dónde salen los perfiles. Nulo en las pruebas, que abren el estado
  /// directamente.
  final Widget? selector;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoNadador>();

    return Scaffold(
      // «Al día hasta el 20/10 a las 07:00» **no cabe en la barra**.
      //
      // Con la letra del sistema al 200% se salía 279 píxeles por la derecha, y
      // quien agranda la letra es precisamente quien necesita leer eso. Baja al
      // cuerpo, junto al aviso de sincronización, que es de lo que habla.
      appBar: AppBar(title: const Text('Mi entrenamiento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (selector != null) ...[
            selector!,
            const SizedBox(height: 12),
          ],
          AvisoSincronizacion(estado: estado),
          const SizedBox(height: Espaciado.minimo),
          UltimaSincronizacion(estado: estado),
          const SizedBox(height: 8),
          _Hoy(estado: estado),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Hoy extends StatelessWidget {
  const _Hoy({required this.estado});

  final EstadoNadador estado;

  @override
  Widget build(BuildContext context) {
    if (estado.plan == null) {
      return const EstadoVacio(
        icono: Icons.event_busy_outlined,
        titulo: 'Todavía no tienes un plan asignado',
        queHacer: 'Cuando tu entrenador te asigne uno, aparecerá aquí.',
      );
    }

    return switch (estado.hoy) {
      SesionDeHoy(:final sesion) => _Sesion(sesion: sesion, estado: estado),
      SinSesionHoy(:final siguiente, :final cuando) => EstadoVacio(
          icono: Icons.event_available_outlined,
          titulo: 'Hoy descansas',
          queHacer: 'Tu próxima sesión es el '
              '${cuando.day.toString().padLeft(2, '0')}/'
              '${cuando.month.toString().padLeft(2, '0')}: '
              '${siguiente.objetivoTecnico}',
        ),
      SinSesionesPorDelante() => const EstadoVacio(
          icono: Icons.flag_outlined,
          titulo: 'No quedan sesiones por delante',
          queHacer: 'Habla con tu entrenador para el siguiente ciclo.',
        ),
    };
  }
}

class _Sesion extends StatelessWidget {
  const _Sesion({required this.sesion, required this.estado});

  final Sesion sesion;
  final EstadoNadador estado;

  @override
  Widget build(BuildContext context) {
    final registro = estado.registroDe(sesion.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sesion.objetivoTecnico,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${sesion.metros} m',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(sesion.objetivoFisiologico),
                if (registro?.realizada ?? false) ...[
                  const SizedBox(height: 8),
                  const Chip(
                    avatar: Icon(Icons.check_circle_outline, size: 18),
                    label: Text('Ya la marcaste como realizada'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final tipo in TipoParte.values) _Parte(sesion: sesion, tipo: tipo),
        const SizedBox(height: 12),
        FormularioRegistro(sesion: sesion, estado: estado),
      ],
    );
  }
}

class _Parte extends StatelessWidget {
  const _Parte({required this.sesion, required this.tipo});

  final Sesion sesion;
  final TipoParte tipo;

  @override
  Widget build(BuildContext context) {
    final parte = sesion.parteDe(tipo);
    if (parte.series.isEmpty) return const SizedBox.shrink();

    // Se reutiliza el renderizador de la feature 002: las series se muestran
    // con la notación del entrenador y los nombres exactos de la Biblioteca,
    // sin abreviar, reescribir ni corregir (FR-004).
    const renderizador = Renderizador();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // `Wrap` y no `Row`: si el nombre de la parte y los metros no caben
            // en una línea, los metros bajan a la siguiente en lugar de
            // salirse.
            CabeceraSeccion(
              titulo: tipo.nombre,
              cifra: '${parte.metros} m',
              estilo: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(),
            // Cifras de ancho fijo (FR-008). `4x100 / 1'40"` es una
            // **instrucción**: si las columnas bailan de línea a línea, se lee
            // mal, y leer mal una cifra cambia lo que el nadador hace en el
            // agua. Es el sitio de la app donde esto más importa.
            SelectableText(
              renderizador.series(parte.series),
              style: Tipografia.notacion(
                Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

