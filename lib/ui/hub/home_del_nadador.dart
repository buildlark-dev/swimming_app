/// La portada del nadador: cómo va.
///
/// **Lo primero es su sesión de hoy, no un gráfico.** `Home` al centro le
/// cuesta un toque: hasta la feature 007 abría la app y caía directamente en su
/// sesión. La decisión D3 acepta ese toque porque el resumen contesta lo que
/// uno se pregunta al abrir —cómo voy, qué me falta—, y esto es lo que hace que
/// el toque no se pague dos veces.
///
/// No lleva nada que la app no calcule de verdad. Lo que no lleva está fijado
/// en la prueba de `ResumenDelNadador`, leyendo su fuente.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/calculo/sesion_del_dia.dart';
import 'package:natacion_app/dominio/hub/resumen_del_nadador.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

class HomeDelNadador extends StatelessWidget {
  const HomeDelNadador({super.key, required this.irAVerPlan});

  /// El camino a su sesión, desde aquí.
  final VoidCallback irAVerPlan;

  @override
  Widget build(BuildContext context) {
    return Consumer<EstadoNadador>(
      builder: (context, estado, _) {
        final resumen = ResumenDelNadador.de(
          plan: estado.plan,
          registros: estado.registros,
          hoy: estado.hoy,
          ultimaSincronizacion: estado.ultimaSincronizacion,
          hayPendientes: estado.hayPendientes,
        );

        return ListView(
          key: const Key('home-nadador'),
          padding: const EdgeInsets.all(Espaciado.amplio),
          children: [
            if (!resumen.tienePlan)
              const EstadoVacio(
                key: Key('home-sin-plan'),
                icono: Icons.pool_outlined,
                titulo: 'Todavía no tienes un plan',
                queHacer:
                    'Cuando tu entrenador te entregue uno, tu sesión del '
                    'día aparecerá aquí.',
              )
            else ...[
              _Hoy(resumen: resumen, irAVerPlan: irAVerPlan),
              const SizedBox(height: Espaciado.amplio),
              Tarjeta(
                child: CabeceraSeccion(
                  titulo: 'Sesiones cumplidas',
                  cifra: '${resumen.cumplidas} de ${resumen.entregadas}',
                ),
              ),
              const SizedBox(height: Espaciado.amplio),
              _UltimaRespuesta(resumen: resumen),
            ],
            const SizedBox(height: Espaciado.amplio),
            _DeCuandoSonLosDatos(resumen: resumen),
          ],
        );
      },
    );
  }
}

class _Hoy extends StatelessWidget {
  const _Hoy({required this.resumen, required this.irAVerPlan});

  final ResumenDelNadador resumen;
  final VoidCallback irAVerPlan;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    final (titulo, detalle) = switch (resumen.hoy) {
      SesionDeHoy(sesion: final sesion) => (
        'Hoy te toca entrenar',
        sesion.objetivoTecnico,
      ),
      SinSesionHoy() => (
        'Hoy no hay sesión',
        'Tu siguiente sesión está en el plan.',
      ),
      SinSesionesPorDelante() => (
        'No hay sesiones por delante',
        'Tu plan no tiene más sesiones con fecha.',
      ),
    };

    return Tarjeta(
      holgada: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: textos.titleMedium),
          const SizedBox(height: Espaciado.corto),
          Text(detalle, style: textos.bodyMedium),
          const SizedBox(height: Espaciado.amplio),
          // El camino a `Ver Plan`: lo que compensa el toque de la decisión D3.
          FilledButton.icon(
            key: const Key('home-ir-a-ver-plan'),
            onPressed: irAVerPlan,
            icon: const Icon(Icons.pool_outlined),
            label: const Text('Ver mi sesión'),
          ),
        ],
      ),
    );
  }
}

class _UltimaRespuesta extends StatelessWidget {
  const _UltimaRespuesta({required this.resumen});

  final ResumenDelNadador resumen;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final ultima = resumen.ultimaRespuesta;

    // **Que falte no es un problema.** Anotar no es obligatorio (principio
    // VIII): quien no anota nada sigue viendo su plan, y su portada no puede
    // tratarlo como algo que arreglar.
    if (ultima == null) {
      return Tarjeta(
        child: Text(
          'Todavía no has anotado nada. Cuando quieras, puedes decir cómo te '
          'sentiste en cada sesión.',
          style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
        ),
      );
    }

    final rpe = ultima.rpePercibido;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CabeceraSeccion(
            titulo: 'Lo último que anotaste',
            cifra: rpe == null ? null : 'RPE $rpe',
          ),
          const SizedBox(height: Espaciado.corto),
          Text(
            ultima.realizada
                ? 'Marcaste la sesión como hecha.'
                : 'Marcaste que no pudiste hacerla.',
            style: textos.bodyMedium,
          ),
          if (ultima.observaciones.isNotEmpty) ...[
            const SizedBox(height: Espaciado.corto),
            Text(ultima.observaciones, style: textos.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// H14 — de cuándo son los datos que se están mostrando.
///
/// La lectura sin conexión solo cubre lo ya descargado, así que el nadador
/// tiene derecho a saber si lo que lee está al día. Es la misma razón por la
/// que la feature 003 guardó `ultimaSincronizacion`.
class _DeCuandoSonLosDatos extends StatelessWidget {
  const _DeCuandoSonLosDatos({required this.resumen});

  final ResumenDelNadador resumen;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final cuando = resumen.ultimaSincronizacion;

    final mensaje = cuando == null
        ? 'Sin conexión todavía: esto es lo que hay guardado en el teléfono.'
        : 'Al día del ${cuando.day}/${cuando.month} a las '
              '${cuando.hour.toString().padLeft(2, '0')}:'
              '${cuando.minute.toString().padLeft(2, '0')}.';

    return Row(
      key: const Key('home-de-cuando'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          resumen.hayPendientes
              ? Icons.cloud_upload_outlined
              : Icons.cloud_done_outlined,
          size: 16,
          color: esquema.outline,
        ),
        const SizedBox(width: Espaciado.corto),
        Expanded(
          child: Text(
            resumen.hayPendientes
                ? '$mensaje Queda algo tuyo por enviar.'
                : mensaje,
            style: textos.bodySmall?.copyWith(color: esquema.outline),
          ),
        ),
      ],
    );
  }
}
