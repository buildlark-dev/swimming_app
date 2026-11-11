/// Los dobles que comparten las pruebas de la lectura del entrenador.
///
/// Van en un archivo propio porque las cinco pruebas de esta carpeta siembran
/// lo mismo —un macrociclo con dos mesociclos y unos registros— y copiarlo
/// cinco veces hace que un arreglo tenga que acertar cinco sitios.
///
/// **Y llevan un aviso.** Estos dobles no tienen reglas que romper: seis de los
/// siete defectos de la feature 009 eran exactamente eso, un doble más amable
/// que Firestore. Lo que se prueba aquí es el cálculo; lo que se prueba contra
/// el servidor son las reglas, en `firebase/test/`, y el recorrido del Pixel 7
/// está en `quickstart.md` porque ninguno de los dos lo ve todo.
library;

import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

Nadador ana() => Nadador(
  id: 'n-ana',
  nombre: 'Ana',
  fechaNacimiento: DateTime(2012, 4, 3),
  categoria: Categoria.precompetitivo,
  estiloObjetivo: Estilo.libre,
);

/// Una sesión con metros de verdad, para que la carga externa exista.
Sesion sesionDe({
  required String id,
  required DateTime? fecha,
  String microcicloId = 'micro-1',
  int metros = 2000,
}) => Sesion(
  id: id,
  microcicloId: microcicloId,
  fecha: fecha,
  objetivoTecnico: 'Viraje',
  objetivoFisiologico: 'Umbral',
  partes: [
    const Parte(tipo: TipoParte.inicial),
    Parte(
      tipo: TipoParte.central,
      series: [
        Serie(
          repeticiones: 1,
          distancia: metros,
          estilo: Estilo.libre,
          zona: Zona.a2,
        ),
      ],
    ),
    const Parte(tipo: TipoParte.cierre),
  ],
);

Plan mesociclo({
  required String id,
  required List<Sesion> sesiones,
  String? versionAnteriorId,
  int orden = 0,
  String versionMetodologia = '3.6.0',
  EstadoPlan estado = EstadoPlan.publicado,
}) => Plan(
  id: id,
  nombre: 'Mesociclo ${orden + 1}',
  categoria: Categoria.precompetitivo,
  estiloObjetivo: Estilo.libre,
  sesiones: sesiones,
  estado: estado,
  versionMetodologia: versionMetodologia,
  versionAnteriorId: versionAnteriorId,
  macrocicloId: 'macro-1',
  ordenEnElMacrociclo: orden,
  fechaInicio: sesiones.isEmpty ? null : sesiones.first.fecha,
  fechaFin: sesiones.isEmpty ? null : sesiones.last.fecha,
);

RegistroDeSesion registroDe({
  required String sesionId,
  required String planId,
  bool realizada = true,
  int? rpe,
  String observaciones = '',
  ReporteDeMolestia? molestia,
  DateTime? cuando,
}) => RegistroDeSesion(
  nadadorId: 'n-ana',
  planId: planId,
  sesionId: sesionId,
  versionDePlan: planId,
  realizada: realizada,
  registradoEn: cuando ?? DateTime(2026, 11, 2),
  rpePercibido: rpe,
  observaciones: observaciones,
  molestia: molestia,
);

/// Registros en memoria. Siembra por plan, como vienen del servidor.
class RegistrosDeMentira implements RepositorioRegistros {
  final _guardados = <String, RegistroDeSesion>{};

  /// Qué planes se preguntaron, para comprobar que se recorrió el linaje y no
  /// se acertó por casualidad.
  final pedidos = <String>[];

  void sembrar(RegistroDeSesion registro) => _guardados[registro.id] = registro;

  @override
  Future<RegistroDeSesion?> obtener(String id) async => _guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async {
    pedidos.add(planId);
    return _guardados.values
        .where((r) => r.nadadorId == nadadorId && r.planId == planId)
        .toList();
  }

  @override
  Future<void> guardar(RegistroDeSesion registro) async => sembrar(registro);

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async {}

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();
}

/// Registros que **fallan al leer**, como un servidor sin permiso o sin red.
class RegistrosQueFallan implements RepositorioRegistros {
  const RegistrosQueFallan([this.porQue = 'No se pudieron leer los registros']);

  final String porQue;

  @override
  Future<RegistroDeSesion?> obtener(String id) async =>
      throw FalloDeDatos(porQue);

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async =>
      throw FalloDeDatos(porQue);

  @override
  Future<void> guardar(RegistroDeSesion registro) async {}

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async {}

  @override
  Future<Set<String>> nadadoresConRegistros() async => const {};
}

class PlanesDeMentira implements RepositorioPlanes {
  PlanesDeMentira([Iterable<Plan> planes = const []]) {
    for (final plan in planes) {
      if (plan.id != null) _planes[plan.id!] = plan;
    }
  }

  final _planes = <String, Plan>{};

  final pedidos = <String>[];

  void sembrar(Plan plan) {
    if (plan.id != null) _planes[plan.id!] = plan;
  }

  @override
  Future<Plan?> obtener(String id) async {
    pedidos.add(id);
    return _planes[id];
  }

  @override
  Future<List<Plan>> listar({Categoria? categoria, EstadoPlan? estado}) async =>
      _planes.values.toList();

  @override
  Future<String> guardarBorrador(Plan plan) async => plan.id ?? 'p';

  @override
  Future<void> guardarAprobado(Plan plan, Map<String, dynamic> a) async {}

  @override
  Future<void> publicar(String id) async {}

  @override
  Future<Plan> crearVersionDesde(String id) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> exportar(String id) async => {};
}
