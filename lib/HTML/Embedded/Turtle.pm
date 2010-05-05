package HTML::Embedded::Turtle;

use 5.008;
use common::sense;
use Data::UUID;
use RDF::RDFa::Parser '1.09_04';
use RDF::TrineShortcuts qw(rdf_query rdf_parse);

our $VERSION = '0.01';

sub new
{
	my ($class, $markup, $base_uri, $options) = @_;
	my $self = bless {
		markup   => $markup ,
		options  => $options ,
		}, $class;
	
	$options->{'rdfa_options'} ||= $options->{'markup'} =~ /x(ht)?ml/i ?
		RDF::RDFa::Parser::Config->new('xhtml', '1.0', dom_parser=>'xml') :
		RDF::RDFa::Parser::Config->new('html',  '1.0', dom_parser=>'html');
	
	my $rdfa_parser      =
	$self->{rdfa_parser} = RDF::RDFa::Parser->new($markup, $base_uri, $options->{'rdfa_options'})->consume;
	$self->{dom}         = $rdfa_parser->dom;
	$self->{base_uri}    = $rdfa_parser->uri;

	$self->_find_endorsed;
	$self->_extract_graphs;
}

sub _find_endorsed
{
	my ($self) = @_;
	my $rdfa_parser = $self->{rdfa_parser};

	my $results = rdf_query(
		sprintf('SELECT ?endorsed WHERE { <%s> <http://www.w3.org/1999/xhtml/vocab#meta> ?endorsed . }', $self->{base_uri}),
		$rdfa_parser->graph);
	while (my $row = $results->next)
	{
		# Endorsements must be URIs.
		next unless UNIVERSAL::isa($row->{endorsed}, 'RDF::Trine::Node::Resource');
		
		# Endorsements must be fragments within this document.
		next unless substr($row->{endorsed}->uri, 0 , 1+length $self->{base_uri})
			eq $self->{base_uri}.'#';
			
		push @{ $self->{endorsements} }, $row->{endorsed}->uri;
	}
	
	return $self;
}

sub _extract_graphs
{
	my ($self) = @_;
	my $uuid = Data::UUID->new;
	
	my @scripts = $self->{'dom'}->getElementsByTagName('script');
	foreach my $script (@scripts)
	{
		my $parser = $self->_choose_parser_by_type($script->getAttribute('type'));
		$parser ||=  $self->_choose_parser_by_language($script->getAttribute('language'));
		
		next unless $parser;
		
		my $data  = $script->textContent;
		my $model = RDF::Trine::Model->temporary_model;
		$parser->parse_into_model($self->{base_uri}, $data, $model);
		
		my $graphname;
		if (length $script->getAttribute('id'))
		{
			$graphname = $self->{base_uri} . '#' . $script->getAttribute('id');
		}
		else
		{
			$graphname = '_:bn'.(substr $uuid->create_hex, 2);
		}
		
		$self->{'graphs'}->{$graphname} = $model;
	}
	
	return $self;
}

sub _choose_parser_by_type
{
	my ($self, $type) = @_;
	
	if ($type =~ m'^\s*(application|text)/(x-)?turtle\b'i)
	{
		return RDF::Trine::Parser::Turtle->new;
	}
	elsif ($type =~ m'^\s*text/plain\b'i)
	{
		return RDF::Trine::Parser::NTriples->new;
	}
	elsif ($type =~ m'^\s*(application|text)/(x-)?(rdf\+)?n3\b'i)
	{
		warn "Notation 3 is not supported; attempting to parse as Turtle.";
		return RDF::Trine::Parser::Turtle->new;
	}
	elsif ($type =~ m'^\s*(application/rdf\+xml)|(text/rdf)\b'i)
	{
		return RDF::Trine::Parser::RDFXML->new;
	}
	elsif ($type =~ m'^\s*application/(x-)?(rdf\+)?json\b'i)
	{
		return RDF::Trine::Parser::RDFJSON->new;
	}
}

sub _choose_parser_by_language
{
	my ($self, $language) = @_;
	my $parser;
	eval { $parser = RDF::Trine::Parser->new($language); };
	return $parser;
}

sub graph
{
	my ($self, $graph) = @_;
	
	if (!defined $graph)
	{
		my $model = RDF::Trine::Model->temporary_model;
		while (my ($graph, $graph_model) = each %{ $self->{graphs} })
		{
			rdf_parse($graph_model, context=>$graph, model=>$model);
		}
		return $model;
	}
	elsif ($graph eq '::ENDORSED')
	{
		my $model = RDF::Trine::Model->temporary_model;
		foreach my $graph (@{ $self->{endorsements} })
		{
			if (defined $self->{graphs}->{$graph})
			{
				rdf_parse($self->{graphs}->{$graph}, context=>$graph, model=>$model);
			}
		}
		return $model;
	}
	elsif (defined $self->{graphs}->{$graph})
	{
		return $self->{graphs}->{$graph};
	}
}

sub union_graph
{
	my ($self) = @_;
	return $self->graph;
}

sub endorsed_union_graph
{
	my ($self) = @_;
	return $self->graph('::ENDORSED');
}

sub graphs
{
	my ($self, $graph) = @_;
	
	if (!defined $graph)
	{
		my $rv = {};
		foreach my $graph (keys %{ $self->{graphs} })
		{
			$rv->{$graph} = $self->{graphs}->{$graph};
		}
		return $rv;
	}
	elsif ($graph == '::ENDORSED')
	{
		my $rv = {};
		foreach my $graph (@{ $self->{endorsements} })
		{
			if (defined $self->{graphs}->{$graph})
			{
				$rv->{$graph} = $self->{graphs}->{$graph};
			}
		}
		return $rv;
	}
	elsif (defined $self->{graphs}->{$graph})
	{
		return  { $graph => $self->{graphs}->{$graph} };
	}
}

sub all_graphs
{
	my ($self) = @_;
	return $self->graphs;	
}

sub endorsed_graphs
{
	my ($self) = @_;
	return $self->graphs('::ENDORSED');
}

sub endorsements
{
	return @{ $_[0]->{endorsements} };
}

sub dom
{
	return $_[0]->{'dom'}
}

sub uri
{
	my $self = shift;
	return $self->{'rdfa_parser'}->uri(@_);
}

1;

__END__

=head1 NAME

HTML::Embedded::Turtle - embedding RDF in HTML the crazy way

=head1 VERSION

0.01

=head1 SYNOPSIS

 use HTML::Embedded::Turtle;
 
 my $het = HTML::Embedded::Turtle->new($html, $base_uri);
 foreach my $graph ($het->endorsements)
 {
   my $model = $het->graph($graph);
   
   # $model is an RDF::Trine::Model. Do something with it.
 }

=head1 DESCRIPTION

RDF can be embedded in (X)HTML using simple E<lt>scriptE<gt> tags. This is
described at L<http://esw.w3.org/N3inHTML>. This gives you a file format
that can contain multiple (optionally named) graphs. The document as a whole
can "endorse" a graph by including:

 <link rel="meta" href="#foo" />

Where "#foo" is a fragment identifier pointing to a graph.

 <script type="text/turtle" id="foo"> ... </script>

The rel="meta" stuff is parsed using an RDFa parser, so equivalent RDFa
works too.

This module parses HTML files containing graphs like these, and allows
you to access them each individually; as a union of all graphs on the page;
or as a union of just the endorsed graphs.

Despite the module name, this module supports a variety of
E<lt>script typeE<gt>s: text/turtle, application/turtle, application/x-turtle
text/plain (N-Triples), application/x-rdf+json (RDF/JSON), application/json (RDF/JSON),
application/rdf+xml (RDF/XML). Although it doesn't support full N3,
it recognises the following as well, but treats them as Turtle:
text/n3, text/rdf+n3.

=head2 Constructor

=over 4

=item C<< $het = HTML::Embedded::Turtle->new($markup, $base_uri, \%opts) >>

Create a new object. $markup is the HTML or XHTML markup to parse;
$base_uri is the base URI to use for relative references.

Options include:

=over 4

=item * B<markup>

Choose which parser to use: 'html' or 'xml'. The former chooses
HTML::HTML5::Parser, which can handle tag soup; the latter chooses
XML::LibXML, which cannot. Defaults to 'html'.

=item * B<rdfa_options>

A set of options to be parsed to RDF::RDFa::Parser when looking for
endorsements. See L<RDF::RDFa::Parser::Config>. The default is
probably sensible.

=back

=back

=head2 Public Methods

=over 4

=item C<< $het->union_graph >>

A union graph of all graphs found in the document, as an RDF::Trine::Model.
Note that the returned model contains quads.

=item C<< $het->endorsed_union_graph >>

A union graph of only the endorsed graphs, as an RDF::Trine::Model.
Note that the returned model contains quads.

=item C<< $het->graph($name) >>

A single graph from the page.

=item C<< $het->all_graphs >>

A hashref where the keys are graph names and the values are
RDF::Trine::Models. Some graph names will be URIs, and others
may be blank nodes (e.g. "_:foobar").

=item C<< $het->endorsed_graphs >>

Like C<all_graphs>, but only returns endorsed graphs. Note that
all endorsed graphs will have graph names that are URIs.

=item C<< $het->endorsements >>

Returns a list of URIs which are the names of endorsed graphs. Note that
the presence of a URI C<$x> in this list does not imply that
C<< $het->graph($x) >> will be defined.

=back

=head1 BUGS

Please report any bugs to L<http://rt.cpan.org/>.

Please forgive me in advance for inflicting this module upon you.

=head1 SEE ALSO

L<RDF::RDFa::Parser>, L<RDF::Trine>.

L<http://www.perlrdf.org/>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Toby Inkster

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
