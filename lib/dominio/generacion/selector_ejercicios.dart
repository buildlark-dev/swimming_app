/// Selección de ejercicios de la Biblioteca Oficial.
///
/// Dos caminos, según haya diagnóstico o no (FR-021, FR-022):
///
/// - **Con diagnóstico**: se eligen ejercicios cuyo «error que corrige»
///   corresponda a los errores observados.
/// - **Sin diagnóstico**: se sigue la progresión técnica de la sección 15, sin
///   inventar errores que nadie observó.
///
/// En ambos casos el recorrido es **estable**: dado el mismo conjunto de
/// entrada, el mismo ejercicio. La rotación entre sesiones se hace por
/// posición, nunca por azar.
///
/// Cuando un error diagnosticado no tiene ejercicio que lo corrija, se reporta
/// el vacío y **no se sustituye** por otro (FR-023). Elegir un ejercicio
/// aproximado sería inventar por otra vía.
library;

import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/ejercicio.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Progresión técnica de la sección 15, en orden.
///
/// Se usa cuando no hay diagnóstico: son los términos que se buscan, en este
/// orden, dentro del campo de error que corrige.
const List<String> progresionTecnica = [
  'patada',
  'posición corporal',
  'control corporal',
  'respiración',
  'tracción',
  'brazada',
  'recobro',
  'deslizamiento',
];

/// Lo que devuelve el selector.
class SeleccionEjercicios {
  const SeleccionEjercicios({
    required this.ejercicios,
    this.vacios = const <VacioDeBiblioteca>[],
  });

  final List<Ejercicio> ejercicios;
  final List<VacioDeBiblioteca> vacios;

  bool get estaVacia => ejercicios.isEmpty;
}

class SelectorEjercicios {
  SelectorEjercicios(this.biblioteca, {IndiceTerminos? indice})
    : indice = indice ?? IndiceTerminos.vacio();

  final Biblioteca biblioteca;

  /// Vocabulario de diagnóstico declarado por el entrenador.
  ///
  /// Sin índice, ningún diagnóstico encuentra ejercicio y todos se reportan
  /// como vacío. Es el comportamiento correcto: antes de que el entrenador
  /// declare sus términos, la app no tiene con qué elegir y no debe adivinar.
  final IndiceTerminos indice;

  /// Elige ejercicios para un estilo, atendiendo al diagnóstico si lo hay.
  ///
  /// [cuantos] es el número de ejercicios distintos que se quieren.
  SeleccionEjercicios elegir({
    required Estilo estilo,
    required List<String> diagnostico,
    required int cuantos,
    int desplazamiento = 0,
  }) {
    if (diagnostico.isEmpty) {
      return SeleccionEjercicios(
        ejercicios: _porProgresion(estilo, cuantos, desplazamiento),
      );
    }
    return _porDiagnostico(estilo, diagnostico, cuantos, desplazamiento);
  }

  /// Ejercicios del estilo que corrigen alguno de los errores observados.
  SeleccionEjercicios _porDiagnostico(
    Estilo estilo,
    List<String> diagnostico,
    int cuantos,
    int desplazamiento,
  ) {
    final elegidos = <Ejercicio>[];
    final vacios = <VacioDeBiblioteca>[];

    for (final error in diagnostico) {
      final candidatos = _paraElDiagnostico(estilo, error);

      if (candidatos.isEmpty) {
        vacios.add(
          VacioDeBiblioteca(errorDiagnosticado: error, estilo: estilo),
        );
        continue;
      }

      for (final candidato in candidatos) {
        if (!elegidos.contains(candidato)) elegidos.add(candidato);
      }
    }

    if (elegidos.isEmpty) {
      // Con diagnóstico pero sin ejercicios que lo cubran, se recurre a la
      // progresión estándar para que la sesión tenga trabajo técnico. El
      // vacío ya queda reportado.
      return SeleccionEjercicios(
        ejercicios: _porProgresion(estilo, cuantos, desplazamiento),
        vacios: vacios,
      );
    }

    return SeleccionEjercicios(
      ejercicios: _tomarRotando(elegidos, cuantos, desplazamiento),
      vacios: vacios,
    );
  }

  /// Ejercicios del estilo en el orden de la progresión de la sección 15.
  List<Ejercicio> _porProgresion(
    Estilo estilo,
    int cuantos,
    int desplazamiento,
  ) {
    final ordenados = <Ejercicio>[];

    for (final etapa in progresionTecnica) {
      for (final ejercicio in _queCorrigen(estilo, etapa)) {
        if (!ordenados.contains(ejercicio)) ordenados.add(ejercicio);
      }
    }

    // Los que no encajan en ninguna etapa van al final, en el orden de la
    // Biblioteca, para que el recorrido siga siendo estable y completo.
    for (final ejercicio in _delEstilo(estilo)) {
      if (!ordenados.contains(ejercicio)) ordenados.add(ejercicio);
    }

    return _tomarRotando(ordenados, cuantos, desplazamiento);
  }

  /// Ejercicios que corresponden a un error **diagnosticado**.
  ///
  /// Van por el índice de términos, no por la prosa de la ficha: el entrenador
  /// declara cómo nombra cada error y a qué ejercicio lleva, en su orden de
  /// prioridad. Una frase que no esté declarada devuelve lista vacía, y quien
  /// llama la reporta como vacío de Biblioteca (tarea T070).
  ///
  /// Los nombres del índice se resuelven contra la Biblioteca: si uno no
  /// existe, se ignora en silencio aquí, pero hay una prueba que impide que el
  /// índice referencie ejercicios inexistentes.
  List<Ejercicio> _paraElDiagnostico(Estilo estilo, String error) {
    final nombres = indice.ejerciciosPara(estilo: estilo, frase: error);
    if (nombres.isEmpty) return const [];

    final delEstilo = _delEstilo(estilo);
    final encontrados = <Ejercicio>[];

    // Se recorre el índice, no la Biblioteca: así se conserva el orden de
    // prioridad que declaró el entrenador.
    for (final nombre in nombres) {
      for (final ejercicio in delEstilo) {
        if (ejercicio.nombre == nombre && !encontrados.contains(ejercicio)) {
          encontrados.add(ejercicio);
        }
      }
    }

    return encontrados;
  }

  /// Ejercicios del estilo cuyo error corregido menciona [termino].
  ///
  /// Se usa **solo para la progresión técnica de la sección 15**, donde los
  /// términos son los del documento y no los del entrenador. El camino del
  /// diagnóstico va por [_paraElDiagnostico].
  List<Ejercicio> _queCorrigen(Estilo estilo, String termino) {
    final buscado = _normalizar(termino);
    if (buscado.isEmpty) return const [];

    return _delEstilo(
      estilo,
    ).where((e) => _normalizar(e.errorQueCorrige).contains(buscado)).toList();
  }

  /// Ejercicios del estilo, más los generales, en el orden de la Biblioteca.
  List<Ejercicio> _delEstilo(Estilo estilo) => biblioteca.todos
      .where((e) => e.estilo == estilo || e.estilo == Estilo.general)
      .toList();

  /// Toma [cuantos] elementos empezando en [desplazamiento], dando la vuelta.
  ///
  /// Es lo que hace que dos sesiones de la misma semana no repitan los mismos
  /// ejercicios, sin usar azar.
  List<Ejercicio> _tomarRotando(
    List<Ejercicio> origen,
    int cuantos,
    int desplazamiento,
  ) {
    if (origen.isEmpty || cuantos <= 0) return const [];

    return [
      for (var i = 0; i < cuantos && i < origen.length; i++)
        origen[(desplazamiento + i) % origen.length],
    ];
  }

  static String _normalizar(String texto) => texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .trim();
}
