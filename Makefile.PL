use strict;
use warnings;

use inc::Module::Install;

my $dist = 'HTML-Embedded-Turtle';
my $fn   = "lib/$dist.pm"; $fn =~ s#-#/#g;

name                $dist;
perl_version_from   $fn;
version_from        $fn;
abstract_from       $fn;
readme_from         $fn;
author              'Toby Inkster <tobyink@cpan.org>';
license             'perl';

requires            'common::sense'       => 0;
requires            'Data::UUID'          => 0;
requires            'RDF::RDFa::Parser'   => '1.09_04';
requires            'RDF::Trine'          => '0.118';
requires            'RDF::TriN3'          => 0;
requires            'RDF::TrineShortcuts' => '0.07';
test_requires       'Test::More'          => '0.61';

resources(
	'homepage'   => "https://metacpan.org/release/$dist",
	'repository' => "http://goddamn.co.uk/svn-web/perlmods/browse/$dist/",
	'bugtracker' => "http://rt.cpan.org/Dist/Display.html?Queue=$dist",
	);
	
keywords(qw(HTML XHTML script RDF SemWeb Turtle Notation3 N-Triples));

write_doap_changes;
write_doap_changes_xml;
auto_license;
auto_manifest;

auto_install;
WriteAll(
	'meta' => 1,
	'sign' => 1,
	);
