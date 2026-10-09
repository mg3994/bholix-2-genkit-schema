import 'package:bholix/schema_org.dart';
import '../tools/lib/schema_org_parser.dart'; // ignore: avoid_relative_lib_imports

void main() {
  // ignore: avoid_print
  print('====================================================');
  // ignore: avoid_print
  print('    Running Schema.org Integration Tests            ');
  // ignore: avoid_print
  print('====================================================');

  testParser();
  testGeneratedModels();

  // ignore: avoid_print
  print('\nAll Schema.org tests passed successfully!');
}

void testParser() {
  // ignore: avoid_print
  print('Testing SchemaOrgParser...');
  const sampleJson = '''
  {
    "@graph": [
      {
        "@id": "schema:Organization",
        "@type": "rdfs:Class",
        "rdfs:comment": "An organization.",
        "rdfs:label": "Organization"
      },
      {
        "@id": "schema:Place",
        "@type": "rdfs:Class",
        "rdfs:comment": "Entities that have a somewhat fixed physical location.",
        "rdfs:label": "Place"
      },
      {
        "@id": "schema:LocalBusiness",
        "@type": "rdfs:Class",
        "rdfs:comment": "A particular physical business.",
        "rdfs:label": "LocalBusiness",
        "rdfs:subClassOf": [
          {"@id": "schema:Organization"},
          {"@id": "schema:Place"}
        ]
      },
      {
        "@id": "schema:description",
        "@type": "rdf:Property",
        "rdfs:comment": "A description of the item.",
        "rdfs:label": "description",
        "schema:domainIncludes": {"@id": "schema:Thing"},
        "schema:rangeIncludes": [
          {"@id": "schema:Text"},
          {"@id": "schema:TextObject"}
        ]
      }
    ]
  }
  ''';

  final parser = SchemaOrgParser.fromJsonString(sampleJson);
  final parsed = parser.parse();

  assert(parsed.classes.length == 3, 'Expected 3 classes');
  assert(parsed.properties.length == 1, 'Expected 1 property');

  final localBusiness = parsed.classes['schema:LocalBusiness']!;
  assert(localBusiness.name == 'LocalBusiness', 'Class name mismatch');
  assert(
    localBusiness.parentIds.contains('schema:Organization') &&
        localBusiness.parentIds.contains('schema:Place'),
    'Parent class mismatch',
  );

  final descriptionProp = parsed.properties['schema:description']!;
  assert(descriptionProp.name == 'description', 'Property name mismatch');
  assert(
    descriptionProp.rangeIds.contains('schema:Text') &&
        descriptionProp.rangeIds.contains('schema:TextObject'),
    'Property range mismatch',
  );

  // ignore: avoid_print
  print('✓ SchemaOrgParser tests passed.');
}

void testGeneratedModels() {
  // ignore: avoid_print
  print('Testing generated \$LocalBusiness model subtyping and properties...');

  final DummyLocalBusiness business = DummyLocalBusiness(
    context: 'https://schema.org',
    type: 'LocalBusiness',
    currenciesAccepted: 'USD',
    priceRange: '\$\$\$',
  );

  assert(
    (business as Object) is $SchemaThing,
    'Should implement \$SchemaThing',
  );
  assert(
    (business as Object) is $Organization,
    'Should implement \$Organization',
  );
  assert((business as Object) is $Place, 'Should implement \$Place');
  assert(
    (business as Object) is $LocalBusiness,
    'Should implement \$LocalBusiness',
  );

  assert(business.context == 'https://schema.org', 'Context mismatch');
  assert(business.type == 'LocalBusiness', 'Type mismatch');
  assert(business.currenciesAccepted == 'USD', 'Currencies accepted mismatch');
  assert(business.priceRange == '\$\$\$', 'Price range mismatch');

  // ignore: avoid_print
  print('✓ Generated models subtyping and property tests passed.');
}

class DummyLocalBusiness implements $LocalBusiness {
  @override
  final String? context;

  @override
  final String type;

  @override
  final String? currenciesAccepted;

  @override
  final String? priceRange;

  DummyLocalBusiness({
    this.context,
    required this.type,
    this.currenciesAccepted,
    this.priceRange,
  });

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
