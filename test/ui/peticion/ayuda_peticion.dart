/// La pantalla de petición montada, con lo que se le siembre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/peticion/peticion_del_nadador.dart';

const Nadador anaDePrueba = Nadador(
  id: 'n-ana',
  nombre: 'Ana María Restrepo',
  categoria: Categoria.precompetitivo,
  estiloObjetivo: Estilo.libre,
  pruebaObjetivo: '200 Libre',
);

/// Un repositorio de peticiones que guarda en memoria y cuenta lo que le piden.
class PeticionesEnMemoria implements RepositorioPeticiones {
  PeticionesEnMemoria({this.sembrada, this.alEnviarFalla});

  PeticionDePlan? sembrada;

  /// Para probar que un fallo al enviar se dice, en vez de darse por enviado.
  final Object? alEnviarFalla;

  final List<RespuestasDePeticion> enviadas = [];
  final List<String> abiertas = [];

  @override
  Future<PeticionDePlan?> miPeticion(String nadadorId) async =>
      sembrada?.nadadorId == nadadorId ? sembrada : null;

  @override
  Future<List<PeticionDePlan>> cola() async =>
      sembrada == null ? const [] : [sembrada!];

  @override
  Future<void> enviar({
    required String nadadorId,
    required RespuestasDePeticion respuestas,
  }) async {
    if (alEnviarFalla != null) throw alEnviarFalla!;

    enviadas.add(respuestas);
    sembrada = PeticionDePlan(
      nadadorId: nadadorId,
      enviadaEn: DateTime(2026, 11, 2, 7),
      respuestas: respuestas,
      estado: EstadoDePeticion.esperando,
    );
  }

  @override
  Future<void> marcarEnRevision(String nadadorId) async {
    abiertas.add(nadadorId);
  }
}

/// Monta la pantalla del nadador con su ficha y su petición, si las hay.
Future<PeticionesEnMemoria> montarPeticion(
  WidgetTester tester, {
  Nadador? ficha = anaDePrueba,
  String? nadadorId = 'n-ana',
  PeticionDePlan? peticion,
  Object? alEnviarFalla,
  AlmacenLocal? almacen,
  bool retenida = false,
  List<String>? reintentos,
}) async {
  // La lista es larga y un `ListView` no construye lo que no se ve. Con una
  // pantalla alta se monta entera y las aserciones hablan de lo que hay, no de
  // lo que cabe.
  tester.view.physicalSize = const Size(800, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final nadadores = RepositorioNadadoresMemoria();
  if (ficha != null) await nadadores.guardar(ficha);

  final peticiones = PeticionesEnMemoria(
    sembrada: peticion,
    alEnviarFalla: alEnviarFalla,
  );

  // **Pantalla nueva de verdad.** Sin esto, volver a montar el mismo tipo de
  // widget reutiliza el `State` que ya había, y la prueba de «lo respondido
  // sobrevive a cerrar la app» pasaría sin que nada se hubiera guardado: lo
  // que sobreviviría sería el objeto en memoria, no el almacén.
  //
  // Lo encontró el control negativo de `lo_respondido_sobrevive_test.dart`,
  // que es justo para lo que estaba puesto.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PeticionDelNadador(
          nadadorId: nadadorId,
          nadadores: nadadores,
          peticiones: peticiones,
          // Retenida **solo después de mandarla**, que es como se comporta
          // de verdad: antes de mandar no hay nada retenido. Con un `true`
          // fijo, la prueba pasaría por el estado inicial y no vería el
          // defecto de que al enviar no se vuelve a mirar.
          estaRetenida: (_) async => retenida && peticiones.enviadas.isNotEmpty,
          alReintentarLoRetenido: reintentos == null
              ? null
              : (nadadorId) async => reintentos.add(nadadorId),
          almacen: almacen,
          hoyParaPruebas: DateTime(2026, 11, 2),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return peticiones;
}
