use strict;
use warnings;
use Test::More;
use Test::Deep qw(cmp_deeply listmethods);

use Moose::Util::TypeConstraints qw(find_type_constraint);
use Router::Dumb::Dumber;

my $r = Router::Dumb::Dumber->new({
  root_dir    => 'templates/pages',
  extras_file => 'eg/extras',
});

# Canonicalize hash.  This is stupid.  I need it because Test::Deep doesn't yet
# have a way to do pairwise comparison. -- rjbs, 2011-07-13
sub _CH {
  my %hash = @_;
  [ map { $_ => $hash{$_} } sort keys %hash ]
}

$r->add_route(
  Router::Dumb::Route->new({
    parts       => [ qw(group :group uid :uid) ],
    target      => 'pants',
    constraints => {
      group => find_type_constraint('Int'),
    },
  }),
);

my @tests = (
  '/legal' => undef,

  '/legal/privacy' => {
    target  => [ 'templates/pages/legal/privacy' ],
    matches => _CH(),
  },

  '/citizen/1234/dob' => {
    target  => [ 'citizen/dob' ],
    matches => _CH(num => 1234),
  },

  '/blog/1231/2;34/your-mom' => {
    target  => [ 'blog' ],
    matches => _CH(REST => '1231/2;34/your-mom'),
  },

  '/group/123/uid/321' => {
    target  => [ 'pants' ],
    matches => _CH(group => 123, uid => 321),
  },

  '/group/abc/uid/321' => undef,
);

for (my $i = 0; $i < @tests; $i += 2) {
  my $path = $tests[ $i ];
  my $test = $tests[ $i + 1 ];

  my $want = $test ? listmethods(%$test) : undef;

  cmp_deeply(
    scalar $r->route($path),
    $want,
    "correct result for $path",
  );
}

done_testing;
