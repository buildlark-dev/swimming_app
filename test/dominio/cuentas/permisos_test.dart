import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/cuentas/permisos.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Garantía A10 — los permisos del dominio y las reglas dicen lo mismo.
///
/// Esta suite y `firebase/test/reglas.test.js` leen **el mismo archivo**,
/// `test/acceso/casos.json`. No hay forma automática de demostrar que Dart y
/// las reglas de Firestore expresan la misma decisión; lo que sí se puede
/// hacer es que las dos recorran la misma lista, de modo que un caso nuevo
/// obligue a las dos a cumplirlo y una regla cambiada sin su pareja haga fallar
/// a la otra el mismo día.
///
/// Contrato: `specs/004-cuentas-y-consentimiento/contracts/cuentas_y_roles.md`.
void main() {
  final casos = (jsonDecode(
    File('test/acceso/casos.json').readAsStringSync(),
  ) as Map<String, dynamic>)['casos'] as List<dynamic>;

  Cuenta? cuentaDe(Map<String, dynamic>? json) {
    if (json == null) return null;
    return Cuenta(
      id: 'uid-de-prueba',
      rol: Rol.porClave(json['rol'] as String)!,
      nadadorId: json['nadadorId'] as String?,
    );
  }

  Plan planDe(Map<String, dynamic> json) => Plan(
        id: 'p1',
        nombre: 'Microciclo de prueba',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '800 Libre',
        estado: EstadoPlan.values.firstWhere(
          (e) => e.name == json['estado'],
        ),
        sesiones: const [],
      );

  bool evaluar(Map<String, dynamic> caso) {
    final cuenta = cuentaDe(caso['cuenta'] as Map<String, dynamic>?);

    switch (caso['accion'] as String) {
      case 'aprobarPlan':
        return Permisos.puedeAprobar(cuenta);
      case 'publicarPlan':
        return Permisos.puedePublicar(cuenta);
      case 'leerPlan':
        final plan = caso['plan'] as Map<String, dynamic>;
        return Permisos.puedeLeerPlan(
          cuenta,
          planDe(plan),
          leEstaAsignado: plan['asignado'] as bool? ?? false,
        );
      case 'asignar':
        return Permisos.puedeAsignar(
          cuenta,
          tieneConsentimiento: caso['tieneConsentimiento'] as bool? ?? false,
        );
      case 'editarPlan':
        return Permisos.puedeEditarPlan(
          cuenta,
          planDe(caso['plan'] as Map<String, dynamic>),
        );
      case 'escribirRegistro':
        return Permisos.puedeEscribirRegistro(
          cuenta,
          caso['registroDe'] as String,
        );
      case 'leerRegistro':
        return Permisos.puedeLeerRegistro(
          cuenta,
          caso['registroDe'] as String,
          esDeSuComunidad: caso['esDeSuComunidad'] as bool? ?? false,
        );
      case 'emitirSolicitud':
        return Permisos.puedeEmitirSolicitud(cuenta);
      case 'escribirConsentimiento':
        return Permisos.puedeEscribirConsentimiento(cuenta);
      case 'leerConsentimiento':
        return Permisos.puedeLeerConsentimiento(
          cuenta,
          caso['deNadador'] as String,
          esDeSuComunidad: caso['esDeSuComunidad'] as bool? ?? false,
        );
      default:
        fail('Acción desconocida en casos.json: ${caso['accion']}. '
            'Si se añadió una acción nueva, esta suite tiene que saber '
            'evaluarla; si no, el caso pasaría sin comprobarse nada');
    }
  }

  group('la lista compartida de casos de acceso', () {
    test('tiene casos, y si se queda vacía esto se entera', () {
      expect(
        casos,
        isNotEmpty,
        reason: 'Una lista de casos vacía haría pasar esta suite sin '
            'comprobar una sola regla',
      );
    });

    for (final entrada in casos) {
      final caso = entrada as Map<String, dynamic>;
      final esperado = caso['permitido'] as bool;

      test('${caso['garantia']} — ${caso['nombre']}', () {
        expect(
          evaluar(caso),
          esperado,
          reason: caso['nota'] as String? ??
              'El dominio decide distinto de lo que declara casos.json. Si el '
                  'caso es correcto, está mal el dominio; si cambió la regla, '
                  'hay que cambiarla también en firestore.rules',
        );
      });
    }
  });

  group('lo que no depende de un caso concreto', () {
    test('sin sesión no hay permiso de nada', () {
      expect(Permisos.sinSesion(null), isTrue);
      expect(
        Permisos.sinSesion(Cuenta(id: 'u1', rol: Rol.nadador)),
        isFalse,
      );
    });

    test('un rol desconocido en el token no se interpreta como nadador', () {
      // Suponer el rol «menos peligroso» ante un valor que no se entiende es
      // justo como se cuela un permiso: quien reciba null tiene que decidir.
      expect(Rol.porClave('administrador'), isNull);
      expect(Rol.porClave(''), isNull);
      expect(Rol.porClave(null), isNull);
    });

    test('las claves del rol son las que leen las reglas', () {
      // Si esto cambia, hay que cambiar firestore.rules el mismo día.
      expect(Rol.entrenador.clave, 'entrenador');
      expect(Rol.nadador.clave, 'nadador');
    });
  });
}
