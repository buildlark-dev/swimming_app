/// Estado del editor de sesión.
///
/// Mantiene el árbol vivo —sesión, partes, series— y reinterpreta y recalcula
/// a medida que el entrenador escribe. Es la razón declarada para depender de
/// `provider` (decisión D8 de `research.md`).
library;

import 'package:flutter/foundation.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/calculo/calculo_sesion.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class EstadoEditor extends ChangeNotifier {
  EstadoEditor({
    required Biblioteca biblioteca,
    Categoria categoria = Categoria.precompetitivo,
    this.repositorio,
    this.planId,
  }) : _analizador = Analizador(biblioteca: biblioteca),
       _sesion = Sesion() {
    _categoria = categoria;
  }

  final Analizador _analizador;

  /// Opcional: sin repositorio el editor funciona igual, solo que no guarda.
  final RepositorioSesiones? repositorio;
  final String? planId;

  Sesion _sesion;
  Categoria _categoria = Categoria.precompetitivo;

  Sesion get sesion => _sesion;
  Categoria get categoria => _categoria;

  CalculoSesion get calculo => CalculoSesion(_sesion);

  ComprobacionVolumen get volumen => calculo.comprobarVolumen(_categoria);

  List<FragmentoPendiente> get pendientes => _sesion.todosLosPendientes;

  List<String> avisos = <String>[];

  void cambiarCategoria(Categoria nueva) {
    _categoria = nueva;
    notifyListeners();
  }

  void cambiarObjetivoTecnico(String texto) {
    _sesion = _sesion.copiarCon(objetivoTecnico: texto);
    notifyListeners();
  }

  void cambiarObjetivoFisiologico(String texto) {
    _sesion = _sesion.copiarCon(objetivoFisiologico: texto);
    notifyListeners();
  }

  void cambiarRpe(int? rpe) {
    _sesion = _sesion.copiarCon(rpePrevisto: rpe);
    notifyListeners();
  }

  /// Reinterpreta el texto de una parte.
  ///
  /// Las series con campos corregidos a mano conservan esos valores: una
  /// reinterpretación no los sobrescribe (FR-035).
  void escribirParte(TipoParte tipo, String texto) {
    final anterior = _sesion.parteDe(tipo);
    final resultado = _analizador.analizar(texto);

    final fusionadas = _fusionarCorrecciones(anterior.series, resultado.series);

    _sesion = _sesion.conParte(
      anterior.copiarCon(
        textoOriginal: texto,
        series: fusionadas,
        fragmentosPendientes: resultado.pendientes,
      ),
    );
    avisos = resultado.avisos;
    notifyListeners();
  }

  /// Conserva los campos que el entrenador corrigió a mano, emparejando por
  /// posición dentro de la parte.
  List<Serie> _fusionarCorrecciones(
    List<Serie> anteriores,
    List<Serie> nuevas,
  ) {
    final resultado = <Serie>[];

    for (var i = 0; i < nuevas.length; i++) {
      var serie = nuevas[i];
      if (i < anteriores.length) {
        final previa = anteriores[i];
        if (previa.camposCorregidos.isNotEmpty) {
          serie = serie.copiarCon(
            repeticiones: previa.estaProtegido('repeticiones')
                ? previa.repeticiones
                : null,
            distancia: previa.estaProtegido('distancia')
                ? previa.distancia
                : null,
            zona: previa.estaProtegido('zona') ? previa.zona : null,
            estilo: previa.estaProtegido('estilo') ? previa.estilo : null,
            camposCorregidos: previa.camposCorregidos,
            origen: previa.origen,
          );
        }
      }
      resultado.add(serie);
    }

    return resultado;
  }

  /// Corrige a mano un campo de una serie. La corrección prevalece.
  void corregirSerie(
    TipoParte tipo,
    int indice,
    String campo, {
    int? valorEntero,
    Zona? zona,
    Estilo? estilo,
  }) {
    final parte = _sesion.parteDe(tipo);
    if (indice < 0 || indice >= parte.series.length) return;

    final series = List<Serie>.from(parte.series);
    series[indice] = series[indice].corregir(
      campo,
      valorEntero: valorEntero,
      zona: zona,
      estilo: estilo,
    );

    _sesion = _sesion.conParte(parte.copiarCon(series: series));
    notifyListeners();
  }

  /// Asigna la zona de intensidad de una serie. La asigna el entrenador: el
  /// analizador no la adivina (FR-011).
  void asignarZona(TipoParte tipo, int indice, Zona zona) {
    corregirSerie(tipo, indice, 'zona', zona: zona);
  }

  bool get puedeGuardar => repositorio != null && planId != null;

  String? ultimoError;

  /// Guarda la sesión con su texto original, sus series interpretadas, sus
  /// fragmentos pendientes y el origen de cada serie (FR-035 a FR-037).
  ///
  /// Se guarda aunque esté incompleta: es un borrador de trabajo. Lo que no se
  /// puede es aprobar un plan con sesiones incompletas.
  Future<bool> guardar() async {
    final destino = repositorio;
    final plan = planId;
    if (destino == null || plan == null) return false;

    try {
      final id = await destino.guardar(plan, _sesion);
      _sesion = _sesion.copiarCon(id: id);
      ultimoError = null;
      notifyListeners();
      return true;
    } on FalloDeDatos catch (e) {
      ultimoError = e.mensaje;
      notifyListeners();
      return false;
    }
  }

  /// Recupera una sesión guardada para seguir editándola.
  Future<void> cargar(Sesion sesion) async {
    _sesion = sesion;
    notifyListeners();
  }

  /// Sesiones de un microciclo generado que se están revisando, y cuál está
  /// abierta. Vacío cuando el entrenador escribe a mano.
  List<Sesion> _sesionesDelPlan = const [];
  int _indiceAbierta = 0;

  List<Sesion> get sesionesDelPlan => _sesionesDelPlan;
  int get indiceAbierta => _indiceAbierta;

  /// Verdadero cuando lo que se está editando vino de una generación.
  bool get revisandoGenerado => _sesionesDelPlan.isNotEmpty;

  Plan? _planGenerado;

  /// El plan que se está revisando, con lo editado ya aplicado.
  ///
  /// Hace falta conservarlo entero —y no solo sus sesiones— porque aprobarlo y
  /// publicarlo son transiciones **del plan**: necesitan su categoría, su fase,
  /// su estilo objetivo y su estado. Sin esto, lo generado se quedaba en el
  /// editor y no había forma de entregárselo a nadie.
  Plan? get planRevisado {
    final plan = _planGenerado;
    if (plan == null) return null;

    // Las sesiones se toman del editor, con la abierta al día: lo que el
    // entrenador corrigió a mano prevalece.
    final sesiones = List<Sesion>.from(_sesionesDelPlan);
    if (_indiceAbierta < sesiones.length) {
      sesiones[_indiceAbierta] = _sesion;
    }

    return plan.copiarCon(sesiones: sesiones);
  }

  /// Abre un microciclo generado para revisarlo.
  ///
  /// El editor pasa de ser la forma de crear a ser la forma de revisar, que es
  /// lo que la feature 002 persigue.
  void abrirGenerado(Plan plan) {
    _planGenerado = plan;
    _sesionesDelPlan = List<Sesion>.from(plan.sesiones);
    _indiceAbierta = 0;
    _categoria = plan.categoria;
    _sesion = _sesionesDelPlan.isEmpty ? Sesion() : _sesionesDelPlan.first;
    notifyListeners();
  }

  /// Cambia de sesión dentro del microciclo, conservando lo editado en la que
  /// se abandona.
  void abrirSesion(int indice) {
    if (indice < 0 || indice >= _sesionesDelPlan.length) return;

    _sesionesDelPlan[_indiceAbierta] = _sesion;
    _indiceAbierta = indice;
    _sesion = _sesionesDelPlan[indice];
    notifyListeners();
  }
}
