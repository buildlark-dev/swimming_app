/// El correo sale aunque la cuenta no estuviera matriculada.
///
/// Esta prueba nació reproduciendo un fallo que el entrenador encontró en la
/// app desplegada: **el correo no se enviaba nunca**.
///
/// El mecanismo de consentimiento de la feature 004 está indexado por
/// `nadadorId`, y una cuenta recién creada no tenía ninguno: ese vínculo lo
/// escribía el entrenador al asociar la cuenta a un perfil de su matrícula. Así
/// que el alta pedía el correo del acudiente, se pulsaba «Terminar», y el
/// servidor rechazaba la solicitud con «Faltan el nadador o el canal».
///
/// Era la tercera vez que asomaba el mismo supuesto. La 004 se escribió para un
/// club cerrado donde el entrenador matricula primero y pide el consentimiento
/// después. **Esta app está abierta a cualquiera, pertenezca a un club o no**,
/// así que la persona llega antes que la matrícula.
///
/// La corrección: quien se da de alta **es** un nadador desde ese momento. El
/// servidor crea su ficha y devuelve su id, y lo que el entrenador sigue
/// decidiendo es su categoría y su estilo objetivo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';

void main() {
  final hoy = DateTime(2026, 10, 22);

  EstadoAlta deUnaMenor(_Servidor servidor, {String? nadadorId}) => EstadoAlta(
        operaciones: servidor,
        correoDeLaCuenta: 'ana@ejemplo.com',
        nadadorId: nadadorId,
        reloj: () => hoy,
      )
        ..escribirNombre('Ana María')
        ..escribirNacimiento(DateTime(2014, 3, 10))
        ..aceptarTerminos(aceptados: true)
        ..escribirCorreoDelAcudiente('madre@ejemplo.com');

  test('una cuenta nueva, sin matricular, también recibe su solicitud',
      () async {
    // **Este es el caso que fallaba**, y es el de todo el que se da de alta.
    final servidor = _Servidor();
    final estado = deUnaMenor(servidor, nadadorId: null);

    final resultado = await estado.terminar();

    expect(resultado, ResultadoDelAlta.listoConSolicitud);
    expect(servidor.solicitudes, ['madre@ejemplo.com']);
  });

  test('el id sale de lo que contesta el servidor, no de la cuenta', () async {
    // Al arrancar el alta no existía ningún nadador. Usar el id que la cuenta
    // tenía entonces es mandar una cadena vacía, que es lo que el servidor
    // rechazaba.
    final servidor = _Servidor(nadadorIdCreado: 'el-recien-creado');
    final estado = deUnaMenor(servidor, nadadorId: null);

    await estado.terminar();

    expect(servidor.nadadoresPedidos, ['el-recien-creado']);
  });

  test('una cuenta que ya estaba matriculada conserva su id', () async {
    // El servidor devuelve el que ya existía: completar el perfil no reescribe
    // a quién pertenece una ficha que el entrenador ya había creado.
    final servidor = _Servidor(nadadorIdCreado: 'el-que-ya-tenia');
    final estado = deUnaMenor(servidor, nadadorId: 'el-que-ya-tenia');

    await estado.terminar();

    expect(servidor.nadadoresPedidos, ['el-que-ya-tenia']);
  });

  test('a un adulto no se le pide nada, con id o sin él', () async {
    final servidor = _Servidor(esMenor: false);
    final estado = EstadoAlta(
      operaciones: servidor,
      correoDeLaCuenta: 'adulto@ejemplo.com',
      reloj: () => hoy,
    )
      ..escribirNombre('Juan')
      ..escribirNacimiento(DateTime(1990, 1, 1))
      ..aceptarTerminos(aceptados: true);

    expect(await estado.terminar(), ResultadoDelAlta.listo);
    expect(servidor.solicitudes, isEmpty);
  });
}

class _Servidor implements OperacionesDelServidor {
  _Servidor({this.esMenor = true, this.nadadorIdCreado = 'n1'});

  final bool esMenor;
  final String nadadorIdCreado;

  final solicitudes = <String>[];
  final nadadoresPedidos = <String>[];

  @override
  Future<PerfilGuardado> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async =>
      PerfilGuardado(esMenor: esMenor, nadadorId: nadadorIdCreado);

  @override
  Future<void> pedirConsentimiento({
    required String nadadorId,
    required String canal,
    Set<Alcance> alcances = const {Alcance.datosDeEntrenamiento},
  }) async {
    nadadoresPedidos.add(nadadorId);

    // Lo que hace el servidor de verdad, y lo que hacía fallar todo.
    if (nadadorId.isEmpty) {
      throw const FalloDelServidor('Faltan el nadador o el canal.');
    }
    solicitudes.add(canal);
  }

  @override
  Future<void> canjear({
    required String token,
    required String nombre,
    required String documento,
    required String calidad,
    required bool esRepresentanteLegal,
    required bool menorFueOido,
    required String versionDelTexto,
  }) async {}
}
