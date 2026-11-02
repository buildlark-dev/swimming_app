/// Exportación de planes y perfiles.
///
/// Principio V de la constitución: el usuario puede exportar sus datos en un
/// formato legible. Es la garantía de portabilidad y el seguro contra la
/// dependencia de un proveedor.
///
/// El resultado debe poder leerse **sin la app**.
library;

import 'dart:convert';

import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';

const String formatoExportacion = 'natacion-app/v1';

class Exportacion {
  const Exportacion();

  /// Plan completo con sus sesiones embebidas, en un único documento.
  Map<String, dynamic> plan(Plan plan, {String? versionMetodologia}) {
    return <String, dynamic>{
      'formato': formatoExportacion,
      'exportadoEl': DateTime.now().toIso8601String(),
      'versionMetodologia': ?versionMetodologia,
      'plan': planAJson(plan, conSesiones: true),
    };
  }

  /// Perfil de nadador con los planes que le corresponden.
  Map<String, dynamic> nadador(
    Nadador nadador, {
    List<Plan> planes = const [],
  }) {
    return <String, dynamic>{
      'formato': formatoExportacion,
      'exportadoEl': DateTime.now().toIso8601String(),
      'nadador': nadadorAJson(nadador),
      'planes': planes.map((p) => planAJson(p, conSesiones: true)).toList(),
    };
  }

  /// La copia que el nadador se lleva (feature 003).
  ///
  /// El plan con sus sesiones **más sus propios registros**. Reutiliza este
  /// formato en lugar de inventar otro: la constitución recuerda que la
  /// descarga «es una copia para archivo o impresión, **no el producto**»
  /// (decisión D5).
  ///
  /// Sirve además al derecho de portabilidad del principio V: el nadador puede
  /// llevarse lo que él mismo generó, y se lee sin la app.
  Map<String, dynamic> paraElNadador(
    Plan plan, {
    List<RegistroDeSesion> registros = const [],
    String? versionMetodologia,
  }) {
    return <String, dynamic>{
      'formato': formatoExportacion,
      'exportadoEl': DateTime.now().toIso8601String(),
      'versionMetodologia': ?versionMetodologia,
      'plan': planAJson(plan, conSesiones: true),
      // Separados del plan a propósito: el plan es carga externa y los
      // registros son carga interna, y el principio VIII pide no mezclarlos.
      'misRegistros': registros.map(registroAJson).toList(),
    };
  }

  /// Texto JSON con sangrado, listo para guardar en un archivo.
  String aTexto(Map<String, dynamic> documento) =>
      const JsonEncoder.withIndent('  ').convert(documento);
}
