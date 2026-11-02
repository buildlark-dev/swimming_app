/// Ajustes: donde cada quien manda sobre lo suyo.
///
/// Es el destino que hace ejercitables los tres derechos que la Ley 1581
/// reconoce al titular. Estaban construidos en el dominio desde la feature 004
/// —`DerechosDelTitular`, con sus pruebas— y **ninguna pantalla los usaba**. Un
/// derecho que solo existe en el dominio no está concedido.
///
/// Todo lo de aquí es de **quien está dentro** y de nadie más (H19). El
/// entrenador no gobierna desde aquí las cuentas de sus nadadores: lo que él ve
/// de ellos sigue en `Ver Plan`.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/preferencias/apariencia.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/constancia.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/dominio/datos_personales/derechos_del_titular.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/ajustes/apariencia.dart';
import 'package:natacion_app/ui/ajustes/lo_que_acepte.dart';
import 'package:natacion_app/ui/ajustes/mis_datos.dart';
import 'package:natacion_app/ui/ajustes/mis_derechos.dart';
import 'package:natacion_app/ui/ajustes/supresion.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({
    super.key,
    required this.uid,
    required this.repositorioPerfil,
    this.nadadorId,
    this.operaciones,
    this.identidad,
    this.constancias,
    this.derechos,
    this.alElegirApariencia,
    this.conmutadorDeRecorrido,
  });

  /// De quién es esta pantalla. Nunca de otra persona.
  final String uid;

  final RepositorioPerfil repositorioPerfil;

  /// Su ficha de nadador, si tiene. La cuenta del entrenador no tiene.
  final String? nadadorId;

  /// Nulas sin servidor: entonces se ve pero no se corrige, y se dice.
  final OperacionesDelServidor? operaciones;

  final Identidad? identidad;
  final LectorDeConstancias? constancias;
  final DerechosDelTitular? derechos;

  final ValueChanged<Apariencia>? alElegirApariencia;

  /// Solo en modo local: sin rol que consultar, el recorrido se elige a
  /// propósito (decisión D13).
  final Widget? conmutadorDeRecorrido;

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  Perfil? _perfil;
  ConstanciaDeConsentimiento? _constancia;
  bool _cargando = true;
  String? _avisoDeClave;

  /// Qué no se pudo leer, para decirlo. Nulo cuando se leyó todo.
  String? _noSePudoLeer;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Carga cada cosa **por separado**, y si una falla sigue con las demás.
  ///
  /// Antes era un `await` detrás de otro sin red de seguridad: lo que fallara
  /// se llevaba por delante la pantalla entera y la dejaba con la rueda dando
  /// vueltas, que no se distingue de estar tardando. Lo vio el teléfono con la
  /// cuenta de una nadadora —el documento de consentimiento tenía la fecha en
  /// otro formato— y lo que se perdía no era un dato: eran los tres derechos
  /// de la Ley 1581 y el botón de pedir el borrado, inalcanzables.
  ///
  /// Que no se pueda leer algo se dice. Quedarse callado girando, no.
  Future<void> _cargar() async {
    final noSePudo = <String>[];

    Perfil? perfil;
    try {
      perfil = await widget.repositorioPerfil.obtener(widget.uid);
    } catch (_) {
      noSePudo.add('tus datos de cuenta');
    }

    ConstanciaDeConsentimiento? constancia;
    final nadadorId = widget.nadadorId;
    if (nadadorId != null) {
      try {
        constancia = await widget.constancias?.de(nadadorId);
      } catch (_) {
        noSePudo.add('la constancia del consentimiento');
      }
    }

    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _constancia = constancia;
      _cargando = false;
      _noSePudoLeer = noSePudo.isEmpty
          ? null
          : 'No se pudo leer ${noSePudo.join(' ni ')}. Lo demás de esta '
                'pantalla funciona igual.';
    });
  }

  Future<void> _pedirCambioDeClave() async {
    try {
      await widget.identidad?.pedirCambioDeClave();
      if (mounted) {
        setState(
          () => _avisoDeClave =
              'Te mandamos un correo para cambiar la contraseña.',
        );
      }
    } on FalloDeAcceso catch (e) {
      if (mounted) setState(() => _avisoDeClave = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;

    if (_cargando) {
      return const Center(
        key: Key('ajustes-cargando'),
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      key: const Key('ajustes'),
      padding: const EdgeInsets.all(Espaciado.amplio),
      children: [
        if (_noSePudoLeer != null) ...[
          // **De cuidado, no de error.** No se perdió nada: hay algo que no
          // se pudo leer y el resto de la pantalla sirve igual.
          Aviso(
            tono: TonoDeAviso.cuidado,
            icono: Icons.cloud_off_outlined,
            claveDelMensaje: const Key('ajustes-no-se-pudo-leer'),
            mensaje: _noSePudoLeer!,
          ),
          const SizedBox(height: Espaciado.amplio),
        ],
        // Sin perfil no se pueden pintar estas dos, y **lo que viene después
        // sí**: los derechos y el borrado no dependen de haber podido leer
        // el nombre.
        if (perfil != null) ...[
          MisDatos(
            perfil: perfil,
            operaciones: widget.operaciones,
            alCorregir: _cargar,
          ),
          const SizedBox(height: Espaciado.amplio),
          LoQueAcepte(perfil: perfil, constancia: _constancia),
          const SizedBox(height: Espaciado.amplio),
        ],
        MisDerechos(derechos: widget.derechos, nadadorId: widget.nadadorId),
        const SizedBox(height: Espaciado.amplio),
        SeccionApariencia(alElegir: widget.alElegirApariencia),
        if (widget.conmutadorDeRecorrido != null) ...[
          const SizedBox(height: Espaciado.amplio),
          Tarjeta(child: widget.conmutadorDeRecorrido!),
        ],
        const SizedBox(height: Espaciado.amplio),
        _LaCuenta(
          identidad: widget.identidad,
          avisoDeClave: _avisoDeClave,
          alPedirClave: _pedirCambioDeClave,
        ),
        const SizedBox(height: Espaciado.amplio),
        Supresion(
          operaciones: widget.operaciones,
          alSuprimir: () async {
            // Sin datos y sin cuenta, lo que queda es salir. `cerrarSesion`
            // vacía lo local y arranca la app de nuevo, que es justo lo que
            // hace falta aquí.
            await widget.identidad?.cerrarSesion();
          },
        ),
        const SizedBox(height: Espaciado.generoso),
      ],
    );
  }
}

class _LaCuenta extends StatelessWidget {
  const _LaCuenta({
    required this.identidad,
    required this.avisoDeClave,
    required this.alPedirClave,
  });

  final Identidad? identidad;
  final String? avisoDeClave;
  final VoidCallback alPedirClave;

  @override
  Widget build(BuildContext context) {
    if (identidad == null) {
      return const Tarjeta(
        child: Aviso(
          tono: TonoDeAviso.cuidado,
          icono: Icons.cloud_off_outlined,
          mensaje: 'Sin servidor no hay sesión que cerrar.',
        ),
      );
    }

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **Por correo, no en un formulario** (H30). Una pantalla que pide la
          // contraseña nueva sin comprobar quién la escribe deja que cualquiera
          // con el teléfono desbloqueado se quede con la cuenta, y el teléfono
          // lo comparten hermanos.
          OutlinedButton.icon(
            key: const Key('ajustes-cambiar-clave'),
            onPressed: alPedirClave,
            icon: const Icon(Icons.mail_outlined),
            label: const Text('Cambiar mi contraseña'),
          ),
          if (avisoDeClave != null) ...[
            const SizedBox(height: Espaciado.normal),
            Aviso(
              tono: TonoDeAviso.informativo,
              icono: Icons.info_outline,
              mensaje: avisoDeClave!,
            ),
          ],
          const SizedBox(height: Espaciado.normal),
          FilledButton.tonalIcon(
            key: const Key('ajustes-cerrar-sesion'),
            onPressed: () => identidad!.cerrarSesion(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
