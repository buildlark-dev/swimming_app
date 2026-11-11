/// Lo que el entrenador lee de una nadadora.
///
/// Sus sesiones de la más reciente a la más antigua, cada una con lo que ella
/// contestó al lado, su adherencia leída del progreso que ya se calcula, y las
/// molestias aparte y arriba.
///
/// Cuatro cosas que esta pantalla distingue y que es tentador juntar:
///
/// 1. **«No contestó nada» no es «no se pudo leer».** Lo primero se dice con
///    una frase; lo segundo con un aviso. Convertir el segundo en el primero
///    es el defecto que la feature 009 entregó dos veces: un `catch` que
///    devuelve `const []` y una pantalla que se pinta perfecta y miente.
/// 2. **Un fallo no enseña media lectura como completa.** Sin registros no hay
///    adherencia: un número calculado sobre lo que no se pudo leer es un
///    número inventado.
/// 3. **La molestia va aparte.** Arriba y marcada, no en el flujo de
///    observaciones (FR-009, FR-010).
/// 4. **La app no opina.** Lo que ella escribió, tal cual, sin severidad, sin
///    puntuación y sin ningún control que cambie un plan (FR-011,
///    principio IV).
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/analisis/lectura_del_nadador.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/analisis/sesion_y_respuesta.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class LecturaDeUnNadador extends StatefulWidget {
  const LecturaDeUnNadador({
    super.key,
    required this.nadador,
    required this.macrocicloId,
    required this.macrociclos,
    required this.planes,
    required this.registros,
    required this.hoy,
    this.peticiones,
    this.asignaciones,
  });

  final Nadador nadador;

  /// El macrociclo que tiene. **Vacío cuando no tiene ninguno**, y entonces la
  /// pantalla lo dice en lugar de dejar un marco.
  final String macrocicloId;

  final RepositorioMacrociclos macrociclos;
  final RepositorioPlanes planes;

  /// **El lector del servidor**, no el del dispositivo (decisión D3). Su
  /// teléfono nunca escribió las respuestas de ella.
  final RepositorioRegistros registros;

  final DateTime hoy;

  /// Lo que ella pidió que mirara (US4). **Nulo sin servidor**: entonces no
  /// hay peticiones que leer ni dónde escribir que las vio.
  final RepositorioPeticionesDeFeedback? peticiones;

  /// Lo que se le entregó **fuera de un macrociclo**.
  ///
  /// Hallazgo del recorrido en el Pixel 7: una nadadora con un plan entregado
  /// directamente —lo que hacen las features 003, 004 y 007, y sigue siendo un
  /// camino válido— no tiene macrociclo, así que esta pantalla no encontraba
  /// mesociclos, ni sesiones, ni respuestas, y decía «todavía no tiene
  /// macrociclo» con sus dos respuestas y su molestia en el servidor.
  ///
  /// Es el mismo respaldo que M23 le dio al nadador en `Ver Plan`, al otro
  /// lado de la app.
  final RepositorioAsignaciones? asignaciones;

  @override
  State<LecturaDeUnNadador> createState() => _LecturaDeUnNadadorState();
}

class _LecturaDeUnNadadorState extends State<LecturaDeUnNadador> {
  LecturaDelNadador? _lectura;
  bool _cargando = true;
  String? _problema;
  String? _problemaAlMarcar;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Los mesociclos de su macrociclo, que es el camino normal desde la 009.
  Future<List<Plan>> _losDelMacrociclo() async {
    final macrociclo = await widget.macrociclos.obtener(widget.macrocicloId);

    final mesociclos = <Plan>[];
    for (final id in macrociclo?.mesociclos ?? const <String>[]) {
      final plan = await widget.planes.obtener(id);
      if (plan != null) mesociclos.add(plan);
    }
    return mesociclos;
  }

  /// El respaldo: **lo que se le entregó suelto**, fuera de todo macrociclo.
  ///
  /// Las dos condiciones por separado, igual que en las reglas: asignado
  /// **y** publicado. Un plan firmado y sin entregar no es suyo todavía
  /// —firmar no es entregar— y una asignación a un borrador no debería
  /// existir, pero si existiera no convertiría el borrador en algo que ella
  /// nadó.
  ///
  /// **Y solo cuando no hay macrociclo.** Mezclar los dos le contaría al
  /// entrenador dos veces lo que programó, porque los mesociclos de un
  /// macrociclo también se asignan.
  Future<List<Plan>> _loQueSeLeEntrego() async {
    final repo = widget.asignaciones;
    if (repo == null) return const [];

    final suyas = await repo.deNadador(widget.nadador.id ?? '');

    final planes = <Plan>[];
    for (final asignacion in suyas) {
      final plan = await widget.planes.obtener(asignacion.planId);
      if (plan != null && plan.estado == EstadoPlan.publicado) {
        planes.add(plan);
      }
    }
    return planes;
  }

  Future<void> _cargar() async {
    try {
      final mesociclos = widget.macrocicloId.isEmpty
          ? await _loQueSeLeEntrego()
          : await _losDelMacrociclo();

      // Ni macrociclo ni planes entregados: ahí sí no hay nada que leer.
      if (mesociclos.isEmpty) {
        if (!mounted) return;
        setState(() => _cargando = false);
        return;
      }

      final lectura = await leerAlNadador(
        nadador: widget.nadador,
        mesociclos: mesociclos,
        registros: widget.registros,
        planes: widget.planes,
        hoy: widget.hoy,
        peticiones: widget.peticiones,
      );

      if (!mounted) return;
      setState(() {
        _lectura = lectura;
        _cargando = false;
      });
    } on Object catch (problema) {
      // **No se convierte en una lectura vacía.** Se dice.
      if (!mounted) return;
      setState(() {
        _problema = problema.toString();
        _cargando = false;
      });
    }
  }

  /// Marca vista la pregunta de una sesión.
  ///
  /// **Toca `vistaEn` y nada más**, porque la regla solo acepta esa escritura:
  /// lo que ella escribió es suyo y la única palabra del entrenador aquí es
  /// «la vi». Después se vuelve a leer, que es más barato que inventarse el
  /// estado nuevo en la pantalla y que no puede discrepar del servidor.
  Future<void> _marcarVista(String peticionId) async {
    final repo = widget.peticiones;
    if (repo == null) return;

    try {
      await repo.marcarVista(peticionId, DateTime.now());
    } on Object catch (problema) {
      if (!mounted) return;
      setState(() => _problemaAlMarcar = problema.toString());
      return;
    }

    if (!mounted) return;
    setState(() => _problemaAlMarcar = null);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_problema != null) {
      return Padding(
        padding: const EdgeInsets.all(Espaciado.amplio),
        child: Aviso(
          tono: TonoDeAviso.error,
          titulo: 'No se pudo leer su análisis',
          mensaje: _problema!,
          claveDelMensaje: const Key('no-se-pudo-leer-su-analisis'),
          detalles: const [
            Text(
              'Esto no quiere decir que no haya contestado: quiere decir que '
              'no se pudo leer lo que contestó.',
            ),
          ],
        ),
      );
    }

    final lectura = _lectura;
    if (lectura == null) {
      return const Padding(
        padding: EdgeInsets.all(Espaciado.amplio),
        child: EstadoVacio(
          key: Key('sin-macrociclo-que-leer'),
          icono: Icons.timeline_outlined,
          titulo: 'Todavía no tiene nada entregado',
          queHacer:
              'Empiézale un macrociclo desde «Ver Plan», o entrégale un plan, '
              'y aquí aparecerá lo que vaya contestando.',
        ),
      );
    }

    final id = widget.nadador.id ?? '';
    final texto = Theme.of(context).textTheme;

    return ListView(
      key: Key('lectura-de-$id'),
      padding: const EdgeInsets.all(Espaciado.amplio),
      children: [
        CabeceraSeccion(
          titulo: widget.nadador.nombre.isEmpty
              ? 'Sin nombre'
              : widget.nadador.nombre,
          icono: Icons.person_outline,
        ),
        const SizedBox(height: Espaciado.corto),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adherencia: sesiones cumplidas', style: texto.labelMedium),
              Text(
                key: Key('adherencia-de-$id'),
                lectura.adherencia.descripcion,
                style: texto.titleMedium,
              ),
              const SizedBox(height: Espaciado.corto),
              Text(
                key: const Key('version-de-metodologia'),
                'Construido con la metodología '
                '${lectura.versionMetodologia ?? 'sin versión registrada'}',
                style: texto.bodySmall,
              ),
              if (lectura.esperandoQueLasMire.isNotEmpty) ...[
                const SizedBox(height: Espaciado.corto),
                // **Cuántas esperan, arriba.** Una pregunta que solo se ve
                // dentro de su tarjeta, entre cuarenta y dos, está enterrada
                // igual que lo estaría una molestia; esto es la misma lección
                // de FR-010 aplicada a lo que ella preguntó.
                Text(
                  key: Key('esperan-que-las-mire-$id'),
                  lectura.esperandoQueLasMire.length == 1
                      ? 'Te preguntó algo de 1 sesión'
                      : 'Te preguntó algo de '
                            '${lectura.esperandoQueLasMire.length} sesiones',
                  style: texto.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (lectura.conMolestia.isNotEmpty ||
            lectura.molestiasSinSesion.isNotEmpty) ...[
          const SizedBox(height: Espaciado.seccion),
          _LasMolestias(key: Key('molestias-de-$id'), lectura: lectura),
        ],

        // Lo que contestó sobre sesiones que no están en su plan.
        //
        // **Se dice, no se cuelga de una sesión cualquiera.** Inventarle una
        // sesión sería peor que no enseñarla: le diría al entrenador que ella
        // contestó algo que no contestó.
        if (lectura.sinSesion.isNotEmpty) ...[
          const SizedBox(height: Espaciado.seccion),
          _SinSesion(key: Key('respuestas-sin-sesion'), lectura: lectura),
        ],

        const SizedBox(height: Espaciado.seccion),
        if (lectura.noHaContestadoNada)
          const Padding(
            padding: EdgeInsets.only(bottom: Espaciado.normal),
            child: EstadoVacio(
              key: Key('no-ha-contestado-nada'),
              icono: Icons.hourglass_empty_outlined,
              titulo: 'Todavía no ha contestado ninguna sesión',
              queHacer:
                  'Lo programado está abajo. Cuando marque una sesión, su '
                  'respuesta aparecerá al lado.',
            ),
          ),
        const CabeceraSeccion(titulo: 'Sus sesiones'),
        const SizedBox(height: Espaciado.corto),
        if (_problemaAlMarcar != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Espaciado.normal),
            child: Aviso(
              tono: TonoDeAviso.error,
              mensaje: 'No se pudo marcar como vista: $_problemaAlMarcar',
              claveDelMensaje: const Key('no-se-pudo-marcar-vista'),
            ),
          ),

        for (final respuesta in lectura.respuestas)
          SesionYRespuesta(
            respuesta: respuesta,
            alMarcarVista:
                widget.peticiones == null || respuesta.peticion == null
                ? null
                : () => _marcarVista(respuesta.peticion!.id),
          ),
      ],
    );
  }
}

/// Las molestias, juntas y arriba.
///
/// **Sin severidad, sin orden de gravedad y sin siguiente paso.** Se enseña la
/// fecha y lo que ella escribió, tal cual. El principio IV reserva al
/// entrenador la decisión sobre el entrenamiento, y una app que ordenara estos
/// reportes por «importancia» estaría tomando la primera mitad de esa decisión
/// por él.
class _LasMolestias extends StatelessWidget {
  const _LasMolestias({super.key, required this.lectura});

  final LecturaDelNadador lectura;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabeceraSeccion(
            titulo: 'Lo que contó que le molestaba',
            icono: Icons.healing_outlined,
          ),
          const SizedBox(height: Espaciado.corto),
          for (final respuesta in lectura.conMolestia)
            Padding(
              padding: const EdgeInsets.only(bottom: Espaciado.corto),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cuando(respuesta.sesion.fecha), style: texto.labelSmall),
                  Text(
                    key: Key(
                      'molestia-contada-en-${respuesta.sesion.id ?? ''}',
                    ),
                    respuesta.registro!.molestia!.descripcion,
                    style: texto.bodyMedium,
                  ),
                  if (respuesta.registro!.molestia!.zonaDelCuerpo
                      .trim()
                      .isNotEmpty)
                    Text(
                      respuesta.registro!.molestia!.zonaDelCuerpo,
                      style: texto.bodySmall,
                    ),
                ],
              ),
            ),

          // Las huérfanas que llevan molestia, aquí también. Son las que no se
          // pueden perder (principio VIII).
          for (final registro in lectura.molestiasSinSesion)
            Padding(
              padding: const EdgeInsets.only(bottom: Espaciado.corto),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cuando(registro.registradoEn)} · de una sesión que ya '
                    'no está en su plan',
                    style: texto.labelSmall,
                  ),
                  Text(
                    key: Key('molestia-sin-sesion-${registro.sesionId}'),
                    registro.molestia!.descripcion,
                    style: texto.bodyMedium,
                  ),
                  if (registro.molestia!.zonaDelCuerpo.trim().isNotEmpty)
                    Text(
                      registro.molestia!.zonaDelCuerpo,
                      style: texto.bodySmall,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que contestó sobre sesiones que **no están en su plan**.
///
/// Hallazgo del recorrido de la 010 en el Pixel 7: un registro apuntaba a una
/// sesión que no existía, la respuesta se caía sin decir nada, y la lista del
/// `Análisis` seguía marcando a la nadadora porque esa consulta mira la
/// colección de registros y no las sesiones.
///
/// **Se dice, y no se cuelga de una sesión cualquiera.** Inventarle una sesión
/// sería peor que no enseñarla: le diría al entrenador que contestó algo que
/// no contestó. Lo que se enseña es lo que ella escribió y cuándo.
class _SinSesion extends StatelessWidget {
  const _SinSesion({super.key, required this.lectura});

  final LecturaDelNadador lectura;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabeceraSeccion(
            titulo: 'Contestó sobre sesiones que ya no están en su plan',
            icono: Icons.help_outline,
          ),
          const SizedBox(height: Espaciado.corto),
          Text(
            'Son respuestas suyas que no se pueden situar en el plan que tiene '
            'ahora. Se enseñan aquí y no cuentan para la adherencia.',
            style: texto.bodySmall,
          ),
          const SizedBox(height: Espaciado.corto),
          for (final registro in lectura.sinSesion)
            Padding(
              padding: const EdgeInsets.only(bottom: Espaciado.corto),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cuando(registro.registradoEn), style: texto.labelSmall),
                  Text(
                    key: Key('sin-sesion-${registro.sesionId}'),
                    registro.realizada
                        ? (registro.rpePercibido == null
                              ? 'La hizo'
                              : 'La hizo · esfuerzo percibido '
                                    '${registro.rpePercibido} de 10')
                        : 'Dijo que no la hizo',
                    style: texto.bodyMedium,
                  ),
                  if (registro.observaciones.trim().isNotEmpty)
                    Text(registro.observaciones, style: texto.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
