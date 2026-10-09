// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema.org Genkit Dart Core Library

/// Annotation class for Genkit / Schemantic / Genkit A2UI schema compatibility
class Schema {
  final String? description;
  const Schema({this.description});
}

/// Base interface for all Schema.org entities
@Schema()
abstract class $SchemaThing {
  @Schema(description: 'JSON-LD context declaration')
  String? get context;

  @Schema(description: 'Schema.org type name')
  String get type;
}

/// Representation of localized text with language tag support in Schema.org
@Schema()
abstract class $LocalizedString {
  @Schema(description: 'The text value')
  String get value;

  @Schema(description: 'The BCP 47 language code, e.g. en, fr, hi')
  String? get language;
}

/// Generic wrapper for multi-type or union values in Schema.org properties
@Schema()
abstract class $SchemaUnion {
  @Schema(description: 'String value if applicable')
  String? get stringValue;

  @Schema(description: 'Numeric value if applicable')
  num? get numberValue;

  @Schema(description: 'Boolean value if applicable')
  bool? get booleanValue;

  @Schema(description: 'List of localized strings')
  List<$LocalizedString>? get localizedValues;

  @Schema(description: 'Raw object or URI reference')
  Object? get objectValue;
}
