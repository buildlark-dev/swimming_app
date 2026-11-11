/// Una sesión y lo que la nadadora contestó, **en dos bloques con nombre**.
///
/// Es el principio VIII en la pantalla: lo programado —metros, objetivos, la
/// zona— es carga **externa**; lo que ella contestó —si la hizo, el esfuerzo
/// percibido, lo que escribió— es carga **interna**. Van etiquetados y
/// separados, y no hay ninguna cifra sacada de los dos.
///
/// **Lo que aquí no hay, y es lo importante**: ningún número derivado del par.
/// Ni metros por RPE, ni una «carga de la sesión», ni un color que resuma las
/// dos cosas en una. El tipo que llega aquí tampoco puede dárselo
/// —`RespuestaASesion` no tiene ningún miembro que mire a los dos—, así que
/// para romper esto habría que escribir la multiplicación aquí mismo, y hay
/// una prueba leyendo esta fuente.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/analisis/respuesta_a_sesion.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class SesionYRespuesta extends StatelessWidget {
  const SesionYRespuesta({super.key, required this.respuesta});

  final RespuestaASesion respuesta;

  @override
  Widget build(BuildContext context) {
    final sesion = respuesta.sesion;
    final id = sesion.id ?? '';
    final texto = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.normal),
      child: Tarjeta(
        key: Key('sesion-y-respuesta-$id'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cuando(sesion.fecha), style: texto.titleSmall),
            const SizedBox(height: Espaciado.corto),

            // --- Carga externa: lo que él programó -----------------------
            Text('Lo programado', style: texto.labelMedium),
            Text(
              key: Key('lo-programado-$id'),
              _loProgramado(),
              style: texto.bodyMedium,
            ),
            if (sesion.objetivoTecnico.trim().isNotEmpty)
              Text(sesion.objetivoTecnico, style: texto.bodySmall),

            const SizedBox(height: Espaciado.normal),

            // --- Carga interna: lo que ella contestó ---------------------
            Text('Lo que contestó', style: texto.labelMedium),
            Text(
              key: Key('lo-que-contesto-$id'),
              _loQueContesto(),
              style: texto.bodyMedium,
            ),
            if (_observaciones.isNotEmpty) ...[
              const SizedBox(height: Espaciado.minimo),
              Text(_observaciones, style: texto.bodySmall),
            ],

            // --- La molestia, aparte -------------------------------------
            //
            // **Aparte y no dentro de las observaciones** (FR-009). Si viviera
            // en el texto libre, encontrarla dependería de que alguien leyera
            // todas las observaciones de todas las sesiones.
            //
            // Tono `cuidado` y no `error`: el tema ya lo dejó decidido —«tiene
            // que encontrarse sin leer todas las observaciones, y a la vez no
            // parecer una alarma médica»—. Pintarlo de rojo sería opinar, y el
            // principio IV no delega eso.
            if (respuesta.tieneMolestia) ...[
              const SizedBox(height: Espaciado.normal),
              Aviso(
                tono: TonoDeAviso.cuidado,
                titulo: 'Contó una molestia',
                mensaje: respuesta.registro!.molestia!.descripcion,
                claveDelMensaje: Key('molestia-en-$id'),
                detalles: [
                  if (respuesta.registro!.molestia!.zonaDelCuerpo
                      .trim()
                      .isNotEmpty)
                    Text(respuesta.registro!.molestia!.zonaDelCuerpo),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _observaciones => respuesta.registro?.observaciones.trim() ?? '';

  /// Carga externa, en palabras. Solo lee la sesión.
  String _loProgramado() {
    final sesion = respuesta.sesion;
    final partes = <String>[
      '${sesion.metros} m',
      if (sesion.metrosTecnicos > 0)
        '${sesion.porcentajeTecnico.round()}% técnico',
      if (sesion.rpePrevisto != null) 'RPE previsto ${sesion.rpePrevisto}',
    ];
    return partes.join(' · ');
  }

  /// Carga interna, en palabras. Solo lee el registro.
  ///
  /// Las tres respuestas posibles se leen **distintas**, y eso es el cerrojo:
  /// «no la hizo» es un dato que ella escribió y «sin respuesta» es la
  /// ausencia de uno. Leerlos igual le enseñaría al entrenador un hueco donde
  /// hay una respuesta.
  String _loQueContesto() {
    final registro = respuesta.registro;
    if (registro == null) return 'Sin respuesta';
    if (!registro.realizada) return 'Dijo que no la hizo';

    final rpe = registro.rpePercibido;
    return rpe == null ? 'La hizo' : 'La hizo · esfuerzo percibido $rpe de 10';
  }
}

/// Una fecha como la lee el entrenador. **Con año**: una prueba de la feature
/// 009 comparaba mes y día sin año en un macrociclo que cruzaba a enero, y
/// pasaba por casualidad.
String cuando(DateTime? fecha) {
  if (fecha == null) return 'Sin fecha';
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
