/// Lo que el entrenador revisa antes de firmar (M13 a M17).
///
/// Se le enseña **lo que se generó**, no un resumen optimista: cada mesociclo
/// con su fase, sus semanas, sus sesiones, su versión de metodología y la
/// auditoría de la sección 16 que ya pinta `tabla_auditoria.dart`.
///
/// **Dos actos y no uno.** Firmar mueve los mesociclos a `aprobado`; entregar
/// los publica y los asigna. Firmar no es entregar, aquí como desde la feature
/// 001, y la pantalla no los junta en un botón aunque sea más corto.
///
/// Y los dos son **un solo acto para él**, por muchos mesociclos que haya
/// (M15, M16): si tuviera que firmar siete veces, la enmienda de la
/// constitución v2.0.0 se habría cumplido en la letra y no en el fondo.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/reajuste.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/boton.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/etiqueta_de_estado.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/planes/tabla_auditoria.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class PantallaRevisarMacrociclo extends StatefulWidget {
  const PantallaRevisarMacrociclo({
    super.key,
    required this.guardado,
    required this.hoy,
    required this.planes,
    required this.asignaciones,
    required this.macrociclos,
    this.alVolver,
    this.alEntregar,
  });

  final MacrocicloGuardado guardado;
  final DateTime hoy;

  final RepositorioPlanes planes;
  final RepositorioAsignaciones asignaciones;
  final RepositorioMacrociclos macrociclos;

  final VoidCallback? alVolver;

  /// Qué hacer cuando ya se entregó: normalmente, volver al HUB.
  final VoidCallback? alEntregar;

  @override
  State<PantallaRevisarMacrociclo> createState() =>
      _PantallaRevisarMacrocicloState();
}

class _PantallaRevisarMacrocicloState extends State<PantallaRevisarMacrociclo> {
  late Macrociclo _macrociclo = widget.guardado.macrociclo;
  late List<Plan> _mesociclos = widget.guardado.mesociclos;

  bool _trabajando = false;
  String? _problema;

  /// Qué bloques marcó para reajustar. Vacío mientras no marque nada: no hay
  /// reajuste por omisión.
  final Set<String> _aReajustar = <String>{};

  Future<void> _reajustar() async {
    setState(() {
      _trabajando = true;
      _problema = null;
    });

    try {
      final reajustado = await reajustarElMacrociclo(
        macrociclo: _macrociclo,
        mesociclos: _mesociclos,
        cualesSeReajustan: _aReajustar,
        planes: widget.planes,
        macrociclos_: widget.macrociclos,
        hoy: widget.hoy,
      );

      // **Dos actos, otra vez.** Las versiones nuevas nacen en borrador: hasta
      // que no se firman y se entregan, el nadador sigue con lo que tenía.
      await firmarYEntregarElReajuste(
        reajustado: reajustado,
        planes: widget.planes,
        asignaciones: widget.asignaciones,
        hoy: widget.hoy,
      );

      if (!mounted) return;
      setState(() {
        _macrociclo = reajustado.macrociclo;
        _mesociclos = [
          for (final mesociclo in reajustado.mesociclos)
            mesociclo.copiarCon(estado: EstadoPlan.publicado),
        ];
        _aReajustar.clear();
        _trabajando = false;
      });
    } on Object catch (problema) {
      if (!mounted) return;
      setState(() {
        _problema = 'No se reajustó nada: $problema';
        _trabajando = false;
      });
    }
  }

  RevisionDelMacrociclo get _revision =>
      revisarElMacrociclo(macrociclo: _macrociclo, mesociclos: _mesociclos);

  Future<void> _firmar() async {
    setState(() {
      _trabajando = true;
      _problema = null;
    });

    try {
      final firmado = await firmarElMacrociclo(
        macrociclo: _macrociclo,
        mesociclos: _mesociclos,
        planes: widget.planes,
        macrociclos: widget.macrociclos,
        hoy: widget.hoy,
      );

      if (!mounted) return;
      setState(() {
        _macrociclo = firmado;
        _mesociclos = [
          for (final mesociclo in _mesociclos)
            mesociclo.copiarCon(
              estado: EstadoPlan.aprobado,
              fechaAprobacion: widget.hoy,
            ),
        ];
        _trabajando = false;
      });
    } on Object catch (problema) {
      if (!mounted) return;
      setState(() {
        _problema = problema.toString();
        _trabajando = false;
      });
    }
  }

  Future<void> _entregar() async {
    setState(() {
      _trabajando = true;
      _problema = null;
    });

    try {
      final entregado = await entregarElMacrociclo(
        macrociclo: _macrociclo,
        mesociclos: _mesociclos,
        planes: widget.planes,
        asignaciones: widget.asignaciones,
        macrociclos: widget.macrociclos,
        hoy: widget.hoy,
      );

      if (!mounted) return;
      setState(() {
        _macrociclo = entregado;
        _mesociclos = [
          for (final mesociclo in _mesociclos)
            mesociclo.copiarCon(estado: EstadoPlan.publicado),
        ];
        _trabajando = false;
      });
      widget.alEntregar?.call();
    } on Object catch (problema) {
      if (!mounted) return;
      setState(() {
        // La entrega es todo o nada: si falló, no quedó nada entregado, y eso
        // se le dice en lugar de dejarle adivinar qué llegó.
        _problema =
            'No se entregó nada: $problema. El nadador no tiene parte del '
            'macrociclo, tiene cero.';
        _trabajando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final revision = _revision;
    final texto = Theme.of(context).textTheme;
    final sinFirmar = _macrociclo.estado == EstadoPlan.borrador;
    final firmado = _macrociclo.estado == EstadoPlan.aprobado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar el macrociclo'),
        leading: widget.alVolver == null
            ? null
            : BackButton(onPressed: widget.alVolver),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(Espaciado.amplio),
          children: [
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_macrociclo.nombre, style: texto.titleLarge),
                      ),
                      EtiquetaDeEstado(estado: _macrociclo.estado),
                    ],
                  ),
                  const SizedBox(height: Espaciado.corto),
                  Text(
                    '${_mesociclos.length} mesociclos · '
                    '${_mesociclos.fold(0, (t, m) => t + m.microciclos.length)} '
                    'microciclos · '
                    '${_mesociclos.fold(0, (t, m) => t + m.sesiones.length)} '
                    'sesiones',
                    key: const Key('resumen-del-macrociclo'),
                    style: texto.bodyMedium,
                  ),
                  const SizedBox(height: Espaciado.minimo),
                  Text(
                    'Competencia el '
                    '${_macrociclo.fechaDeCompetencia.day}/'
                    '${_macrociclo.fechaDeCompetencia.month}/'
                    '${_macrociclo.fechaDeCompetencia.year}',
                    style: texto.bodySmall,
                  ),
                  // FR-013: cada nivel registra bajo qué metodología se
                  // construyó, y se puede ver sin abrir la base de datos.
                  Text(
                    'Metodología ${_macrociclo.versionMetodologia}',
                    key: const Key('version-del-macrociclo'),
                    style: texto.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: Espaciado.seccion),
            const CabeceraSeccion(
              titulo: 'Lo que usted confirmó',
              icono: Icons.edit_note_outlined,
            ),
            const SizedBox(height: Espaciado.corto),
            Tarjeta(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modelo de la prueba', style: texto.titleSmall),
                  Text(
                    _macrociclo.estructura.modeloDeLaPrueba,
                    key: const Key('modelo-de-la-prueba'),
                    style: texto.bodyMedium,
                  ),
                  const SizedBox(height: Espaciado.normal),
                  Text('Modelo del nadador', style: texto.titleSmall),
                  Text(
                    _macrociclo.estructura.modeloDelNadador,
                    key: const Key('modelo-del-nadador'),
                    style: texto.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: Espaciado.seccion),
            CabeceraSeccion(
              titulo: 'Los mesociclos',
              icono: Icons.layers_outlined,
              cifra: '${_mesociclos.length}',
            ),
            const SizedBox(height: Espaciado.corto),

            for (var i = 0; i < _mesociclos.length; i++)
              _Mesociclo(
                key: ValueKey('mesociclo-$i'),
                indice: i,
                plan: _mesociclos[i],
                auditoria: revision.porMesociclo[i],
              ),

            if (_problema != null) ...[
              const SizedBox(height: Espaciado.seccion),
              Aviso(
                tono: TonoDeAviso.error,
                mensaje: _problema!,
                claveDelMensaje: const Key('problema-al-firmar'),
              ),
            ],

            if (!revision.sePuedeFirmar && sinFirmar) ...[
              const SizedBox(height: Espaciado.seccion),
              Aviso(
                tono: TonoDeAviso.error,
                titulo: 'Todavía no se puede firmar',
                mensaje:
                    'Hay mesociclos que no pasan la auditoría de la sección '
                    '16. El macrociclo no se firma a medias.',
                detalles: [
                  for (final impedimento in revision.impedimentos)
                    LineaDeAviso(
                      icono: Icons.block_outlined,
                      texto: impedimento.toString(),
                    ),
                ],
              ),
            ],

            const SizedBox(height: Espaciado.seccion),

            if (sinFirmar)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Firmar mueve los ${_mesociclos.length} mesociclos a '
                    'aprobado. Es un solo acto. Firmar no es entregar: el '
                    'nadador no verá nada hasta que lo entregue.',
                    style: texto.bodySmall,
                  ),
                  const SizedBox(height: Espaciado.normal),
                  BotonPrincipal(
                    clave: const Key('firmar-el-macrociclo'),
                    etiqueta: 'Firmar el macrociclo',
                    icono: Icons.draw_outlined,
                    trabajando: _trabajando,
                    alPulsar: revision.sePuedeFirmar && !_trabajando
                        ? _firmar
                        : null,
                  ),
                ],
              )
            else if (firmado)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Firmado. Entregar lo publica y lo asigna completo: o '
                    'llegan los ${_mesociclos.length} mesociclos o no llega '
                    'ninguno.',
                    style: texto.bodySmall,
                  ),
                  const SizedBox(height: Espaciado.normal),
                  BotonPrincipal(
                    clave: const Key('entregar-el-macrociclo'),
                    etiqueta: 'Entregar al nadador',
                    icono: Icons.send_outlined,
                    trabajando: _trabajando,
                    alPulsar: _trabajando ? null : _entregar,
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Aviso(
                    tono: TonoDeAviso.exito,
                    mensaje:
                        'Entregado. El nadador ya ve el camino completo en '
                        'Ver Plan.',
                    claveDelMensaje: const Key('ya-entregado'),
                  ),

                  // El reajuste (M30, sección 4 paso 8). **Se entra por aquí
                  // y por ningún disparador automático**: la app no reajusta
                  // por clara que parezca la adherencia.
                  const SizedBox(height: Espaciado.seccion),
                  const CabeceraSeccion(
                    titulo: 'Reajustar',
                    icono: Icons.tune_outlined,
                  ),
                  const SizedBox(height: Espaciado.corto),
                  Text(
                    'Marque los bloques que quiere volver a generar con lo '
                    'que ha visto. Cada uno recibe una versión nueva; lo que '
                    'el nadador ya anotó no se toca, y se le avisa una vez.',
                    style: texto.bodySmall,
                  ),
                  const SizedBox(height: Espaciado.normal),

                  for (var i = 0; i < _mesociclos.length; i++)
                    CheckboxListTile(
                      key: Key('reajustar-$i'),
                      value: _aReajustar.contains(_mesociclos[i].id),
                      onChanged: _trabajando
                          ? null
                          : (marcado) => setState(() {
                              final id = _mesociclos[i].id;
                              if (id == null) return;
                              if (marcado ?? false) {
                                _aReajustar.add(id);
                              } else {
                                _aReajustar.remove(id);
                              }
                            }),
                      title: Text('Bloque ${i + 1}: ${_mesociclos[i].nombre}'),
                      contentPadding: EdgeInsets.zero,
                    ),

                  const SizedBox(height: Espaciado.normal),
                  BotonPrincipal(
                    clave: const Key('reajustar-el-macrociclo'),
                    etiqueta: _aReajustar.length <= 1
                        ? 'Reajustar el bloque marcado'
                        : 'Reajustar los ${_aReajustar.length} bloques '
                              'marcados',
                    icono: Icons.tune_outlined,
                    trabajando: _trabajando,
                    alPulsar: _aReajustar.isEmpty || _trabajando
                        ? null
                        : _reajustar,
                  ),
                ],
              ),

            const SizedBox(height: Espaciado.generoso),
          ],
        ),
      ),
    );
  }
}

class _Mesociclo extends StatelessWidget {
  const _Mesociclo({
    super.key,
    required this.indice,
    required this.plan,
    required this.auditoria,
  });

  final int indice;
  final Plan plan;
  final ResultadoAuditoria auditoria;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.normal),
      child: Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(plan.nombre, style: texto.titleMedium)),
                EtiquetaDeEstado(estado: plan.estado),
              ],
            ),
            const SizedBox(height: Espaciado.corto),
            Text(
              '${plan.microciclos.length} '
              '${plan.microciclos.length == 1 ? 'microciclo' : 'microciclos'} · '
              '${plan.sesiones.length} sesiones · ${plan.metros} m · '
              '${plan.porcentajeTecnico.toStringAsFixed(0)}% técnico',
              key: Key('resumen-mesociclo-$indice'),
              style: texto.bodyMedium,
            ),
            Text(
              'Metodología ${plan.versionMetodologia ?? 'sin sellar'}',
              key: Key('version-mesociclo-$indice'),
              style: texto.bodySmall,
            ),
            const SizedBox(height: Espaciado.normal),
            ExpansionTile(
              key: Key('auditoria-mesociclo-$indice'),
              tilePadding: EdgeInsets.zero,
              title: Text('Auditoría de la sección 16', style: texto.titleSmall),
              children: [TablaAuditoria(resultado: auditoria)],
            ),
          ],
        ),
      ),
    );
  }
}
