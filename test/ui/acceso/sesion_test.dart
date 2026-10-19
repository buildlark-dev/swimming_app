import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/acceso/estado_sesion.dart';

/// El estado de sesión, que es lo que decide qué ve cada quien al abrir.
///
/// Se prueba contra un doble de [Identidad] y no contra Firebase: lo que hay
/// que comprobar es la decisión, no la librería.
void main() {
  /// Esperas de milisegundos, para no tardar veinte segundos en cada prueba.
  const rapidas = [
    Duration(milliseconds: 5),
    Duration(milliseconds: 5),
    Duration(milliseconds: 5),
  ];

  group('al abrir la app', () {
    test('no se enseña la pantalla de acceso antes de saber quién eres', () {
      // Es el parpadeo que vería a diario quien ya tiene sesión.
      final sesion = SesionActiva(identidad: _IdentidadFalsa());

      expect(sesion.estado, EstadoDeSesion.comprobando);
      expect(sesion.hayCuenta, isFalse);
    });

    test('con sesión guardada se entra directo', () async {
      final sesion = SesionActiva(
        identidad: _IdentidadFalsa(
          inicial: CuentaLista(
            Cuenta(id: 'u1', rol: Rol.nadador, nadadorId: 'n1'),
          ),
        ),
      );

      await _unCiclo();

      expect(sesion.estado, EstadoDeSesion.dentro);
      expect(sesion.cuenta!.nadadorId, 'n1');
    });

    test('sin sesión guardada se queda fuera', () async {
      final sesion = SesionActiva(identidad: _IdentidadFalsa());
      await _unCiclo();

      expect(sesion.estado, EstadoDeSesion.fuera);
    });

    test('si no se puede resolver quién eres, se trata como estar fuera',
        () async {
      final sesion = SesionActiva(identidad: _IdentidadFalsa(revienta: true));
      await _unCiclo();

      expect(sesion.estado, EstadoDeSesion.fuera);
    });
  });

  group('recién creada la cuenta, el rol tarda en llegar', () {
    test('NO se devuelve a la pantalla de acceso', () async {
      // Este fue el fallo: el entrenador creaba la cuenta y la app lo
      // rebotaba al login una y otra vez, sin explicar nada. El rol lo asigna
      // el servidor después de crear la cuenta, así que existe un momento en
      // que la sesión es real y el papel todavía no se sabe.
      final identidad = _IdentidadFalsa(inicial: const CuentaSinRol('u1'));
      final sesion = SesionActiva(identidad: identidad, esperas: rapidas);

      await _unCiclo();

      expect(
        sesion.estado,
        isNot(EstadoDeSesion.fuera),
        reason: 'Volver al login invita a registrarse otra vez, y la cuenta '
            'nueva tendría exactamente el mismo problema',
      );
      expect(sesion.estado, EstadoDeSesion.preparando);
    });

    test('cuando el rol llega, entra sin que nadie toque nada', () async {
      final identidad = _IdentidadFalsa(inicial: const CuentaSinRol('u1'));
      final sesion = SesionActiva(identidad: identidad, esperas: rapidas);
      await _unCiclo();

      // El disparador del servidor termina y el rol aparece.
      identidad.estado = CuentaLista(Cuenta(id: 'u1', rol: Rol.nadador));

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(sesion.estado, EstadoDeSesion.dentro);
      expect(sesion.cuenta!.id, 'u1');
    });

    test('reintenta de verdad, no una sola vez', () async {
      // Una única comprobación inmediata casi nunca alcanza al disparador.
      final identidad = _IdentidadFalsa(inicial: const CuentaSinRol('u1'));
      SesionActiva(identidad: identidad, esperas: rapidas);

      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(identidad.consultas, greaterThan(1));
    });

    test('si el rol nunca llega, lo dice en lugar de rebotar al login',
        () async {
      final sesion = SesionActiva(
        identidad: _IdentidadFalsa(inicial: const CuentaSinRol('u1')),
        esperas: rapidas,
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(sesion.estado, EstadoDeSesion.sinRol);
      expect(sesion.hayCuenta, isFalse);
    });

    test('mientras no hay rol, no se concede ninguna cuenta', () async {
      // Las reglas deniegan todo a un token sin rol. El cliente no puede
      // inventarse uno «mientras tanto».
      final sesion = SesionActiva(
        identidad: _IdentidadFalsa(inicial: const CuentaSinRol('u1')),
        esperas: rapidas,
      );
      await _unCiclo();

      expect(sesion.cuenta, isNull);
    });
  });

  group('cerrar sesión', () {
    test('deja la sesión fuera', () async {
      final identidad = _IdentidadFalsa(
        inicial: CuentaLista(
          Cuenta(id: 'u1', rol: Rol.nadador, nadadorId: 'n1'),
        ),
      );
      final sesion = SesionActiva(identidad: identidad);
      await _unCiclo();
      expect(sesion.estado, EstadoDeSesion.dentro);

      await sesion.cerrarSesion();
      await _unCiclo();

      expect(sesion.estado, EstadoDeSesion.fuera);
      expect(sesion.cuenta, isNull);
    });

    test('pide vaciar el dispositivo, no solo cerrar la sesión', () async {
      // Garantía A7: el siguiente hermano que entre en ese teléfono no puede
      // encontrar lo del anterior en la caché.
      final identidad = _IdentidadFalsa(
        inicial: CuentaLista(
          Cuenta(id: 'u1', rol: Rol.nadador, nadadorId: 'n1'),
        ),
      );
      final sesion = SesionActiva(identidad: identidad);
      await _unCiclo();

      await sesion.cerrarSesion();

      expect(identidad.vaciados, 1);
    });
  });

  group('cambiar de cuenta en el mismo dispositivo', () {
    test('la cuenta activa pasa a ser la nueva, sin rastro de la anterior',
        () async {
      final identidad = _IdentidadFalsa(
        inicial: CuentaLista(
          Cuenta(id: 'u-mayor', rol: Rol.nadador, nadadorId: 'n1'),
        ),
      );
      final sesion = SesionActiva(identidad: identidad);
      await _unCiclo();

      await sesion.cerrarSesion();
      identidad.entra(
        CuentaLista(Cuenta(id: 'u-menor', rol: Rol.nadador, nadadorId: 'n2')),
      );
      await _unCiclo();

      expect(sesion.cuenta!.id, 'u-menor');
      expect(sesion.cuenta!.nadadorId, 'n2');
    });
  });

  group('el rol decide qué se ve', () {
    test('una cuenta de entrenador se reconoce como tal', () async {
      final sesion = SesionActiva(
        identidad: _IdentidadFalsa(
          inicial: CuentaLista(Cuenta(id: 'u-e', rol: Rol.entrenador)),
        ),
      );
      await _unCiclo();

      expect(sesion.cuenta!.esEntrenador, isTrue);
      expect(sesion.cuenta!.esNadador, isFalse);
    });

    test('una cuenta sin perfil asociado entra igual', () async {
      // No es un error: es el día en que alguien se registra antes de que su
      // entrenador lo inscriba.
      final sesion = SesionActiva(
        identidad: _IdentidadFalsa(
          inicial: CuentaLista(Cuenta(id: 'u-s', rol: Rol.nadador)),
        ),
      );
      await _unCiclo();

      expect(sesion.estado, EstadoDeSesion.dentro);
      expect(sesion.cuenta!.sinPerfilAsociado, isTrue);
    });
  });
}

/// Deja correr los futuros pendientes.
Future<void> _unCiclo() => Future<void>.delayed(Duration.zero);

class _IdentidadFalsa implements Identidad {
  _IdentidadFalsa({EstadoDeCuenta? inicial, this.revienta = false})
      : estado = inicial ?? const SinSesion();

  EstadoDeCuenta estado;
  final bool revienta;

  /// Cuántas veces se preguntó por el estado. Para comprobar que reintenta.
  int consultas = 0;

  /// Cuántas veces se pidió vaciar el dispositivo.
  int vaciados = 0;

  final _control = StreamController<EstadoDeCuenta>.broadcast();

  void entra(EstadoDeCuenta nuevo) {
    estado = nuevo;
    _control.add(nuevo);
  }

  @override
  Future<EstadoDeCuenta> actual() async {
    consultas++;
    if (revienta) throw const FalloDeAcceso('sin red y sin caché');
    return estado;
  }

  @override
  Stream<EstadoDeCuenta> get cambios => _control.stream;

  @override
  Future<void> cerrarSesion() async {
    vaciados++;
    estado = const SinSesion();
    _control.add(const SinSesion());
  }

  @override
  Future<void> entrar({required String correo, required String clave}) async {
    entra(CuentaLista(Cuenta(id: 'u-$correo', rol: Rol.nadador)));
  }

  @override
  Future<void> crearCuenta({
    required String correo,
    required String clave,
  }) async {
    // Como en Firebase: la cuenta existe antes de que el servidor le ponga
    // el rol.
    entra(CuentaSinRol('u-$correo'));
  }
}
