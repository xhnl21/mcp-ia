// scripts/arc_accessibility.dart

/// ARC-027 (accesibilidad, WCAG 2.2 / ISO 9241-110): lo que un lector de
/// pantalla (TalkBack, VoiceOver) necesita de la capa de presentación.
///
/// - `GestureDetector` no se anuncia solo: va dentro de un `Semantics` (o
///   lo trae en su hijo), salvo `excludeFromSemantics: true`.
/// - `IconButton` sin `tooltip` se lee como «botón» sin nombre.
/// - Las imágenes llevan `semanticLabel` (o `semanticsLabel` en SVG) o
///   `excludeFromSemantics: true` si son decorativas.
///
/// Sin resolución de tipos, `GestureDetector(...)` se lee como llamada y
/// `const Image.asset(...)` como creación de instancia: se aceptan ambas.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Widgets que dan nombre o semántica a lo que envuelven.
const Set<String> _semanticsWrappers = {
  'Semantics',
  'MergeSemantics',
  'ExcludeSemantics',
  'Tooltip',
};

/// Constructores de `IconButton` (no `IconButton.styleFrom`, que es un estilo).
const Set<String?> _iconButtonConstructors = {
  null,
  'filled',
  'filledTonal',
  'outlined',
};

/// Constructores de imagen que deben describirse.
const Set<String> _imageConstructors = {'asset', 'network', 'file', 'memory'};

/// Argumentos que describen una imagen o la excluyen de la semántica.
const Set<String> _imageLabels = {
  'semanticLabel',
  'semanticsLabel',
  'excludeFromSemantics',
};

/// Widget que crea [node]: tipo, constructor con nombre y argumentos.
({String type, String? constructor, ArgumentList args})? widgetCall(
  AstNode node,
) {
  if (node is InstanceCreationExpression) {
    final type = node.constructorName.type;
    final prefix = type.importPrefix?.name.lexeme;
    // Sin resolución, `const Image.network(...)` llega como tipo `network`
    // con prefijo `Image` y sin constructor con nombre.
    return node.constructorName.name == null && prefix != null
        ? (type: prefix, constructor: type.name.lexeme, args: node.argumentList)
        : (
            type: type.name.lexeme,
            constructor: node.constructorName.name?.name,
            args: node.argumentList,
          );
  }
  return switch (node) {
    MethodInvocation(target: null, :final methodName, :final argumentList) => (
      type: methodName.name,
      constructor: null,
      args: argumentList,
    ),
    MethodInvocation(
      target: SimpleIdentifier(:final name),
      :final methodName,
      :final argumentList,
    ) =>
      (type: name, constructor: methodName.name, args: argumentList),
    _ => null,
  };
}

/// Problema de accesibilidad de [node], o `null` si no hay.
String? accessibilityProblem(AstNode node) {
  final call = widgetCall(node);
  if (call == null) return null;
  final args = _namedArgs(call.args);
  switch (call.type) {
    case 'GestureDetector':
      if (args.contains('excludeFromSemantics') ||
          _hasWrapperAncestor(node) ||
          _containsSemantics(call.args)) {
        return null;
      }
      return 'GestureDetector sin Semantics: el lector de pantalla no anuncia qué hace el toque. Envuélvelo en Semantics(button: true, label: …) o usa un botón de Material.';
    case 'IconButton' when _iconButtonConstructors.contains(call.constructor):
      if (args.contains('tooltip') || _hasWrapperAncestor(node)) return null;
      return 'IconButton sin tooltip: el lector de pantalla lo lee como «botón» sin nombre. Agrega tooltip: con lo que hace.';
    case 'Image' when _imageConstructors.contains(call.constructor):
    case 'SvgPicture' when call.constructor != null:
      if (args.any(_imageLabels.contains) || _hasWrapperAncestor(node)) {
        return null;
      }
      return '${call.type}.${call.constructor} sin semanticLabel: descríbela, o marca excludeFromSemantics: true si es decorativa.';
  }
  return null;
}

Set<String> _namedArgs(ArgumentList args) => {
  for (final arg in args.arguments.whereType<NamedArgument>()) arg.name.lexeme,
};

/// `true` si [node] está dentro de un widget de semántica del mismo método
/// o función (no sube más allá: otro build no garantiza que lo envuelva).
bool _hasWrapperAncestor(AstNode node) {
  for (AstNode? p = node.parent; p != null; p = p.parent) {
    if (p is MethodDeclaration ||
        p is FunctionDeclaration ||
        p is ClassDeclaration) {
      return false;
    }
    final call = widgetCall(p);
    if (call != null && _semanticsWrappers.contains(call.type)) return true;
  }
  return false;
}

/// `true` si los argumentos crean un `Semantics` (p. ej. en `child:`).
bool _containsSemantics(ArgumentList args) {
  final finder = _WrapperFinder();
  args.accept(finder);
  return finder.found;
}

class _WrapperFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  void _check(AstNode node) {
    final call = widgetCall(node);
    if (call != null && _semanticsWrappers.contains(call.type)) found = true;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _check(node);
    super.visitMethodInvocation(node);
  }
}
