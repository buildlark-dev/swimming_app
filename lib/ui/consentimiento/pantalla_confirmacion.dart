/// Lo que abre el acudiente cuando recibe el enlace.
///
/// Es la única pantalla de esta app que lee alguien que no tiene cuenta, y
/// probablemente la única que lea nunca. Por eso va en español llano, con el
/// texto informativo completo delante y las tres declaraciones explícitas.
///
/// **Lo que se registra son declaraciones, no hechos comprobados.** Que alguien
/// marque «soy el representante legal» no lo convierte en el representante
/// legal; lo que el sistema puede demostrar es quién declaró qué y cuándo.
///
/// Contrato: `specs/004-cuentas-y-consentimiento/contracts/consentimiento.md`.
library;

import 'package:flutter/material.dart';

/// Lo que el acudiente declara al confirmar.
class DeclaracionDelAcudiente {
  const DeclaracionDelAcudiente({
    required this.nombre,
    required this.documento,
    required this.calidad,
    required this.esRepresentanteLegal,
    required this.menorFueOido,
    required this.versionDelTexto,
  });

  final String nombre;
  final String documento;
  final String calidad;
  final bool esRepresentanteLegal;
  final bool menorFueOido;
  final String versionDelTexto;
}

/// Devuelve `null` si quedó registrado, o el mensaje a mostrar si no.
typedef Confirmar = Future<String?> Function(DeclaracionDelAcudiente);

class PantallaConfirmacion extends StatefulWidget {
  const PantallaConfirmacion({
    super.key,
    required this.textoInformativo,
    required this.versionDelTexto,
    required this.alConfirmar,
  });

  final String textoInformativo;
  final String versionDelTexto;
  final Confirmar alConfirmar;

  @override
  State<PantallaConfirmacion> createState() => _PantallaConfirmacionState();
}

class _PantallaConfirmacionState extends State<PantallaConfirmacion> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _documento = TextEditingController();
  final _calidad = TextEditingController();

  bool _esRepresentante = false;
  bool _menorFueOido = false;
  bool _enviando = false;
  String? _error;
  bool _registrado = false;

  @override
  void dispose() {
    _nombre.dispose();
    _documento.dispose();
    _calidad.dispose();
    super.dispose();
  }

  /// Las dos casillas son obligatorias y no se marcan solas.
  ///
  /// Premarcarlas sería un patrón oscuro, y sobre la autorización de datos de
  /// un menor sería algo peor que eso.
  bool get _puedeConfirmar => _esRepresentante && _menorFueOido;

  Future<void> _confirmar() async {
    if (!_formulario.currentState!.validate() || !_puedeConfirmar) return;

    setState(() {
      _enviando = true;
      _error = null;
    });

    final fallo = await widget.alConfirmar(
      DeclaracionDelAcudiente(
        nombre: _nombre.text.trim(),
        documento: _documento.text.trim(),
        calidad: _calidad.text.trim(),
        esRepresentanteLegal: _esRepresentante,
        menorFueOido: _menorFueOido,
        versionDelTexto: widget.versionDelTexto,
      ),
    );

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = fallo;
      _registrado = fallo == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_registrado) return const _Gracias();

    return Scaffold(
      appBar: AppBar(title: const Text('Autorización')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        widget.textoInformativo,
                        key: const Key('texto-informativo'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Quién autoriza',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nombre,
                    key: const Key('campo-nombre'),
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Escriba su nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _documento,
                    key: const Key('campo-documento'),
                    decoration: const InputDecoration(
                      labelText: 'Documento de identidad',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Escriba su documento'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _calidad,
                    key: const Key('campo-calidad'),
                    decoration: const InputDecoration(
                      labelText: 'En calidad de',
                      helperText: 'Padre, madre, acudiente…',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Diga en qué calidad autoriza'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    key: const Key('casilla-representante'),
                    value: _esRepresentante,
                    onChanged: (v) =>
                        setState(() => _esRepresentante = v ?? false),
                    title: const Text(
                      'Declaro que soy el representante legal del nadador',
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('casilla-menor-oido'),
                    value: _menorFueOido,
                    onChanged: (v) =>
                        setState(() => _menorFueOido = v ?? false),
                    title: const Text(
                      'Declaro que escuché al menor antes de autorizar',
                    ),
                    subtitle: const Text(
                      'La norma colombiana lo pide, y no es un trámite: lo que '
                      'se va a guardar es sobre él o ella.',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const Key('error-de-confirmacion'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('boton-confirmar'),
                    onPressed:
                        _enviando || !_puedeConfirmar ? null : _confirmar,
                    child: _enviando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Autorizo'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Puede retirar esta autorización cuando quiera, desde este '
                    'mismo enlace y sin pasar por el entrenador.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Gracias extends StatelessWidget {
  const _Gracias();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                'Quedó registrada su autorización',
                key: const Key('confirmacion-registrada'),
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Le llegará un aviso por el mismo medio. Si usted no fue quien '
                'autorizó, avise al entrenador de inmediato.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
