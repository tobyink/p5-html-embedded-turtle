use Test::More tests => 10;
use Test::RDF 0.23;
use HTML::Embedded::Turtle;
use RDF::Trine qw[statement iri literal blank variable];
use RDF::Trine::Namespace 'rdf';
my $foaf = RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');

my $het = HTML::Embedded::Turtle->new(<<'MARKUP', 'http://example.net/');
	<title property="http://purl.org/dc/terms/title">Test</title>
	<link rel=meta href="#endorsed">
	<script language=Turtle>
		@prefix foaf: <http://xmlns.com/foaf/0.1/> .
		[] a foaf:Person ; foaf:name "Joe Bloggs" .
	</script>
	<script type="text/turtle" id=endorsed>
		@prefix foaf: <http://xmlns.com/foaf/0.1/> .
		[] a foaf:Person ; foaf:name "Alice Smith" .
	</script>
	<script type="TEXT/TURTLE" id=unendorsed>
		@prefix foaf: <http://xmlns.com/foaf/0.1/> .
		[] a foaf:Person ; foaf:name "Bob Smith" .
	</script>
	<p>Hello</p>
MARKUP

pattern_target($het->union_graph);

pattern_ok(
	statement(variable('x'), $rdf->type, $foaf->Person),
	statement(variable('x'), $foaf->name, literal('Joe Bloggs')),
	);

pattern_ok(
	statement(variable('x'), $rdf->type, $foaf->Person),
	statement(variable('x'), $foaf->name, literal('Alice Smith')),
	);

pattern_ok(
	statement(variable('x'), $rdf->type, $foaf->Person),
	statement(variable('x'), $foaf->name, literal('Bob Smith')),
	);

is_deeply([ $het->endorsements ], ['http://example.net/#endorsed'], 'endorsed graph list is sensible');

pattern_target($het->endorsed_union_graph);

pattern_ok(
	statement(variable('x'), $rdf->type, $foaf->Person),
	statement(variable('x'), $foaf->name, literal('Alice Smith')),
	'second graph is endorsed'
	);

is($het->endorsed_union_graph->count_statements(undef, undef, literal('Joe Bloggs')),
	0, 'first graph is not endorsed');

is($het->endorsed_union_graph->count_statements(undef, undef, literal('Bob Smith')),
	0, 'third graph is not endorsed');

isa_ok($het->dom, 'XML::LibXML::Document');