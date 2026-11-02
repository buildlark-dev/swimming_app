/// Glosario de la notación del entrenador.
///
/// Fuente normativa: sección 10 de `docs/metodologia/PROMPT_MAESTRO_V3.4.md`.
///
/// Un término ausente del glosario y de la Biblioteca se trata como
/// desconocido: se pregunta, no se supone (regla R3). El entrenador puede
/// incorporar términos aclarados, que quedan registrados con su fecha.
library;

import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Término que el entrenador aclaró y se incorporó al glosario.
class TerminoGlosario {
  const TerminoGlosario({
    required this.termino,
    required this.definicion,
    required this.fechaIncorporacion,
  });

  final String termino;
  final String definicion;
  final DateTime fechaIncorporacion;
}

class Glosario {
  Glosario({List<TerminoGlosario> incorporados = const []})
    : _incorporados = {
        for (final termino in incorporados)
          _normalizar(termino.termino): termino,
      };

  final Map<String, TerminoGlosario> _incorporados;

  static String _normalizar(String texto) => texto.trim().toUpperCase();

  /// Implementos de la sección 10.
  static const Map<String, Implemento> implementos = {
    'AL': Implemento.aletas,
    'PL': Implemento.palas,
    'PP': Implemento.palasPequenas,
    'PULL': Implemento.pullBuoy,
    'PU': Implemento.pullBuoy,
    'SNK': Implemento.snorkel,
    'PARAC': Implemento.paracaidas,
    'CAUCHO': Implemento.caucho,
  };

  /// Modificadores de ejecución de la sección 10.
  static const Map<String, Modificador> modificadores = {
    'PN': Modificador.patada,
    'PAT': Modificador.patada,
    'PATADA': Modificador.patada,
    'BR': Modificador.brazada,
    'BRAZ': Modificador.brazada,
    'UW': Modificador.subacuatico,
    'REC': Modificador.recuperacion,
    '1<4': Modificador.progresivo,
    'PROG': Modificador.progresivo,
    '1>4': Modificador.regresivo,
    '^': Modificador.salidaDeBloque,
    'PARTIDO': Modificador.partido,
  };

  /// Abreviaturas de estilo admitidas dentro de una serie.
  static const Map<String, Estilo> estilos = {
    'L': Estilo.libre,
    'LIBRE': Estilo.libre,
    'E': Estilo.espalda,
    'ESPALDA': Estilo.espalda,
    'P': Estilo.pecho,
    'PECHO': Estilo.pecho,
    'M': Estilo.mariposa,
    'MARIPOSA': Estilo.mariposa,
    'CI': Estilo.combinado,
  };

  /// Etiquetas de bloque técnico válidas (sección 8). Solo como etiqueta de un
  /// bloque, nunca como nombre de un nado completo.
  static const Map<String, Estilo> etiquetasTecnicas = {
    'TEC L': Estilo.libre,
    'TEC E': Estilo.espalda,
    'TEC P': Estilo.pecho,
    'TEC M': Estilo.mariposa,
    'TEC EST': Estilo.general,
  };

  /// Notación en desuso: si aparece en documentos históricos se ignora, sin
  /// bloquear (sección 10).
  static const Set<String> enDesuso = {'FC1', 'FC2'};

  /// Formas de nado prohibidas por la sección 8.
  static const List<String> nombresDeNadoProhibidos = [
    'libre técnico',
    'libre tecnico',
    'espalda técnica',
    'espalda tecnica',
    'pecho técnico',
    'pecho tecnico',
    'mariposa técnica',
    'mariposa tecnica',
    'pecho asistido',
    'libre corregido',
    'pecho corregido',
    'espalda corregida',
    'mariposa corregida',
  ];

  bool conoce(String termino) {
    final clave = _normalizar(termino);
    return implementos.containsKey(clave) ||
        modificadores.containsKey(clave) ||
        estilos.containsKey(clave) ||
        enDesuso.contains(clave) ||
        _incorporados.containsKey(clave);
  }

  bool estaEnDesuso(String termino) => enDesuso.contains(_normalizar(termino));

  Implemento? implemento(String termino) => implementos[_normalizar(termino)];

  Modificador? modificador(String termino) =>
      modificadores[_normalizar(termino)];

  Estilo? estilo(String termino) => estilos[_normalizar(termino)];

  TerminoGlosario? incorporado(String termino) =>
      _incorporados[_normalizar(termino)];

  /// Devuelve un glosario nuevo con el término incorporado (FR-006).
  Glosario incorporar(TerminoGlosario termino) {
    return Glosario(incorporados: [..._incorporados.values, termino]);
  }

  /// Verdadero si el texto contiene una forma de nado prohibida.
  static String? formaProhibidaEn(String texto) {
    final minusculas = texto.toLowerCase();
    for (final prohibida in nombresDeNadoProhibidos) {
      if (minusculas.contains(prohibida)) return prohibida;
    }
    return null;
  }
}
