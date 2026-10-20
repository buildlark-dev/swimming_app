import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/exportacion.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/local/repositorios_locales.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Principio V: datos de deportistas, mínimos, protegidos y portables.
///
/// Esta feature almacena la respuesta de un nadador, y en este proyecto eso
/// significa con frecuencia la de un menor de edad. Las pruebas de aquí son las
/// que impiden que un descuido se convierta en una filtración.
void main() {
  RegistroDeSesion registro({
    String nadadorId = 'n1',
    String sesionId = 's1',
    String observaciones = '',
    ReporteDeMolestia? molestia,
  }) =>
      RegistroDeSesion(
        nadadorId: nadadorId,
        planId: 'p1',
        sesionId: sesionId,
        versionDePlan: '3.5.0',
        realizada: true,
        registradoEn: DateTime(2026, 10, 14, 7, 30),
        rpePercibido: 7,
        observaciones: observaciones,
        molestia: molestia,
      );

  group('FR-023 — sin datos personales en lo que se guarda', () {
    test('el registro serializado no lleva nombre, edad ni marcas', () {
      final json = registroAJson(registro());

      expect(json.keys, isNot(contains('nombre')));
      expect(json.keys, isNot(contains('fechaNacimiento')));
      expect(json.keys, isNot(contains('marcas')));
      expect(json.keys, isNot(contains('edad')));
    });

    test('solo lleva identificadores opacos y la respuesta', () {
      final json = registroAJson(registro());

      expect(
        json.keys.toSet(),
        {
          'id',
          'nadadorId',
          'planId',
          'sesionId',
          'versionDePlan',
          'realizada',
          'registradoEn',
          'rpePercibido',
        },
        reason: 'Minimización: no se guarda ningún dato que no tenga un uso '
            'declarado en esta feature',
      );
    });

    test('el identificador del nadador es opaco, no su nombre', () {
      // Si alguien pasara el nombre como identificador, el identificador del
      // registro —que es determinista y viaja al servidor— lo llevaría dentro.
      final json = registroAJson(registro(nadadorId: 'n1'));
      expect(json['id'], startsWith('n1|'));
      expect(json['id'], isNot(contains(' ')));
    });
  });

  group('FR-024 — portabilidad y borrado', () {
    late AlmacenLocal almacen;
    late RegistrosLocales repositorio;

    setUp(() {
      almacen = _AlmacenEnMemoria();
      repositorio = RegistrosLocales(almacen);
    });

    test('un nadador puede exportar lo que él mismo generó', () async {
      await repositorio.guardar(registro(sesionId: 's1'));
      await repositorio.guardar(registro(sesionId: 's2'));

      final exportado = await repositorio.exportar('n1');

      expect(exportado['formato'], formatoExportacion);
      expect(exportado['registros'], hasLength(2));
    });

    test('la exportación solo trae lo suyo', () async {
      await repositorio.guardar(registro(nadadorId: 'n1'));
      await repositorio.guardar(registro(nadadorId: 'n2', sesionId: 's9'));

      final exportado = await repositorio.exportar('n1');

      expect(exportado['registros'], hasLength(1));
    });

    test('se puede borrar todo lo de un nadador sin rediseñar nada', () async {
      await repositorio.guardar(registro(sesionId: 's1'));
      await repositorio.guardar(registro(sesionId: 's2'));

      await repositorio.eliminarDe('n1');

      expect(await repositorio.obtenerDePlan('n1', 'p1'), isEmpty);
    });

    test('borrar a uno no borra a otro', () async {
      await repositorio.guardar(registro(nadadorId: 'n1'));
      await repositorio.guardar(registro(nadadorId: 'n2', sesionId: 's9'));

      await repositorio.eliminarDe('n1');

      expect(await repositorio.obtenerDePlan('n2', 'p1'), hasLength(1));
    });

    test('la exportación se lee sin la app', () async {
      await repositorio.guardar(
        registro(observaciones: 'Me costó la tercera serie'),
      );

      final exportado = await repositorio.exportar('n1');
      final primero = (exportado['registros'] as List).first as Map;

      // Texto plano y claves legibles: nada codificado ni comprimido.
      expect(primero['observaciones'], 'Me costó la tercera serie');
      expect(primero['realizada'], isTrue);
    });
  });

  group('FR-026 — nada de lo suyo queda tras un muro de pago', () {
    test('la exportación no pide nivel de suscripción', () async {
      // Principio VI: «el muro de pago NUNCA bloquea el acceso del usuario a
      // los datos que él mismo generó, a su historial, ni a su exportación».
      // La firma no tiene por dónde preguntarlo, y esa es la garantía.
      final repositorio = RegistrosLocales(_AlmacenEnMemoria());
      await repositorio.guardar(registro());

      expect(await repositorio.exportar('n1'), isNotEmpty);
    });

    test('leer los registros propios tampoco', () async {
      final repositorio = RegistrosLocales(_AlmacenEnMemoria());
      await repositorio.guardar(registro());

      expect(await repositorio.obtenerDePlan('n1', 'p1'), hasLength(1));
    });
  });

  group('la copia que el nadador se lleva', () {
    test('trae el plan y sus registros, separados', () {
      // Carga externa y carga interna en claves distintas, por la misma razón
      // por la que son entidades distintas (principio VIII).
      const exportacion = Exportacion();
      final documento = exportacion.paraElNadador(
        _planMinimo(),
        registros: [registro()],
      );

      expect(documento.keys, contains('plan'));
      expect(documento.keys, contains('misRegistros'));
      expect(documento['misRegistros'], hasLength(1));
    });
  });

  group('viaje de ida y vuelta', () {
    test('un registro sobrevive a serializar y volver', () {
      final original = registro(
        observaciones: 'CON MAYÚSCULAS\ny salto de línea',
        molestia: const ReporteDeMolestia(
          descripcion: 'Pinchazo',
          zonaDelCuerpo: 'hombro derecho',
        ),
      );

      final vuelto = registroDesdeJson(registroAJson(original));

      expect(vuelto.id, original.id);
      expect(vuelto.observaciones, original.observaciones);
      expect(vuelto.rpePercibido, original.rpePercibido);
      expect(vuelto.molestia, original.molestia);
    });

    test('un estado de envío desconocido vuelve a pendiente, nunca a enviado',
        () {
      final raro = envioDesdeJson(const {
        'registroId': 'r1',
        'estado': 'inventado',
        'intentos': 2,
      });

      expect(raro.estado.name, 'pendiente');
      expect(
        raro.esperaEnvio,
        isTrue,
        reason: 'Dar por enviado lo que no se sabe sería perder el dato en '
            'silencio',
      );
    });
  });
}

class _AlmacenEnMemoria implements AlmacenLocal {
  final Map<String, Map<String, Map<String, dynamic>>> _datos = {};

  @override
  Future<Map<String, Map<String, dynamic>>> leerTodo(String coleccion) async =>
      Map.of(_datos[coleccion] ?? {});

  @override
  Future<Map<String, dynamic>?> leer(String coleccion, String clave) async =>
      _datos[coleccion]?[clave];

  @override
  Future<void> escribir(
    String coleccion,
    String clave,
    Map<String, dynamic> documento,
  ) async {
    _datos.putIfAbsent(coleccion, () => {})[clave] = documento;
  }

  @override
  Future<void> borrar(String coleccion, String clave) async =>
      _datos[coleccion]?.remove(clave);

  @override
  Future<void> borrarColeccion(String coleccion) async =>
      _datos.remove(coleccion);

  @override
  Future<void> vaciar() async => _datos.clear();
}

/// Plan mínimo para la prueba de la copia descargable.
Plan _planMinimo() => Plan(
      id: 'p1',
      nombre: 'Microciclo',
      categoria: Categoria.precompetitivo,
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '800 Libre',
      estado: EstadoPlan.publicado,
      sesiones: const [],
    );
