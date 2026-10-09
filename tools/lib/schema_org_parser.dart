import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model representing a Schema.org Class definition parsed from JSON-LD
class SchemaClass {
  final String id; // e.g. "schema:LocalBusiness"
  final String name; // e.g. "LocalBusiness"
  final String comment;
  final List<String> parentIds; // e.g. ["schema:Organization", "schema:Place"]

  SchemaClass({
    required this.id,
    required this.name,
    required this.comment,
    required this.parentIds,
  });
}

/// Model representing a Schema.org Property definition parsed from JSON-LD
class SchemaProperty {
  final String id; // e.g. "schema:description"
  final String name; // e.g. "description"
  final String comment;
  final List<String> domainIds; // e.g. ["schema:Thing"]
  final List<String> rangeIds; // e.g. ["schema:Text", "schema:TextObject"]

  SchemaProperty({
    required this.id,
    required this.name,
    required this.comment,
    required this.domainIds,
    required this.rangeIds,
  });
}

/// Model representing an Enumeration Value or Instance parsed from JSON-LD
class SchemaEnumValue {
  final String id;
  final String name;
  final String comment;
  final String classId;

  SchemaEnumValue({
    required this.id,
    required this.name,
    required this.comment,
    required this.classId,
  });
}

/// Parser for Schema.org JSON-LD ontology definition.
class SchemaOrgParser {
  final List<Map<String, dynamic>> graph;

  SchemaOrgParser(this.graph);

  static Future<SchemaOrgParser> fetchFromUrl(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception(
        'Failed to fetch schema.org JSON-LD from $url (status: ${res.statusCode})',
      );
    }
    final map = json.decode(res.body) as Map<String, dynamic>;
    final graph = (map['@graph'] as List).cast<Map<String, dynamic>>();
    return SchemaOrgParser(graph);
  }

  static SchemaOrgParser fromJsonString(String jsonStr) {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    final graph = (map['@graph'] as List).cast<Map<String, dynamic>>();
    return SchemaOrgParser(graph);
  }

  /// Parses classes, properties, data types, and enum values from the JSON-LD graph.
  ({
    Map<String, SchemaClass> classes,
    Map<String, SchemaProperty> properties,
    Set<String> dataTypes,
    Map<String, SchemaEnumValue> enumValues,
  })
  parse() {
    final classes = <String, SchemaClass>{};
    final properties = <String, SchemaProperty>{};
    final dataTypes = <String>{};
    final enumValues = <String, SchemaEnumValue>{};

    for (final item in graph) {
      final id = item['@id'] as String? ?? '';
      if (id.isEmpty) continue;

      final type = item['@type'];
      final types = type is List
          ? type.cast<String>()
          : [if (type is String) type];

      final label = _extractLabel(item, id);
      final comment = _extractComment(item);

      if (types.contains('rdfs:Class')) {
        if (types.contains('schema:DataType') ||
            id.startsWith('schema:DataType')) {
          dataTypes.add(id);
        }
        final parents = _extractRefList(item['rdfs:subClassOf']);
        classes[id] = SchemaClass(
          id: id,
          name: label,
          comment: comment,
          parentIds: parents,
        );
      } else if (types.contains('rdf:Property')) {
        final domains = _extractRefList(item['schema:domainIncludes']);
        final ranges = _extractRefList(item['schema:rangeIncludes']);
        properties[id] = SchemaProperty(
          id: id,
          name: label,
          comment: comment,
          domainIds: domains,
          rangeIds: ranges,
        );
      } else {
        // Enumeration value or instance
        for (final t in types) {
          if (t.startsWith('schema:')) {
            enumValues[id] = SchemaEnumValue(
              id: id,
              name: label,
              comment: comment,
              classId: t,
            );
          }
        }
      }
    }

    return (
      classes: classes,
      properties: properties,
      dataTypes: dataTypes,
      enumValues: enumValues,
    );
  }

  String _extractLabel(Map<String, dynamic> item, String id) {
    final labelObj = item['rdfs:label'];
    if (labelObj is String) return labelObj;
    if (labelObj is Map && labelObj.containsKey('@value')) {
      return labelObj['@value'].toString();
    }
    // Fallback to ID part after colon
    if (id.contains(':')) return id.split(':').last;
    return id;
  }

  String _extractComment(Map<String, dynamic> item) {
    final commentObj = item['rdfs:comment'];
    if (commentObj is String) return commentObj;
    if (commentObj is Map && commentObj.containsKey('@value')) {
      return commentObj['@value'].toString();
    }
    return '';
  }

  List<String> _extractRefList(dynamic obj) {
    final list = <String>[];
    if (obj is Map && obj.containsKey('@id')) {
      list.add(obj['@id'] as String);
    } else if (obj is List) {
      for (final elem in obj) {
        if (elem is Map && elem.containsKey('@id')) {
          list.add(elem['@id'] as String);
        }
      }
    }
    return list;
  }
}
