/// El historial se lee aunque la versión anterior ya no sea legible.
///
/// **Encontrado en el Pixel 7, y lo encontró el arreglo de antes.** Al
/// conectar `registrosDelLinaje` a la pantalla del nadador, a Ana le salió:
///
///     No se pudo cargar tu plan: No se pudo leer el plan UVOja…:
///     The caller does not have permission to execute the specified operation.
///
/// `firmarYEntregarElReajuste` **retira la asignación de la versión
/// anterior** —el nadador trabaja con una, y eso está bien—, y la regla de
/// planes se apoya en la asignación para dejar leer. Así que la versión vieja
/// deja de ser legible justo cuando hace falta para el historial.
///
/// En memoria no se nota: el doble no tiene reglas que romper. Otra vez la
/// misma forma.
///
/// Lo que el nadador sí puede leer siempre son **sus registros**: son suyos
/// por regla y no dependen del plan. Así que el recorrido deja de necesitar el
/// documento del plan para leer los registros de una versión — lo necesita
/// solo para saber cuál es la siguiente hacia atrás, y cuando no puede leerlo
/// devuelve lo que tiene en lugar de taparle la pantalla.
///
/// **Queda un límite y conviene decirlo:** con dos reajustes encadenados, la
/// generación más vieja se pierde de vista, porque para llegar a ella haría
/// falta leer un plan intermedio que tampoco es suyo. Quitarlo del todo es una
/// decisión de diseño —o no retirar la asignación, o ensanchar la regla— y no
/// se toma aquí.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/macrociclo/registros_del_linaje.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Un repositorio de planes que **niega uno**, como hace la regla con la
/// versión que el nadador ya no tiene asignada.
class _PlanesQueNiegan implements RepositorioPlanes {
  _PlanesQueNiegan(this._planes, this._negado);

  final Map<String, Plan> _planes;
  final String _negado;

  /// Para comprobar que se intentó, y no que se esquivó por casualidad.
  final pedidos = <String>[];

  @override
  Future<Plan?> obtener(String id) async {
    pedidos.add(id);
    if (id == _negado) {
      throw FalloDeDatos(
        'No se pudo leer el plan $id: The caller does not have permission '
        'to execute the specified operation.',
      );
    }
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

class _RegistrosEnMemoria implements RepositorioRegistros {
  final _guardados = <String, RegistroDeSesion>{};

  void sembrar(RegistroDeSesion registro) => _guardados[registro.id] = registro;

  @override
  Future<RegistroDeSesion?> obtener(String id) async => _guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async => _guardados.values
      .where((r) => r.nadadorId == nadadorId && r.planId == planId)
      .toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async => sembrar(registro);

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async => _guardados.clear();

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();
}

void main() {
  Plan mesociclo({required String id, String? desde}) => Plan(
    id: id,
    nombre: 'Mesociclo 1: Acumulación',
    categoria: Categoria.precompetitivo,
    estiloObjetivo: Estilo.libre,
    estado: EstadoPlan.publicado,
    versionMetodologia: '3.6.0',
    versionAnteriorId: desde,
  );

  RegistroDeSesion anotado(String planId, String sesionId) => RegistroDeSesion(
    nadadorId: 'n-ana',
    planId: planId,
    sesionId: sesionId,
    versionDePlan: '3.6.0',
    realizada: true,
    registradoEn: DateTime(2026, 11, 2),
  );

  late _RegistrosEnMemoria registros;
  late Plan version2;

  setUp(() {
    registros = _RegistrosEnMemoria();
    // Lo que anotó en la versión vieja, que es lo que no se puede perder.
    registros.sembrar(anotado('v1', 's-1'));
    registros.sembrar(anotado('v1', 's-2'));
    version2 = mesociclo(id: 'v2', desde: 'v1');
  });

  test(
    'se lee lo que anotó aunque el plan anterior no se pueda leer',
    () async {
      final planes = _PlanesQueNiegan({'v2': version2}, 'v1');

      final delLinaje = await registrosDelLinaje(
        mesociclo: version2,
        nadadorId: 'n-ana',
        registros: registros,
        planes: planes,
      );

      expect(
        delLinaje.map((r) => r.sesionId).toSet(),
        {'s-1', 's-2'},
        reason: 'sin el documento del plan anterior se perdía lo anotado en él',
      );
    },
  );

  test('no revienta: la pantalla del nadador no se cae por esto', () async {
    // Antes el fallo subía y le tapaba el plan entero con un mensaje en
    // inglés, en lugar de enseñarle su camino.
    final planes = _PlanesQueNiegan({'v2': version2}, 'v1');

    await expectLater(
      registrosDelLinaje(
        mesociclo: version2,
        nadadorId: 'n-ana',
        registros: registros,
        planes: planes,
      ),
      completes,
    );
  });

  test('y cuando sí se puede leer, sigue yendo más atrás', () async {
    // Que tolere la negativa no puede costar el caso normal.
    final v0 = mesociclo(id: 'v0');
    final v1 = mesociclo(id: 'v1', desde: 'v0');
    registros.sembrar(anotado('v0', 's-0'));

    final planes = _PlanesQueNiegan({
      'v2': version2,
      'v1': v1,
      'v0': v0,
    }, 'ninguno');

    final delLinaje = await registrosDelLinaje(
      mesociclo: version2,
      nadadorId: 'n-ana',
      registros: registros,
      planes: planes,
    );

    expect(delLinaje.map((r) => r.sesionId).toSet(), {'s-0', 's-1', 's-2'});
  });

  test('lo respondido en la versión más nueva sigue mandando', () async {
    // La regla de siempre, que el arreglo no puede tirar: si volvió a
    // contestar la misma sesión, esa es su última palabra.
    registros.sembrar(
      RegistroDeSesion(
        nadadorId: 'n-ana',
        planId: 'v2',
        sesionId: 's-1',
        versionDePlan: '3.6.0',
        realizada: false,
        registradoEn: DateTime(2026, 11, 20),
      ),
    );

    final planes = _PlanesQueNiegan({'v2': version2}, 'v1');

    final delLinaje = await registrosDelLinaje(
      mesociclo: version2,
      nadadorId: 'n-ana',
      registros: registros,
      planes: planes,
    );

    final suya = delLinaje.firstWhere((r) => r.sesionId == 's-1');
    expect(suya.realizada, isFalse, reason: 'ganó la versión vieja');
  });
}
