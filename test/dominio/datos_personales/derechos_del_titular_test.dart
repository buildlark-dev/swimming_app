import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/datos_personales/derechos_del_titular.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Los derechos del titular: saber, llevarse y borrar.
///
/// La prueba que más importa es **SC-014**: eliminar los datos de un nadador
/// no puede llevarse por delante el trabajo del entrenador. Un microciclo es
/// su obra profesional, y borrar lo de un niño no puede costarle la temporada.
void main() {
  late RepositorioNadadoresMemoria nadadores;
  late _RegistrosEnMemoria registros;
  late RepositorioAsignacionesMemoria asignaciones;
  late RepositorioPlanesMemoria planes;
  late DerechosDelTitular derechos;

  setUp(() {
    nadadores = RepositorioNadadoresMemoria();
    registros = _RegistrosEnMemoria();
    asignaciones = RepositorioAsignacionesMemoria();
    planes = RepositorioPlanesMemoria();
    derechos = DerechosDelTitular(
      nadadores: nadadores,
      registros: registros,
      asignaciones: asignaciones,
    );
  });

  Future<String> unNadador({
    String nombre = 'Nadador de prueba',
    DateTime? fechaNacimiento,
  }) =>
      nadadores.guardar(
        Nadador(
          nombre: nombre,
          fechaNacimiento: fechaNacimiento,
          categoria: Categoria.iniciacion,
          estiloObjetivo: Estilo.libre,
        ),
      );

  Future<String> unPlanEntregadoA(String nadadorId) async {
    final planId = await planes.guardarBorrador(
      Plan(
        nombre: 'Microciclo del entrenador',
        categoria: Categoria.iniciacion,
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '100 Libre',
        estado: EstadoPlan.borrador,
        sesiones: const [],
      ),
    );

    await asignaciones.asignar(
      Asignacion(
        planId: planId,
        nadadorId: nadadorId,
        asignadaEn: DateTime(2026, 10, 15),
      ),
    );

    return planId;
  }

  Future<void> respuesta(
    String nadadorId,
    String planId,
    String sesionId, {
    bool conMolestia = false,
  }) =>
      registros.guardar(
        RegistroDeSesion(
          nadadorId: nadadorId,
          planId: planId,
          sesionId: sesionId,
          versionDePlan: '3.6.0',
          realizada: true,
          registradoEn: DateTime(2026, 10, 15),
          rpePercibido: 7,
          molestia: conMolestia
              ? const ReporteDeMolestia(
                  descripcion: 'Pinchazo',
                  zonaDelCuerpo: 'hombro derecho',
                )
              : null,
        ),
      );

  group('FR-036 — saber qué se guarda, en palabras', () {
    test('cuenta lo que hay sin volcar la base de datos', () async {
      final id = await unNadador(nombre: 'Ana', fechaNacimiento: DateTime(2017, 5, 1));
      final planId = await unPlanEntregadoA(id);
      await respuesta(id, planId, 's1');
      await respuesta(id, planId, 's2', conMolestia: true);

      final que = await derechos.queSeGuardaDe(id);

      expect(que!.nombre, 'Ana');
      expect(que.constaFechaDeNacimiento, isTrue);
      expect(que.planesEntregados, 1);
      expect(que.sesionesRespondidas, 2);
      expect(que.conReporteDeMolestia, 1);
    });

    test('lo dice en frases, no en campos', () async {
      final id = await unNadador(nombre: 'Ana');
      final palabras = (await derechos.queSeGuardaDe(id))!.enPalabras;

      expect(palabras.first, contains('Ana'));
      expect(
        palabras.join(' '),
        contains('No hay fotos, ni videos'),
        reason: 'A un acudiente hay que decirle también lo que NO se guarda. '
            'Es la mitad de la respuesta y la que más tranquiliza',
      );
    });

    test('sin fecha de nacimiento lo dice, en lugar de callarlo', () async {
      final id = await unNadador();
      final que = await derechos.queSeGuardaDe(id);

      expect(que!.constaFechaDeNacimiento, isFalse);
      expect(que.enPalabras.join(' '), contains('No consta su fecha'));
    });

    test('de un nadador que no existe no se inventa nada', () async {
      expect(await derechos.queSeGuardaDe('fantasma'), isNull);
    });
  });

  group('FR-037 — llevárselo', () {
    test('la exportación contiene el perfil y sus registros', () async {
      final id = await unNadador(nombre: 'Ana');
      final planId = await unPlanEntregadoA(id);
      await respuesta(id, planId, 's1');

      final documento = await derechos.exportar(id);

      expect(documento.keys, isNotEmpty);
      expect(documento.toString(), contains('Ana'));
    });

    test('de un nadador que no existe falla en lugar de devolver vacío', () {
      expect(() => derechos.exportar('fantasma'), throwsA(isA<FalloDeDatos>()));
    });
  });

  group('FR-038 — eliminar', () {
    test('se van sus registros, sus asignaciones y su perfil', () async {
      final id = await unNadador();
      final planId = await unPlanEntregadoA(id);
      await respuesta(id, planId, 's1');
      await respuesta(id, planId, 's2');

      final resultado = await derechos.eliminar(id);

      expect(resultado.registrosEliminados, 2);
      expect(resultado.asignacionesRetiradas, 1);
      expect(resultado.perfilEliminado, isTrue);

      expect(await nadadores.obtener(id), isNull);
      expect(await asignaciones.deNadador(id), isEmpty);
      expect(await registros.obtenerDePlan(id, planId), isEmpty);
    });

    test('eliminar a uno no toca a otro', () async {
      final uno = await unNadador(nombre: 'Ana');
      final otro = await unNadador(nombre: 'Luis');
      final planId = await unPlanEntregadoA(uno);
      await asignaciones.asignar(
        Asignacion(planId: planId, nadadorId: otro, asignadaEn: DateTime(2026, 10, 15)),
      );
      await respuesta(otro, planId, 's1');

      await derechos.eliminar(uno);

      expect(await nadadores.obtener(otro), isNotNull);
      expect(await asignaciones.deNadador(otro), hasLength(1));
      expect(await registros.obtenerDePlan(otro, planId), hasLength(1));
    });

    test('eliminar a quien no existe no revienta', () async {
      final resultado = await derechos.eliminar('fantasma');
      expect(resultado.perfilEliminado, isFalse);
    });
  });

  group('SC-014 — borrar no destruye el trabajo del entrenador', () {
    test('el plan sigue ahí, entero, después de eliminar al nadador', () async {
      final id = await unNadador();
      final planId = await unPlanEntregadoA(id);
      await respuesta(id, planId, 's1');

      await derechos.eliminar(id);

      final plan = await planes.obtener(planId);
      expect(
        plan,
        isNotNull,
        reason: 'Un microciclo es la obra profesional del entrenador. Borrar '
            'los datos de un niño no puede costarle la temporada',
      );
      expect(plan!.nombre, 'Microciclo del entrenador');
    });

    test('y no queda ningún rastro del nadador dentro del plan', () async {
      // Desde que la asignación es un documento aparte, un plan no sabe
      // siquiera de quién fue. Lo que se retira es la asignación.
      final id = await unNadador(nombre: 'Ana');
      final planId = await unPlanEntregadoA(id);

      await derechos.eliminar(id);

      final plan = await planes.obtener(planId);
      expect(plan.toString(), isNot(contains('Ana')));
      expect(plan.toString(), isNot(contains(id)));
    });
  });

  group('lo que sobrevive, y por qué', () {
    test('queda dicho que el registro del consentimiento no se borra', () {
      // Es la prueba de que el tratamiento anterior estuvo amparado
      // (garantía C8). Destruirla al borrar dejaría al entrenador sin poder
      // demostrar que actuó con autorización.
      expect(
        ResultadoDeEliminacion.loQueSobrevive,
        contains('prueba de que lo anterior estuvo autorizado'),
      );
    });
  });
}

class _RegistrosEnMemoria implements RepositorioRegistros {
  final _guardados = <String, RegistroDeSesion>{};

  @override
  Future<RegistroDeSesion?> obtener(String registroId) async =>
      _guardados[registroId];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async =>
      _guardados.values
          .where((r) => r.nadadorId == nadadorId && r.planId == planId)
          .toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async {
    _guardados[registro.id] = registro;
  }

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {
        'misRegistros': _guardados.values
            .where((r) => r.nadadorId == nadadorId)
            .map((r) => r.sesionId)
            .toList(),
      };

  @override
  Future<void> eliminarDe(String nadadorId) async {
    _guardados.removeWhere((_, r) => r.nadadorId == nadadorId);
  }
}
