/// La portada del entrenador: cuatro números.
///
/// Son cuentas, no juicios, y **ninguno mueve un plan de estado** (H18).
/// «Cuántos esperan aprobación» no dice si están bien; firmar sigue siendo un
/// acto suyo en la pantalla del plan, que es lo que el principio IV no delega.
///
/// Por eso aquí no hay ni un botón de aprobar, firmar, publicar o entregar.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/hub/resumen_del_entrenador.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/tema/tipografia.dart';

class HomeDelEntrenador extends StatelessWidget {
  const HomeDelEntrenador({super.key, required this.resumen});

  /// Nulo mientras se cuenta. No se enseñan ceros como si fueran datos.
  final ResumenDelEntrenador? resumen;

  @override
  Widget build(BuildContext context) {
    final cuentas = resumen;

    if (cuentas == null) {
      return const Center(
        key: Key('home-entrenador'),
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      key: const Key('home-entrenador'),
      padding: const EdgeInsets.all(Espaciado.amplio),
      children: [
        if (cuentas.sinNadaTodavia)
          const EstadoVacio(
            key: Key('home-sin-nada'),
            icono: Icons.auto_awesome_outlined,
            titulo: 'Todavía no has generado ningún plan',
            queHacer:
                'Empieza en «Generar»: declara los datos de la semana y '
                'la app devuelve el microciclo cuadrado para que lo revises.',
          )
        else ...[
          _Numero(
            clave: 'numero-planes',
            etiqueta: 'Planes generados',
            icono: Icons.description_outlined,
            valor: cuentas.planesGenerados,
          ),
          const SizedBox(height: Espaciado.normal),
          _Numero(
            clave: 'numero-en-uso',
            etiqueta: 'En uso',
            detalle: 'Entregados, y su nadador ya respondió algo',
            icono: Icons.pool_outlined,
            valor: cuentas.enUso,
          ),
          const SizedBox(height: Espaciado.normal),
          _Numero(
            clave: 'numero-esperando',
            etiqueta: 'Esperando tu firma',
            detalle: 'Borradores sin nada que impida aprobarlos',
            icono: Icons.draw_outlined,
            valor: cuentas.esperandoAprobacion,
          ),
          const SizedBox(height: Espaciado.normal),
          _Numero(
            clave: 'numero-sin-asignar',
            etiqueta: 'Aprobados sin entregar',
            detalle: 'Firmados y todavía sin nadador',
            icono: Icons.inbox_outlined,
            valor: cuentas.aprobadosSinAsignar,
          ),
        ],
      ],
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.clave,
    required this.etiqueta,
    required this.icono,
    required this.valor,
    this.detalle,
  });

  final String clave;
  final String etiqueta;
  final String? detalle;
  final IconData icono;
  final int valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    return Tarjeta(
      child: Row(
        children: [
          Icon(icono, color: esquema.primary),
          const SizedBox(width: Espaciado.amplio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: textos.titleSmall),
                if (detalle != null) ...[
                  const SizedBox(height: Espaciado.minimo),
                  Text(
                    detalle!,
                    style: textos.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Espaciado.amplio),
          Text(
            '$valor',
            key: Key(clave),
            // Cifras tabulares: cuatro números en columna que no bailan al
            // cambiar de valor. Es el estilo que el tema de la 005 declara
            // para la notación, por la misma razón.
            style: textos.headlineSmall?.copyWith(
              fontFeatures: Tipografia.cifrasTabulares,
            ),
          ),
        ],
      ),
    );
  }
}
