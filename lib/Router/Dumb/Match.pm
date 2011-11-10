package Router::Dumb::Match;
use Moose;
# ABSTRACT: a dumb match against a dumb route

use namespace::autoclean;

=head1 OVERVIEW

Match objects are dead simple.  They have a C<target> method that returns the
target of the match (from the Route taken), a C<matches> method that returns a
list of pairs of the placeholders matched, and a C<route> method that returns
the L<route object|Router::Dumb::Route> that led to the match.

=cut

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
