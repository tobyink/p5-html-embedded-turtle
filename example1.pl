use lib "lib";
use Data::Dumper;
use HTML::Embedded::Turtle;

my $het = HTML::Embedded::Turtle->new(<<MARKUP, 'http://example.net/');
<title>Test</title>
<link rel=meta href="#endorsed">

<script language=Turtle>
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .
[] a foaf:Person ; foaf:name "Joe Bloggs" .
</script>

<script type="text/turtle" id=endorsed>
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .
[] a foaf:Person ; foaf:name "Alice Smith" .
</script>

<script type="TEXT/TURTLE" id=unendorsed>
\@prefix foaf: <http://xmlns.com/foaf/0.1/> .
[] a foaf:Person ; foaf:name "Bob Smith" .
</script>

<p>Hello</p>

MARKUP

my $iter = $het->endorsed_union_graph->get_statements(undef, undef, undef, undef);
while (my $st = $iter->next)
{
	print $st->as_string;
}