/// Camino inverso del analizador: convierte series estructuradas en el texto
/// que el entrenador lee y edita.
///
/// Contrato: `specs/002-generador-microciclos/contracts/renderizado.md`.
///
/// El orden de los elementos es **fijo**, para que el resultado sea
/// determinista y reconocible. No abrevia, no embellece y no corrige: el texto
/// refleja la estructura tal como está.
library;

import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Orden fijo en que se escriben los implementos.
const List<Implemento> ordenDeImplementos = [
  Implemento.aletas,
  Implemento.palas,
  Implemento.palasPequenas,
  Implemento.pullBuoy,
  Implemento.snorkel,
  Implemento.paracaidas,
  Implemento.caucho,
];

/// Orden fijo en que se escriben los modificadores.
const List<Modificador> ordenDeModificadores = [
  Modificador.patada,
  Modificador.brazada,
  Modificador.subacuatico,
  Modificador.recuperacion,
  Modificador.progresivo,
  Modificador.regresivo,
  Modificador.salidaDeBloque,
  Modificador.partido,
  Modificador.hipoxico,
];

class Renderizador {
  const Renderizador();

  /// Escribe una serie en la notación del entrenador.
  String serie(Serie serie) {
    final partes = <String>[];

    // Cabecera: `8×50` o `200`.
    partes.add(
      serie.repeticiones > 1
          ? '${serie.repeticiones}×${serie.distancia}'
          : '${serie.distancia}',
    );

    // Implementos, en orden fijo.
    for (final implemento in ordenDeImplementos) {
      if (serie.implementos.contains(implemento)) {
        partes.add(implemento.abreviatura);
      }
    }

    // Modificadores, en orden fijo. El hipóxico lleva su número.
    for (final modificador in ordenDeModificadores) {
      if (!serie.modificadores.contains(modificador)) continue;

      if (modificador == Modificador.hipoxico) {
        partes.add(
          serie.respiracionCada == null
              ? 'Hyp'
              : 'Hyp ${serie.respiracionCada}',
        );
      } else {
        partes.add(modificador.abreviatura);
      }
    }

    // Ejercicio, etiqueta de bloque técnico o nado completo.
    final ejercicio = serie.ejercicio;
    final bloque = serie.bloqueTecnico;

    if (ejercicio != null) {
      partes.add(ejercicio.nombreParaPlan);
    } else if (bloque != null) {
      partes.add(_etiquetaTecnica(bloque));
    } else if (serie.estilo != null) {
      partes.add(serie.estilo!.nombreDeNado);
    }

    // Zona, si está asignada.
    if (serie.zona != null) {
      partes.add('(${serie.zona!.abreviatura})');
    }

    // Tiempo de salida.
    final tiempo = serie.tiempoSalida;
    if (tiempo != null) {
      partes.add('/ ${_tiempo(tiempo)}');
    }

    return partes.join(' ');
  }

  /// Escribe todas las series de una parte, una por línea.
  String parte(Parte parte) => parte.series.map(serie).join('\n');

  /// Escribe una lista de series, una por línea.
  String series(List<Serie> lista) => lista.map(serie).join('\n');

  static String _etiquetaTecnica(Estilo estilo) {
    const etiquetas = <Estilo, String>{
      Estilo.libre: 'TEC L',
      Estilo.espalda: 'TEC E',
      Estilo.pecho: 'TEC P',
      Estilo.mariposa: 'TEC M',
      Estilo.general: 'TEC EST',
    };
    return etiquetas[estilo] ?? 'TEC EST';
  }

  /// `2'`, `1'30"` o `45"`, como en los documentos del entrenador.
  static String _tiempo(Duration duracion) {
    final minutos = duracion.inMinutes;
    final segundos = duracion.inSeconds % 60;

    if (minutos == 0) return '$segundos"';
    if (segundos == 0) return "$minutos'";
    return "$minutos'$segundos\"";
  }
}
