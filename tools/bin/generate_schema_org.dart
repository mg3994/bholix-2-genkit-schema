import 'dart:convert';
import 'dart:io';

import '../lib/schema_org_parser.dart';

void main(List<String> args) async {
  final schemaUrl = args.isNotEmpty
      ? args[0]
      : 'https://schema.org/version/latest/schemaorg-current-https.jsonld';

  final parser = await SchemaOrgParser.fetchFromUrl(schemaUrl);
  final parsedData = parser.parse();

  // Filter classes to only include schema.org namespace (id starts with 'schema:')
  final schemaClasses = <String, SchemaClass>{};
  for (final entry in parsedData.classes.entries) {
    if (entry.key.startsWith('schema:')) {
      schemaClasses[entry.key] = entry.value;
    }
  }

  final schemaProperties = <String, SchemaProperty>{};
  for (final entry in parsedData.properties.entries) {
    if (entry.key.startsWith('schema:')) {
      schemaProperties[entry.key] = entry.value;
    }
  }

  final outputDir = Directory('lib/src/schema_org');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final generator = SchemaCodeGenerator(
    classes: schemaClasses,
    properties: schemaProperties,
    dataTypes: parsedData.dataTypes,
    enumValues: parsedData.enumValues,
  );

  final generatedFiles = generator.generateAll();

  for (final entry in generatedFiles.entries) {
    final file = File('lib/src/schema_org/${entry.key}');
    await file.writeAsString(entry.value);
  }

  final exportFile = File('lib/schema_org.dart');
  await exportFile.writeAsString('''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema.org Genkit Dart Export Library

export 'src/schema_org/schema_core.dart';
export 'src/schema_org/schema_org.dart';
''');
}

/// Generator that creates Dart files with Genkit @Schema() classes from parsed Schema.org ontology.
class SchemaCodeGenerator {
  final Map<String, SchemaClass> classes;
  final Map<String, SchemaProperty> properties;
  final Set<String> dataTypes;
  final Map<String, SchemaEnumValue> enumValues;

  SchemaCodeGenerator({
    required this.classes,
    required this.properties,
    required this.dataTypes,
    required this.enumValues,
  });

  Map<String, String> generateAll() {
    final files = <String, String>{};

    files['schema_core.dart'] = _generateCoreLibrary();
    files['schema_org.dart'] = _generateClassesLibrary();

    return files;
  }

  String _generateCoreLibrary() {
    return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema.org Genkit Dart Core Library

/// Annotation class for Genkit / Schemantic compatibility
class Schema {
  final String? description;
  const Schema({this.description});
}

/// Base interface for all Schema.org entities
@Schema()
abstract class \$SchemaThing {
  @Schema(description: 'JSON-LD context declaration')
  String? get context;

  @Schema(description: 'Schema.org type name')
  String get type;
}

/// Representation of localized text with language tag support in Schema.org
@Schema()
abstract class \$LocalizedString {
  @Schema(description: 'The text value')
  String get value;

  @Schema(description: 'The BCP 47 language code, e.g. en, fr, hi')
  String? get language;
}

/// Generic wrapper for multi-type or union values in Schema.org properties
@Schema()
abstract class \$SchemaUnion {
  @Schema(description: 'String value if applicable')
  String? get stringValue;

  @Schema(description: 'Numeric value if applicable')
  num? get numberValue;

  @Schema(description: 'Boolean value if applicable')
  bool? get booleanValue;

  @Schema(description: 'List of localized strings')
  List<\$LocalizedString>? get localizedValues;

  @Schema(description: 'Raw object or URI reference')
  Object? get objectValue;
}
''';
  }

  String _generateClassesLibrary() {
    final sb = StringBuffer();

    sb.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    sb.writeln('// Schema.org Genkit Dart Types');
    sb.writeln();
    sb.writeln(
      "// ignore_for_file: annotate_overrides, non_constant_identifier_names",
    );
    sb.writeln("import 'schema_core.dart';");
    sb.writeln();

    // Group properties by target class domain
    final domainProperties = <String, List<SchemaProperty>>{};
    for (final prop in properties.values) {
      for (final domainId in prop.domainIds) {
        domainProperties.putIfAbsent(domainId, () => []).add(prop);
      }
    }

    // Sort class IDs deterministically
    final sortedClassIds = classes.keys.toList()..sort();

    for (final classId in sortedClassIds) {
      final cls = classes[classId]!;
      final className = _toDartClassName(cls.name);
      final schemaClassName = '\$$className';

      // Determine parents/implements
      final implementsList = <String>[];
      for (final parentId in cls.parentIds) {
        if (classes.containsKey(parentId)) {
          final parentName = classes[parentId]!.name;
          implementsList.add('\$${_toDartClassName(parentName)}');
        }
      }
      if (implementsList.isEmpty) {
        implementsList.add('\$SchemaThing');
      }

      final implementsClause = 'implements ${implementsList.join(', ')} ';

      // Doc comment
      sb.writeln('/// ${_escapeComment(cls.comment)}');
      sb.writeln('@Schema()');
      sb.writeln('abstract class $schemaClassName $implementsClause{');

      // Direct properties for this class
      final classProps = domainProperties[classId] ?? [];
      classProps.sort((a, b) => a.name.compareTo(b.name));

      final processedPropNames = <String>{'context', 'type'};

      for (final prop in classProps) {
        final propName = _toDartFieldName(prop.name);
        if (processedPropNames.contains(propName)) continue;
        processedPropNames.add(propName);

        final propType = _resolvePropertyType(prop.rangeIds);

        sb.writeln('  /// ${_escapeComment(prop.comment)}');
        sb.writeln(
          "  @Schema(description: ${_jsonStringLiteral(prop.comment)})",
        );
        sb.writeln('  $propType get $propName;');
        sb.writeln();
      }

      sb.writeln('}');
      sb.writeln();
    }

    return sb.toString();
  }

  String _resolvePropertyType(List<String> rangeIds) {
    if (rangeIds.isEmpty) return 'Object?';

    if (rangeIds.length == 1) {
      return _mapSchemaTypeToDart(rangeIds.single);
    }

    return '\$SchemaUnion?';
  }

  String _mapSchemaTypeToDart(String typeId) {
    switch (typeId) {
      case 'schema:Text':
      case 'schema:URL':
      case 'schema:CssSelectorType':
      case 'schema:XPathType':
      case 'schema:PronounceableText':
        return 'String?';
      case 'schema:Number':
      case 'schema:Float':
      case 'schema:Integer':
        return 'num?';
      case 'schema:Boolean':
        return 'bool?';
      case 'schema:Date':
      case 'schema:DateTime':
      case 'schema:Time':
        return 'String?';
      default:
        if (classes.containsKey(typeId)) {
          final targetName = classes[typeId]!.name;
          return '\$${_toDartClassName(targetName)}?';
        }
        return 'Object?';
    }
  }

  String _toDartClassName(String name) {
    var cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.isEmpty) return 'Item';
    if (_isReservedKeyword(cleaned)) return '${cleaned}Type';
    return cleaned;
  }

  String _toDartFieldName(String name) {
    var cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.isEmpty) return 'value';
    cleaned = cleaned[0].toLowerCase() + cleaned.substring(1);
    if (_isReservedKeyword(cleaned)) return '${cleaned}Property';
    return cleaned;
  }

  bool _isReservedKeyword(String word) {
    const keywords = {
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'covariant',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'late',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'required',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield',
      'type',
    };
    return keywords.contains(word);
  }

  String _escapeComment(String comment) {
    return comment.replaceAll('\n', ' ').replaceAll('\r', '').trim();
  }

  String _jsonStringLiteral(String text) {
    final cleaned = _escapeComment(text);
    return json.encode(cleaned).replaceAll(r'$', r'\$');
  }
}
