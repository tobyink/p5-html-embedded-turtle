use Test::More tests => 7;

BEGIN { use_ok('HTML::Embedded::Turtle') };
can_ok('HTML::Embedded::Turtle', 'VERSION');
can_ok('HTML::Embedded::Turtle', 'AUTHORITY');
ok(HTML::Embedded::Turtle->AUTHORITY('cpan:TOBYINK'), 'Correct AUTHORITY');
can_ok('HTML::Embedded::Turtle', 'new');
ok(my $obj = HTML::Embedded::Turtle->new('','http://example.com/'), 'Object can be instantiated.');
ok($obj->AUTHORITY('cpan:TOBYINK'), 'Correct AUTHORITY');
