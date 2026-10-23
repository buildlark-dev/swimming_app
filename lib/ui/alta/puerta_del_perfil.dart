/// Lo primero que pasa al entrar: ¿sabemos quién eres?
///
/// **Es el mismo camino para una cuenta nueva y para una de las que ya
/// existían.** Quien acaba de crear su cuenta tiene el perfil vacío; quien
/// entró por primera vez desde la feature 004 también. Las dos recorren los
/// mismos pasos, y por eso no hay dos pantallas que se parecen (FR-021, T040).
///
/// La consecuencia que de verdad importa no es tener los nombres en la ficha:
/// es que **una cuenta sin fecha de nacimiento es una cuenta de la que no se
/// sabe si necesita consentimiento**. Si alguna de las que ya existen resulta
/// ser de un menor, es aquí donde por fin se le pide (FR-023).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/alta/pantalla_alta.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/boton.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:provider/provider.dart';

class PuertaDelPerfil extends StatefulWidget {
  const PuertaDelPerfil({
    super.key,
    required this.uid,
    required this.correo,
    required this.repositorio,
    required this.operaciones,
    required this.dentro,
    this.almacen,
    this.nadadorId,
  });

  final String uid;
  final String correo;
  final RepositorioPerfil repositorio;
  final OperacionesDelServidor? operaciones;
  final AlmacenLocal? almacen;
  final String? nadadorId;

  /// Lo que hay detrás, una vez se sabe quién es.
  final Widget dentro;

  @override
  State<PuertaDelPerfil> createState() => _PuertaDelPerfilState();
}

class _PuertaDelPerfilState extends State<PuertaDelPerfil> {
  late Future<Perfil> _perfil = widget.repositorio.obtener(widget.uid);
  ResultadoDelAlta? _altaRecienTerminada;

  /// Entró sin haber podido guardar el perfil. Se le vuelve a preguntar la
  /// próxima vez que abra la app.
  bool _entroSinPerfil = false;

  @override
  Widget build(BuildContext context) {
    if (_altaRecienTerminada != null) {
      return _Bienvenida(
        resultado: _altaRecienTerminada!,
        alContinuar: () => setState(() => _altaRecienTerminada = null),
      );
    }

    if (_entroSinPerfil) return widget.dentro;

    return FutureBuilder<Perfil>(
      future: _perfil,
      builder: (context, instantanea) {
        if (instantanea.hasError) {
          // **Si no se puede leer el perfil, se pregunta.** No se deja pasar.
          //
          // Al revés parece más amable y es peor: dejar pasar equivale a
          // suponer que el perfil está completo, y esa es justo la suposición
          // que hace que a un menor **no se le pida nunca el consentimiento**.
          // Preguntar de más cuesta que alguien reescriba su nombre una vez;
          // suponer de más cuesta un consentimiento que nadie pidió.
          //
          // No encierra a nadie: si además falla guardar, el alta ofrece
          // «Entrar de todos modos».
          //
          // Y de paso quita un camino silencioso. Un fallo que te mete en la
          // app sin decir nada es un fallo que nadie puede explicar después.
          return _pedirElPerfil();
        }

        if (!instantanea.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (instantanea.data!.estaCompleto) return widget.dentro;

        return _pedirElPerfil();
      },
    );
  }

  Widget _pedirElPerfil() {
    return ChangeNotifierProvider<EstadoAlta>(
      create: (_) => EstadoAlta(
        operaciones: widget.operaciones,
        correoDeLaCuenta: widget.correo,
        almacen: widget.almacen,
        nadadorId: widget.nadadorId,
      )..recuperar(),
      child: PantallaAlta(
        alTerminar: (resultado) => setState(() {
          _altaRecienTerminada = resultado;
          _perfil = widget.repositorio.obtener(widget.uid);
        }),
        // Si el perfil no se pudo guardar, se entra igual. Sin fecha de
        // nacimiento la app trata a quien entra como menor, así que la puerta
        // sigue cerrada y nada sale del dispositivo: lo único que se pierde es
        // saber quién es, y se vuelve a preguntar mañana.
        alEntrarIgual: () => setState(() => _entroSinPerfil = true),
      ),
    );
  }
}

/// Lo que se ve justo después de terminar el alta.
///
/// Existe para una sola frase: la de quien es menor y no dio el correo de su
/// acudiente. Decirle «no podrás hacer X» en el paso y no volver a mencionarlo
/// sería esconderlo.
class _Bienvenida extends StatelessWidget {
  const _Bienvenida({required this.resultado, required this.alContinuar});

  final ResultadoDelAlta resultado;
  final VoidCallback alContinuar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Espaciado.amplio),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EstadoVacio(
                icono: Icons.waving_hand_outlined,
                titulo: 'Ya estás dentro',
                queHacer: 'Aquí verás lo que te toca entrenar cada día.',
              ),

              if (resultado == ResultadoDelAlta.listoConSolicitud) ...[
                const SizedBox(height: Espaciado.amplio),
                const Aviso(
                  tono: TonoDeAviso.exito,
                  claveDelMensaje: Key('alta-solicitud-enviada'),
                  mensaje: 'Le enviamos un correo a tu acudiente para pedirle '
                      'permiso. Mientras tanto puedes usar la app con '
                      'normalidad: lo que anotes se guarda en tu teléfono.',
                ),
              ],

              if (resultado == ResultadoDelAlta.listoSinAcudiente) ...[
                const SizedBox(height: Espaciado.amplio),
                // **Informativo, no de cuidado.** No dio el correo, y eso es
                // una decisión suya. Lo que toca es que sepa qué ocurre, no
                // hacerle sentir que hizo algo mal.
                const Aviso(
                  tono: TonoDeAviso.informativo,
                  claveDelMensaje: Key('alta-sin-acudiente'),
                  mensaje: 'Todavía no nos diste el correo de tu acudiente. '
                      'Puedes usar la app igual, pero lo que anotes se quedará '
                      'en tu teléfono hasta que alguien dé el permiso. Podrás '
                      'añadirlo más adelante.',
                ),
              ],

              const SizedBox(height: Espaciado.seccion),
              BotonPrincipal(
                clave: const Key('alta-continuar'),
                etiqueta: 'Entrar',
                alPulsar: alContinuar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
