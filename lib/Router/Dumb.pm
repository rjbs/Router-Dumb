use 5.14.0;
package Router::Dumb;
use Moose;

use Router::Dumb::Route;

use namespace::autoclean;

has root_dir => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has extras_file => (
  is  => 'ro',
  isa => 'Str',
  predicate => 'has_extras_file',
);

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

sub BUILD {
  my ($self) = @_;
  $self->_build_routes;
}

sub _build_routes {
  my ($self) = @_;

  my $root = $self->root_dir;
  my @files = `find $root -type f`;
  chomp @files;

  for my $file (@files) {
    my $path = $file =~ s{/INDEX$}{/}gr;
    $path =~ s{$root}{};
    $path =~ s{^/}{};

    my @parts = split m{/}, $path;

    confess "can't use placeholder-like name in route files"
      if grep {; /^:/ } @parts;

    confess "can't use asterisk in file names" if grep {; $_ eq '*' } @parts;

    my $route = Router::Dumb::Route->new({
      parts  => \@parts,
      target => $file,
    });

    $self->add_route($route);
  }

  if ($self->has_extras_file) {
    my $file = $self->extras_file;
    my @lines = `cat $file`;
    chomp @lines;

    for my $line (grep { /\S/ } @lines) {
      my ($path, $target) = split /\s*=>\s*/, $line;
      s{^/}{} for $path, $target;
      my @parts = split m{/}, $path;

      my $route = Router::Dumb::Route->new({
        parts  => \@parts,
        target => $file,
      });

      $self->add_route($route);
    }
  }
}

sub route {
  my ($self, $str) = @_;

  # Shamelessly stolen from Path::Router 0.10 -- rjbs, 2011-07-13
  $str =~ s|/{2,}|/|g;                          # xx////xx  -> xx/xx
  $str =~ s{(?:/\.)+(?:/|\z)}{/}g;              # xx/././xx -> xx/xx
  $str =~ s|^(?:\./)+||s unless $str eq "./";   # ./xx      -> xx
  $str =~ s|^/(?:\.\./)+|/|;                    # /../../xx -> xx
  $str =~ s|^/\.\.$|/|;                         # /..       -> /

  # Actually, I'm okay with turning / into '' -- rjbs, 2011-07-13
  # $str =~ s|/\z|| unless $str eq "/";           # xx/       -> xx
  $str =~ s|/\z||;                              # xx/       -> xx

  confess "path didn't start with /" unless $str =~ s{^/}{};

  if (my $route = $self->route_at($str)) {
    # should always match! -- rjbs, 2011-07-13
    confess "empty route didn't match empty path"
      unless my $matches = $route->matches($str);

    return {
      target  => $route->target,
      matches => $matches,
    }
  }

  my @parts = split m{/}, $str;
  my @candidates = grep {
       ($_->part_count == @parts and $_->has_params)
    or ($_->part_count <= @parts and $_->is_slurpy)
  } $self->routes;

  for my $candidate (
    sort { $b->part_count <=> $a->part_count
        || $a->is_slurpy  <=> $b->is_slurpy
    } @candidates
  ) {
    next unless my $matches = $candidate->matches($str);
    return {
      target  => $candidate->target,
      matches => $matches,
    };
  }

  return;
}

1;
