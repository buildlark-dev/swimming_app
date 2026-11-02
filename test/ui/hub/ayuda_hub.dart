/// El HUB montado para probarlo, con datos sembrados.
///
/// Sin esto no había forma de comprobar el recorrido del nadador: los
/// repositorios se construían dentro del estado de la pantalla y no se podía
/// sembrar ni un nadador. Por eso la feature 007 los saca a
/// `RepositoriosDelHub`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/recursos/recursos_iniciales.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/hub/hub.dart';
import 'package:natacion_app/ui/hub/repositorios_del_hub.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime hoy = DateTime(2026, 10, 27, 7);

Biblioteca bibliotecaDePrueba() => Biblioteca.desdeJson(
  jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
      as Map<String, dynamic>,
);

Sesion sesionDePrueba(String id, DateTime? fecha) => Sesion(
  id: id,
  microcicloId: 'm1',
  fecha: fecha,
  objetivoTecnico: 'Técnica de eficiencia en Libre',
  objetivoFisiologico: 'Base aeróbica con énfasis en economía de nado',
  partes: const [
    Parte(tipo: TipoParte.inicial, textoOriginal: "4x100 AL / 2'"),
    Parte(tipo: TipoParte.central, textoOriginal: '8x50 Libre'),
    Parte(tipo: TipoParte.cierre),
  ],
);

Plan planDePrueba({
  String id = 'p1',
  EstadoPlan estado = EstadoPlan.publicado,
  int sesiones = 3,
  bool conSesionHoy = true,
}) => Plan(
  id: id,
  nombre: 'Microciclo de base aeróbica',
  categoria: Categoria.precompetitivo,
  estiloObjetivo: Estilo.libre,
  estado: estado,
  versionMetodologia: '3.6.0',
  microciclos: const [Microciclo(id: 'm1', nombre: 'Semana 1', orden: 1)],
  sesiones: [
    for (var i = 0; i < sesiones; i++)
      sesionDePrueba('s$i', hoy.add(Duration(days: conSesionHoy ? i : i + 3))),
  ],
);

PlanesComoFirestore? ultimoRepoComoFirestore;

RegistroDeSesion registroDePrueba({
  required String sesionId,
  required bool realizada,
  String nadadorId = 'n1',
  String planId = 'p1',
  int? rpe,
  DateTime? cuando,
}) => RegistroDeSesion(
  nadadorId: nadadorId,
  planId: planId,
  sesionId: sesionId,
  versionDePlan: '3.6.0',
  realizada: realizada,
  registradoEn: cuando ?? hoy,
  rpePercibido: rpe,
);

const Nadador nadadorDePrueba = Nadador(
  id: 'n1',
  nombre: 'Ana María Restrepo',
  categoria: Categoria.precompetitivo,
  estiloObjetivo: Estilo.libre,
  pruebaObjetivo: '800 Libre',
);

/// Monta el HUB con lo que se le siembre.
///
/// `cuentaDe` decide el recorrido, igual que en la app: el rol sale de la
/// cuenta y no de un parámetro de la pantalla.
Future<Widget> montarHub({
  required Rol rol,
  List<Plan> planes = const [],
  List<Nadador> nadadores = const [nadadorDePrueba],
  List<Asignacion> asignaciones = const [],
  List<RegistroDeSesion> registros = const [],
  bool modoLocal = false,
  String? nadadorIdDeLaCuenta = 'n1',
  bool planesQueFallan = false,
  bool listarSinSesiones = false,
}) async {
  SharedPreferences.setMockInitialValues({});

  final repoPlanes = RepositorioPlanesMemoria();
  for (final plan in planes) {
    // `guardarAprobado` guarda el plan tal cual, con el estado que traiga.
    await repoPlanes.guardarAprobado(plan, const {});
  }

  final repoNadadores = RepositorioNadadoresMemoria();
  for (final nadador in nadadores) {
    await repoNadadores.guardar(nadador);
  }

  final repoAsignaciones = RepositorioAsignacionesMemoria();
  for (final asignacion in asignaciones) {
    await repoAsignaciones.asignar(asignacion);
  }

  final repoRegistros = _RegistrosSembrados(registros);

  final recursos = RecursosIniciales(
    biblioteca: bibliotecaDePrueba(),
    versionMetodologia: '3.6.0',
    indiceTerminos: IndiceTerminos.vacio(),
    red: _SinRed(),
    transporte: _TransporteQuieto(),
  );

  return MaterialApp(
    home: PantallaPrincipal(
      recursos: recursos,
      modoLocal: modoLocal,
      cuenta: modoLocal
          ? null
          : Cuenta(
              id: 'u1',
              rol: rol,
              nadadorId: rol == Rol.entrenador ? null : nadadorIdDeLaCuenta,
            ),
      repositorios: RepositoriosDelHub(
        planes: planesQueFallan
            ? _PlanesQueRevientan()
            : listarSinSesiones
            ? (ultimoRepoComoFirestore = PlanesComoFirestore(planes))
            : repoPlanes,
        sesiones: RepositorioSesionesMemoria(),
        nadadores: repoNadadores,
        asignaciones: repoAsignaciones,
        registrosLocales: repoRegistros,
        registrosDelServidor: repoRegistros,
      ),
    ),
  );
}

/// Pinta el HUB y espera a que termine de cargar lo suyo.
Future<void> abrirHub(WidgetTester tester, Widget hub) async {
  await tester.pumpWidget(hub);
  await tester.pumpAndSettle();
}

Asignacion asignacionDePrueba({
  String planId = 'p1',
  String nadadorId = 'n1',
}) => Asignacion(planId: planId, nadadorId: nadadorId, asignadaEn: hoy);

class _RegistrosSembrados implements RepositorioRegistros {
  _RegistrosSembrados(List<RegistroDeSesion> iniciales) {
    for (final registro in iniciales) {
      _guardados[registro.id] = registro;
    }
  }

  final Map<String, RegistroDeSesion> _guardados = {};

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
  Future<void> guardar(RegistroDeSesion registro) async =>
      _guardados[registro.id] = registro;

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async =>
      _guardados.removeWhere((_, r) => r.nadadorId == nadadorId);

  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();
}

class _SinRed implements EstadoDeRed {
  @override
  Future<bool> hayConexion() async => false;

  @override
  Stream<bool> get cambios => const Stream<bool>.empty();
}

class _TransporteQuieto implements EnvioDeRegistros {
  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async => hoy;
}

/// Un repositorio que lanza algo que **no** es un fallo con nombre.
///
/// Es lo que pasa de verdad cuando un documento guardado tiene una forma que
/// el cliente no espera: un `TypeError`, no un `FalloDeDatos`.
class _PlanesQueRevientan implements RepositorioPlanes {
  @override
  Future<List<Plan>> listar({Categoria? categoria, EstadoPlan? estado}) async {
    throw TypeError();
  }

  @override
  Future<Plan?> obtener(String id) async => throw TypeError();

  @override
  Future<String> guardarBorrador(Plan plan) async => throw TypeError();

  @override
  Future<void> guardarAprobado(Plan plan, Map<String, dynamic> a) async =>
      throw TypeError();

  @override
  Future<Plan> crearVersionDesde(String id) async => throw TypeError();

  @override
  Future<Map<String, dynamic>> exportar(String id) async => throw TypeError();
}

/// Un repositorio que **miente como el de Firestore**: al listar devuelve los
/// planes sin sus sesiones, y solo al pedir uno concreto las trae.
///
/// Es exactamente lo que hace `RepositorioPlanesFirestore.listar()`, y es lo
/// que hacía que «esperando tu firma» no pudiera dar otra cosa que cero.
class PlanesComoFirestore implements RepositorioPlanes {
  PlanesComoFirestore(this._completos);

  final List<Plan> _completos;

  /// Si alguien pidió un plan concreto: es lo que distingue contar sobre lo
  /// listado de contar sobre el plan completo.
  final pedidos = <String>[];

  @override
  Future<List<Plan>> listar({Categoria? categoria, EstadoPlan? estado}) async =>
      _completos
          .where((p) => estado == null || p.estado == estado)
          .map((p) => p.copiarCon(sesiones: const []))
          .toList();

  @override
  Future<Plan?> obtener(String id) async {
    pedidos.add(id);
    for (final plan in _completos) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  @override
  Future<String> guardarBorrador(Plan plan) async => plan.id ?? 'p1';

  @override
  Future<void> guardarAprobado(Plan plan, Map<String, dynamic> a) async {}

  @override
  Future<Plan> crearVersionDesde(String id) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> exportar(String id) async => {};
}
