use 5.14.0;
package Router::Dumb;
use Moose;
# ABSTRACT: yet another dumb path router for URLs

use Router::Dumb::Route;

use namespace::autoclean;

has _route_map => (
  is   => 'ro',
  isa  => 'HashRef',
  init_arg => undef,
  default  => sub {  {}  },
  traits   => [ 'Hash' ],
  handles  => {
    routes   => 'values',
    route_at => 'get',
    _add_route => 'set',
  },
);

sub add_route {
  my ($self, $route) = @_;

  confess "invalid route" unless $route->isa('Router::Dumb::Route');

  my $npath = $route->normalized_path;
  if (my $existing = $self->route_at( $npath )) {
    confess sprintf(
      "route conflict: %s would conflict with %s",
      $route->path,
      $existing->path,
    );
  }

  $self->_add_route($npath, $route);
}

sub route {
  my ($self, $str) = @_;

  # Shamelessly stolen from Path::Router 0.10 -- rjbs, 2011-07-13
  $str =~ s|/{2,}|/|g;                          # xx////xx  -> xx/xx
  $str =~ s{(?:/\.)+(?:/|\z)}{/}g;              # xx/././xx -> xx/xx
  $str =~ s|^(?:\./)+||s unless $str eq "./";   # ./xx      -> xx
  $str =~ s|^/(?:\.\./)+|/|;                    # /../../xx -> xx
  $str =~ s|^/\.\.$|/|;                         # /..       -> /
  $str =~ s|/\z|| unless $str eq "/";           # xx/       -> xx

  confess "path didn't start with /" unless $str =~ s{^/}{};

  if (my $route = $self->route_at($str)) {
    # should always match! -- rjbs, 2011-07-13
    confess "empty route didn't match empty path"
      unless my $match = $route->check($str);

    return $match;
  }

  my @parts = split m{/}, $str;

  for my $candidate ($self->ordered_routes(
    sub {
         ($_->part_count == @parts and $_->has_params)
      or ($_->part_count <= @parts and $_->is_slurpy)
    }
  )) {
    next unless my $match = $candidate->check($str);
    return $match;
  }

  return;
}

sub ordered_routes {
  my ($self, $filter) = @_;

  return sort { $b->part_count <=> $a->part_count
             || $a->is_slurpy  <=> $b->is_slurpy }
         grep { $filter ? $filter->() : 1 }
         $self->routes;
}

1;
