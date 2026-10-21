/// La página que abre un acudiente desde su correo.
///
/// Junta las tres piezas que la feature 004 construyó y nunca conectó: el
/// enlace con su token, el formulario de confirmación, y la operación del
/// servidor que lo canjea (decisión D10).
///
/// **No exige haber entrado.** Es lo que distingue a esta pantalla de todas las
/// demás, y es a propósito: el acudiente no tiene cuenta, y por eso el
/// mecanismo usa un token de un solo uso.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/recursos/textos_legales.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/ui/consentimiento/enlace_del_acudiente.dart';
import 'package:natacion_app/ui/consentimiento/pantalla_confirmacion.dart';

class PaginaDelAcudiente extends StatefulWidget {
  const PaginaDelAcudiente({
    super.key,
    required this.token,
    required this.operaciones,
    this.textos = const CargadorTextosLegales(),
  });

  final String token;

  /// Nulo cuando no hay servidor: entonces no se puede canjear nada, y hay que
  /// decirlo en lugar de enseñar un formulario que no va a funcionar.
  final OperacionesDelServidor? operaciones;

  final CargadorTextosLegales textos;

  @override
  State<PaginaDelAcudiente> createState() => _PaginaDelAcudienteState();
}

class _PaginaDelAcudienteState extends State<PaginaDelAcudiente> {
  late final Future<String> _texto = widget.textos.consentimiento();
  bool _registrada = false;

  @override
  Widget build(BuildContext context) {
    if (_registrada) return const AutorizacionRegistrada();

    final operaciones = widget.operaciones;
    if (operaciones == null) {
      return const EnlaceQueNoSirve(
        mensaje: 'No se pudo conectar con el servidor. Inténtelo otra vez en '
            'un momento, con el mismo enlace: todavía sirve.',
      );
    }

    return FutureBuilder<String>(
      future: _texto,
      builder: (context, instantanea) {
        if (instantanea.hasError) {
          // Sin el texto informativo **no se puede pedir el consentimiento**.
          // Autorizar sin haber leído qué se autoriza no es consentimiento
          // informado, y enseñar el formulario sin él sería fingir que sí.
          return const EnlaceQueNoSirve(
            mensaje: 'No se pudo cargar la información que hay que leer antes '
                'de autorizar. Inténtelo otra vez en un momento.',
          );
        }

        if (!instantanea.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return PantallaConfirmacion(
          textoInformativo: instantanea.data!,
          versionDelTexto: versionDelConsentimiento,
          alConfirmar: (declaracion) async {
            try {
              await operaciones.canjear(
                token: widget.token,
                nombre: declaracion.nombre,
                documento: declaracion.documento,
                calidad: declaracion.calidad,
                esRepresentanteLegal: declaracion.esRepresentanteLegal,
                menorFueOido: declaracion.menorFueOido,
                versionDelTexto: declaracion.versionDelTexto,
              );

              if (mounted) setState(() => _registrada = true);
              return null;
            } on FalloDelServidor catch (e) {
              // El servidor no dice **cuál** de los tres motivos fue —no
              // coincide, venció, ya se usó—, y aquí tampoco: distinguirlos le
              // diría a quien prueba enlaces cuáles existieron.
              return e.mensaje;
            }
          },
        );
      },
    );
  }
}
