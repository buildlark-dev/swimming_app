/// Reproduce lo que el entrenador encontró: **el correo no se envía nunca**.
///
/// El mecanismo de consentimiento de la feature 004 está indexado por
/// `nadadorId`: la solicitud, el consentimiento y la puerta hablan todos de un
/// nadador de la matrícula. Pero **una cuenta recién creada no tiene
/// `nadadorId`**: ese vínculo lo escribe el servidor cuando el entrenador
/// asocia la cuenta a un perfil de su matrícula, y en el alta eso no ha pasado.
///
/// Así que el alta pide el correo del acudiente, la nadadora pulsa «Terminar»,
/// y el servidor rechaza la solicitud porque le falta el nadador. No sale
/// ningún correo.
///
/// Es la tercera vez que asoma el mismo supuesto: la 004 se escribió para un
/// club cerrado donde el entrenador matricula primero y pide el consentimiento
/// después. Aquí la persona llega antes que la matrícula.
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

  test('con nadadorId, la solicitud sale', () {
    // El caso que las pruebas cubrían: una cuenta ya asociada a un perfil.
    final servidor = _Servidor();
    final estado = deUnaMenor(servidor, nadadorId: 'n1');

    return estado.terminar().then((resultado) {
      expect(resultado, ResultadoDelAlta.listoConSolicitud);
      expect(servidor.solicitudes, ['madre@ejemplo.com']);
    });
  });

  test('SIN nadadorId —una cuenta nueva— el servidor la rechaza', () async {
    // **Esto es lo que le pasa a todo el que se da de alta hoy.**
    final servidor = _Servidor();
    final estado = deUnaMenor(servidor, nadadorId: null);

    final resultado = await estado.terminar();

    expect(
      servidor.nadadoresPedidos,
      [''],
      reason: 'Se manda una cadena vacía, que es lo que el servidor rechaza '
          'con «Faltan el nadador o el canal»',
    );
    expect(
      resultado,
      isNull,
      reason: 'El alta no termina: la nadadora se queda con un error y sin '
          'que su acudiente reciba nada',
    );
  });
}

class _Servidor implements OperacionesDelServidor {
  final solicitudes = <String>[];
  final nadadoresPedidos = <String>[];

  @override
  Future<bool> guardarPerfil({
    required String nombre,
    required DateTime fechaNacimiento,
    String? pais,
    required String versionDeTerminos,
  }) async =>
      true;

  @override
  Future<void> pedirConsentimiento({
    required String nadadorId,
    required String canal,
    Set<Alcance> alcances = const {Alcance.datosDeEntrenamiento},
  }) async {
    nadadoresPedidos.add(nadadorId);
    // Lo que hace el servidor de verdad.
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
