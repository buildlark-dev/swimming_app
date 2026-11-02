/// Biblioteca Oficial de ejercicios.
///
/// Regla R2 de la metodología (no invención): solo pueden usarse los
/// ejercicios de esta biblioteca. La búsqueda es por **coincidencia exacta**.
/// No hay sinónimos, ni corrección automática, ni sugerencias de "quizá quiso
/// decir": un nombre que no coincide se reporta como fuera de biblioteca
/// (FR-002).
library;

import 'package:natacion_app/dominio/biblioteca/ejercicio.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Resultado de buscar un ejercicio por su nombre.
sealed class ResultadoBusqueda {
  const ResultadoBusqueda();
}

/// Se encontró exactamente uno.
class EjercicioEncontrado extends ResultadoBusqueda {
  const EjercicioEncontrado(this.ejercicio);

  final Ejercicio ejercicio;
}

/// El nombre existe en varios estilos y no se indicó cuál.
class EjercicioAmbiguo extends ResultadoBusqueda {
  const EjercicioAmbiguo(this.nombreBase, this.estilosPosibles);

  final String nombreBase;
  final List<Estilo> estilosPosibles;
}

/// El nombre no está en la biblioteca.
class EjercicioNoEncontrado extends ResultadoBusqueda {
  const EjercicioNoEncontrado(this.nombre);

  final String nombre;
}

class Biblioteca {
  Biblioteca(List<Ejercicio> ejercicios)
    : _ejercicios = List.unmodifiable(ejercicios) {
    for (final ejercicio in _ejercicios) {
      final clave = _normalizar(ejercicio.nombreBase);
      _porNombreBase.putIfAbsent(clave, () => <Ejercicio>[]).add(ejercicio);
    }
  }

  final List<Ejercicio> _ejercicios;
  final Map<String, List<Ejercicio>> _porNombreBase = {};

  List<Ejercicio> get todos => _ejercicios;

  int get cantidad => _ejercicios.length;

  /// Normaliza solo mayúsculas y espacios. **No** corrige tildes ni acepta
  /// nombres parecidos: la regla de no invención exige coincidencia exacta.
  static String _normalizar(String texto) =>
      texto.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Busca un ejercicio por su nombre, opcionalmente con el estilo indicado.
  ///
  /// - Si el nombre no existe: [EjercicioNoEncontrado].
  /// - Si existe en varios estilos y no se indicó estilo: [EjercicioAmbiguo].
  /// - Si existe y el estilo resuelve la ambigüedad: [EjercicioEncontrado].
  ResultadoBusqueda buscar(String nombre, {Estilo? estilo}) {
    final consulta = _normalizar(nombre);

    // El nombre puede venir ya desambiguado: "FLECHA (Espalda)".
    final coincidencia = RegExp(
      r'^(.*?)\s*\((.+)\)$',
    ).firstMatch(nombre.trim());
    if (coincidencia != null) {
      final base = _normalizar(coincidencia.group(1)!);
      final estiloIndicado = Estilo.porNombre(coincidencia.group(2)!);
      if (estiloIndicado != null) {
        return _resolver(base, estiloIndicado, nombre);
      }
    }

    return _resolver(consulta, estilo, nombre);
  }

  ResultadoBusqueda _resolver(
    String nombreBase,
    Estilo? estilo,
    String nombreOriginal,
  ) {
    final candidatos = _porNombreBase[nombreBase];
    if (candidatos == null || candidatos.isEmpty) {
      return EjercicioNoEncontrado(nombreOriginal.trim());
    }

    if (candidatos.length == 1) {
      final unico = candidatos.first;
      // Un ejercicio de un solo estilo se acepta aunque no se indique estilo.
      if (estilo == null ||
          unico.estilo == estilo ||
          unico.estilo == Estilo.general) {
        return EjercicioEncontrado(unico);
      }
      return EjercicioEncontrado(unico);
    }

    if (estilo == null) {
      return EjercicioAmbiguo(
        candidatos.first.nombreBase,
        candidatos.map((e) => e.estilo).toList(),
      );
    }

    for (final candidato in candidatos) {
      if (candidato.estilo == estilo) return EjercicioEncontrado(candidato);
    }

    return EjercicioAmbiguo(
      candidatos.first.nombreBase,
      candidatos.map((e) => e.estilo).toList(),
    );
  }

  /// Verdadero si el nombre base existe, sin importar el estilo. Lo usa el
  /// analizador para distinguir "esto parece un ejercicio pero está mal
  /// escrito" de "esto no es un ejercicio".
  bool conoceNombreBase(String nombre) =>
      _porNombreBase.containsKey(_normalizar(nombre));

  List<Ejercicio> porEstilo(Estilo estilo) =>
      _ejercicios.where((e) => e.estilo == estilo).toList();

  /// Ejercicios que corrigen un error concreto del diagnóstico (sección 15).
  List<Ejercicio> queCorrigen(String textoError) {
    final buscado = textoError.toLowerCase();
    return _ejercicios
        .where((e) => e.errorQueCorrige.toLowerCase().contains(buscado))
        .toList();
  }

  factory Biblioteca.desdeJson(Map<String, dynamic> json) {
    final lista = (json['ejercicios'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Ejercicio.desdeJson)
        .toList();
    return Biblioteca(lista);
  }
}
