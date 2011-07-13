use strict;
use warnings;
use Test::More;

use Router::Dumb;

my $r = Router::Dumb->new({
  root_dir    => 'templates/pages',
  extras_file => 'eg/extras',
});

$r->routes;

pass;

note explain $r;

for my $what (qw(
  /legal/privacy
  /citizen/1234/dob
  /blog/1231/2;34/your-mom
)) {
  note "$what: " . join(q{}, explain $r->route($what));
}

done_testing;
