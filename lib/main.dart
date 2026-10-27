import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:natacion_app/datos/auth/sesion_firebase.dart';
import 'package:natacion_app/datos/firestore/configuracion.dart';
import 'package:natacion_app/datos/firestore/envio_registros.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/preferencias/apariencia.dart';
import 'package:natacion_app/datos/recursos/biblioteca_empaquetada.dart';
import 'package:natacion_app/datos/recursos/recursos_iniciales.dart';
import 'package:natacion_app/datos/recursos/version_metodologia.dart';
import 'package:natacion_app/datos/red/estado_de_red.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/acceso/estado_sesion.dart';
import 'package:natacion_app/ui/acceso/pantalla_acceso.dart';
import 'package:natacion_app/ui/alta/puerta_del_perfil.dart';
import 'package:natacion_app/ui/consentimiento/enlace_del_acudiente.dart';
import 'package:natacion_app/ui/consentimiento/pagina_del_acudiente.dart';
import 'package:natacion_app/ui/hub/hub.dart';
import 'package:natacion_app/ui/tema/tema.dart';
import 'package:provider/provider.dart';

/// Punto de entrada de la aplicación.
///
/// `USAR_EMULADORES` se pasa con `--dart-define=USAR_EMULADORES=true` y decide
/// si la capa de datos apunta a los emuladores locales. Por omisión es falsa,
/// de modo que un arranque descuidado nunca escriba en un proyecto real.
const bool usarEmuladores = bool.fromEnvironment(
  'USAR_EMULADORES',
  defaultValue: false,
);

void main() {
  runApp(const AppNatacion());
}

class AppNatacion extends StatefulWidget {
  const AppNatacion({
    super.key,
    this.preferencias = const PreferenciasDelDispositivo(),
  });

  final PreferenciasDelDispositivo preferencias;

  @override
  State<AppNatacion> createState() => _AppNatacionState();
}

class _AppNatacionState extends State<AppNatacion> {
  /// Por omisión, la del teléfono: es lo que la app hacía antes de que hubiera
  /// dónde elegir.
  Apariencia _apariencia = Apariencia.delSistema;

  @override
  void initState() {
    super.initState();
    _cargarApariencia();
  }

  Future<void> _cargarApariencia() async {
    final guardada = await widget.preferencias.apariencia();
    if (mounted) setState(() => _apariencia = guardada);
  }

  void _elegir(Apariencia apariencia) =>
      setState(() => _apariencia = apariencia);

  ThemeMode get _modo => switch (_apariencia) {
    Apariencia.claro => ThemeMode.light,
    Apariencia.oscuro => ThemeMode.dark,
    Apariencia.delSistema => ThemeMode.system,
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planificación de natación',
      theme: temaSeguro(Tema.claro),
      darkTheme: temaSeguro(Tema.oscuro),
      // La elección de Ajustes, y si no hay ninguna, la del teléfono. Hasta la
      // feature 007 esto estaba fijo en `system`, con una nota diciendo que el
      // interruptor pertenecía a esta feature.
      themeMode: _modo,

      // **Todo en español, el calendario incluido.**
      //
      // Sin esto el selector de fecha sale en inglés y con formato mm/dd/aaaa.
      // Para quien escribe su fecha de nacimiento eso no es un detalle de
      // estilo: 03/05 significa cosas distintas a los dos lados del Atlántico,
      // y de esa fecha depende si se le pide el consentimiento a un acudiente.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,

      home: PantallaInicio(alElegirApariencia: _elegir),
    );
  }
}

/// El tema, o la apariencia por omisión si no se pudiera construir.
///
/// **Garantía V14**: quedarse sin abrir por un asunto de aspecto no es
/// aceptable. Ya hubo un caso en este proyecto —el arranque sin Firebase del
/// PR #5— donde un fallo que debía degradar tumbaba el arranque entero, y la
/// lección fue que estas cosas se escriben antes de necesitarlas.
///
/// Se atrapa cualquier fallo, no solo las excepciones: un error al construir
/// una escala de color es un `Error`, no una `Exception`, que es exactamente
/// lo que se nos escapó aquella vez.
ThemeData temaSeguro(ThemeData Function() construir) {
  try {
    return construir();
  } catch (_) {
    return ThemeData(useMaterial3: true);
  }
}

/// Carga la Biblioteca Oficial y la versión de metodología antes de abrir la
/// app. Sin biblioteca no se puede comprobar la regla de no invención, así que
/// no se muestra nada hasta tenerla.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, this.alElegirApariencia});

  /// Para que la app entera se repinte con lo que se elija en Ajustes.
  final ValueChanged<Apariencia>? alElegirApariencia;

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late final Future<RecursosIniciales> _recursos = _cargar();

  /// De todo lo que se carga aquí, **solo la biblioteca puede tumbar el
  /// arranque**. Es deliberado: sin ella no se puede comprobar la regla de no
  /// invención, así que no hay app que mostrar. Todo lo demás degrada: la
  /// versión de metodología se marca como desconocida, el índice de términos
  /// queda vacío y Firestore, si no está, deja la app trabajando en local.
  /// Si algún día otro recurso empieza a propagar, el mensaje de error de
  /// abajo pasa a mentir.
  Future<RecursosIniciales> _cargar() async {
    final biblioteca = await CargadorBiblioteca().cargar();
    final version = await CargadorVersionMetodologia().cargar();
    final indice = await CargadorIndiceTerminos().cargar();
    // Firestore puede no estar: sin credenciales, sin emuladores, o sin red.
    // **La app arranca igual.** El nadador lee y escribe en local, y lo
    // pendiente espera. Caerse porque no hay conexión sería justo lo contrario
    // de lo que esta feature promete.
    final datos = await const ConfiguracionDatos(
      usarEmuladores: usarEmuladores,
    ).conectar();

    return RecursosIniciales(
      biblioteca: biblioteca,
      versionMetodologia: version,
      indiceTerminos: indice,
      // La detección de red sondea de verdad en lugar de preguntarle al
      // sistema: «hay wifi» y «el servidor responde» son cosas distintas, y a
      // pie de piscina la segunda es la que importa.
      red: RedPorSondeo(sondear: () async => datos != null),
      transporte: _TransporteSiHayFirestore(datos),
      // Sin Firestore no hay con quién autenticarse. La app arranca igual y
      // entra en modo local, que es lo que permite seguir desarrollando sin
      // levantar los emuladores.
      identidad: datos == null
          ? null
          : SesionFirebase.porOmision(firestore: datos),
      // Por lo mismo: sin servidor no hay a quién llamar. El alta lo dice en
      // lugar de guardar un perfil que no va a ninguna parte.
      operaciones: datos == null
          ? null
          : OperacionesFirebase.porOmision(usarEmuladores: usarEmuladores),
      firestore: datos,
    );
  }

  @override
  Widget build(BuildContext context) {
    // **El enlace del acudiente se atiende antes que nada.**
    //
    // Si la app arranca en `/consentimiento?t=…`, lo que se ve es el
    // formulario, no la pantalla de acceso. El acudiente no tiene cuenta y no
    // va a crearse una para decir que sí: mandarlo a «entra a tu
    // entrenamiento» sería mandarlo a otra app.
    //
    // Esto faltaba desde la feature 004: el formulario existía, el servidor
    // sabía emitir el enlace, y no había nada que entendiera el enlace al
    // llegar (decisión D10).
    final token = tokenDelEnlace();
    if (token != null) {
      return FutureBuilder<RecursosIniciales>(
        future: _recursos,
        builder: (context, instantanea) {
          if (!instantanea.hasData && !instantanea.hasError) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return PaginaDelAcudiente(
            token: token,
            // Sin servidor no se puede canjear nada, y la página lo dice en
            // lugar de enseñar un formulario que no va a funcionar.
            operaciones: instantanea.data?.operaciones,
          );
        },
      );
    }

    return FutureBuilder<RecursosIniciales>(
      future: _recursos,
      builder: (context, instantanea) {
        if (instantanea.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Planificación de natación')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la Biblioteca Oficial de ejercicios.\n'
                  'Sin ella no se puede comprobar la regla de no invención.\n\n'
                  '${instantanea.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (!instantanea.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _Acceso(
          recursos: instantanea.data!,
          alElegirApariencia: widget.alElegirApariencia,
        );
      },
    );
  }
}

/// Decide qué se enseña según haya sesión o no.
///
/// Sin servidor no hay con quién autenticarse, y la app entra en **modo
/// local**. No es un atajo: es el modo en que se desarrolla sin levantar los
/// emuladores, y en él no hay nada que proteger porque no hay dónde guardar
/// nada. Va rotulado para que nadie lo confunda con la app de verdad.
class _Acceso extends StatelessWidget {
  const _Acceso({required this.recursos, this.alElegirApariencia});

  final RecursosIniciales recursos;
  final ValueChanged<Apariencia>? alElegirApariencia;

  @override
  Widget build(BuildContext context) {
    final identidad = recursos.identidad;

    if (identidad == null) {
      return PantallaPrincipal(
        recursos: recursos,
        modoLocal: true,
        alElegirApariencia: alElegirApariencia,
      );
    }

    return ChangeNotifierProvider<SesionActiva>(
      create: (_) => SesionActiva(identidad: identidad),
      child: Consumer<SesionActiva>(
        builder: (context, sesion, _) {
          switch (sesion.estado) {
            case EstadoDeSesion.comprobando:
              // No se enseña la pantalla de acceso mientras no se sepa quién
              // eres: haría parpadear a quien ya tiene sesión cada vez que
              // abre la app al borde de la piscina.
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );

            case EstadoDeSesion.preparando:
              // La cuenta existe; el servidor todavía le está asignando el
              // rol. Dura unos segundos y hay que decirlo, no dejar la
              // pantalla en blanco ni devolver a nadie al login.
              return const _Preparando();

            case EstadoDeSesion.sinRol:
              return _SinRol(
                alReintentar: () => sesion.reintentar(),
                alSalir: () => sesion.cerrarSesion(),
              );

            case EstadoDeSesion.fuera:
              return PantallaAcceso(
                alEnviar:
                    ({
                      required String correo,
                      required String clave,
                      required ModoDeAcceso modo,
                    }) async {
                      try {
                        if (modo == ModoDeAcceso.crear) {
                          await identidad.crearCuenta(
                            correo: correo,
                            clave: clave,
                          );
                        } else {
                          await identidad.entrar(correo: correo, clave: clave);
                        }
                        return null;
                      } on FalloDeAcceso catch (e) {
                        return e.mensaje;
                      }
                    },
              );

            case EstadoDeSesion.dentro:
              // **Antes de entrar, saber quién es.**
              //
              // Una cuenta recién creada y una de las que ya existían desde la
              // feature 004 están en el mismo estado: sin nombre y sin fecha
              // de nacimiento. Las dos recorren los mismos pasos, que es lo
              // que evita tener dos pantallas parecidas.
              //
              // Y es donde se cierra el hueco que importa: si una cuenta
              // antigua resulta ser de un menor, su consentimiento no se
              // habría pedido nunca, porque su alta ya pasó.
              return PuertaDelPerfil(
                // La clave fuerza a reconstruir el estado entero al cambiar de
                // cuenta. Sin esto, el editor, la bandeja y el recorrido del
                // nadador sobrevivirían al cambio y el segundo hermano vería
                // lo del primero.
                key: ValueKey(sesion.cuenta!.id),
                uid: sesion.cuenta!.id,
                // **El correo de la cuenta no viaja en `Cuenta`**, y es a
                // propósito: el dominio guarda lo mínimo (principio V). Sin él
                // la comprobación de «ese es tu propio correo» no puede
                // hacerse en el cliente.
                //
                // No se pierde: **la frontera es el servidor**, que sí conoce
                // el correo del token y rechaza la solicitud. El cliente solo
                // adelantaba el aviso.
                correo: '',
                // Con reintentos: recién iniciada la sesión, la lectura puede
                // fallar porque el cliente todavía no lleva el token nuevo, y
                // ese fallo mandaba al alta a quien ya tenía perfil.
                repositorio: recursos.firestore == null
                    ? RepositorioPerfilEnMemoria()
                    : RepositorioPerfilConReintentos(
                        RepositorioPerfilFirestore(recursos.firestore!),
                      ),
                operaciones: recursos.operaciones,
                nadadorId: sesion.cuenta!.nadadorId,
                dentro: PantallaPrincipal(
                  recursos: recursos,
                  cuenta: sesion.cuenta,
                  alElegirApariencia: alElegirApariencia,
                ),
              );
          }
        },
      ),
    );
  }
}

/// La cuenta existe y el servidor le está asignando el rol.
class _Preparando extends StatelessWidget {
  const _Preparando();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Preparando tu cuenta',
                key: const Key('preparando-cuenta'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tarda unos segundos la primera vez.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hay sesión, pero el rol nunca llegó.
///
/// Se muestra en lugar de devolver al login, porque volver al login invita a
/// registrarse otra vez y el problema se repite igual.
class _SinRol extends StatelessWidget {
  const _SinRol({required this.alReintentar, required this.alSalir});

  final VoidCallback alReintentar;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_disabled_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Tu cuenta quedó a medio preparar',
                  key: const Key('cuenta-sin-rol'),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'La cuenta existe, pero el servidor no terminó de '
                  'configurarla. No hace falta volver a crearla: eso haría '
                  'una cuenta nueva con el mismo problema.\n\n'
                  'Avisa al entrenador.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('boton-reintentar-rol'),
                  onPressed: alReintentar,
                  child: const Text('Volver a intentarlo'),
                ),
                TextButton(onPressed: alSalir, child: const Text('Salir')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Envía registros si hay Firestore, y si no, falla de forma recuperable.
///
/// Un fallo aquí deja el registro **pendiente** y se reintenta (garantía G3).
/// No es una excepción que el nadador deba ver: es el caso normal a pie de
/// piscina, y el único error que sí se le muestra es el de escritura local.
class _TransporteSiHayFirestore implements EnvioDeRegistros {
  const _TransporteSiHayFirestore(this.firestore);

  final FirebaseFirestore? firestore;

  @override
  Future<DateTime> enviar(RegistroDeSesion registro) {
    final instancia = firestore;
    if (instancia == null) {
      throw const FalloDeDatos('Sin conexión con el servidor');
    }
    return EnvioAFirestore(instancia).enviar(registro);
  }
}
