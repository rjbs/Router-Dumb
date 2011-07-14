package Router::Dumb::Match;
use Moose;
# ABSTRACT: a dumb match against a dumb route

use namespace::autoclean;

has route => (
  is  => 'ro',
  isa => 'Router::Dumb::Route',
  required => 1,
  handles  => [ qw(target) ],
);

has matches => (
  isa => 'HashRef',
  required => 1,
  traits   => [ 'Hash' ],
  handles  => {
    matches => 'elements',
  },
);

1;
