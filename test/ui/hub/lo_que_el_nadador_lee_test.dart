/// De dónde lee el nadador lo suyo.
///
/// **El comportamiento está fijado en
/// `test/datos/su_historial_viaja_con_ella_test.dart`.** Esto fija lo otro:
/// que el HUB le dé esa lectura y no la de un solo aparato.
///
/// Es la mitad que se rompió de verdad. `RegistrosDeLasDosPartes` no existía,
/// pero `RegistrosFirestore` sí desde la feature 007, sabía leer, y nadie lo
/// usaba para él: la pieza estaba escrita y sin conectar. Esta feature ya ha
/// encontrado dos iguales —`registrosDelLinaje` y el camino de vuelta al
/// macrociclo—, así que lo que hay que vigilar no es que la clase funcione,
/// es que esté enchufada.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/registros_de_las_dos_partes.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/hub/repositorios_del_hub.dart';

class _Registros implements RepositorioRegistros {
  final guardados = <String, RegistroDeSesion>{};

  void sembrar(RegistroDeSesion registro) => guardados[registro.id] = registro;

  @override
  Future<RegistroDeSesion?> obtener(String id) async => guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async => guardados.values
      .where((r) => r.nadadorId == nadadorId && r.planId == planId)
      .toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async => sembrar(registro);

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async => guardados.clear();

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      guardados.values.map((r) => r.nadadorId).toSet();
}

void main() {
  RegistroDeSesion anotado(String sesionId) => RegistroDeSesion(
    nadadorId: 'n-ana',
    planId: 'p1',
    sesionId: sesionId,
    versionDePlan: '3.6.0',
    realizada: true,
    registradoEn: DateTime(2026, 11, 2),
  );

  RepositoriosDelHub conServidor(
    RepositorioRegistros local,
    RepositorioRegistros? servidor,
  ) => RepositoriosDelHub(
    planes: RepositorioPlanesMemoria(),
    sesiones: RepositorioSesionesMemoria(),
    nadadores: RepositorioNadadoresMemoria(),
    asignaciones: RepositorioAsignacionesMemoria(),
    macrociclos: RepositorioMacrociclosMemoria(),
    registrosLocales: local,
    registrosDelServidor: servidor,
  );

  test('con servidor, lee de los dos lados', () async {
    // El caso del teléfono nuevo: el almacén está vacío y el servidor tiene lo
    // que ella anotó en el anterior.
    final local = _Registros();
    final servidor = _Registros()..sembrar(anotado('s-1'));

    final suyos = await conServidor(
      local,
      servidor,
    ).registrosDelNadador.obtenerDePlan('n-ana', 'p1');

    expect(suyos.map((r) => r.sesionId).toList(), [
      's-1',
    ], reason: 'el HUB le seguía dando solo el almacén de este aparato');
  });

  test('y es la unión de verdad, no el servidor a secas', () {
    final local = _Registros();
    final servidor = _Registros();

    expect(
      conServidor(local, servidor).registrosDelNadador,
      isA<RegistrosDeLasDosPartes>(),
    );
  });

  test('sin servidor se queda en lo local, que es lo único que hay', () {
    // En modo local no hay a quién preguntar, y pedirlo sería un fallo por
    // cada lectura.
    final local = _Registros();

    expect(conServidor(local, null).registrosDelNadador, same(local));
  });

  test('escribir sigue siendo cosa del dispositivo', () async {
    // La garantía G1 no se toca: lo que el HUB le da para leer no puede haber
    // convertido anotar en algo que espera a la red.
    final local = _Registros();
    final servidor = _Registros();

    await conServidor(
      local,
      servidor,
    ).registrosDelNadador.guardar(anotado('s-1'));

    expect(local.guardados, hasLength(1));
    expect(servidor.guardados, isEmpty);
  });
}
