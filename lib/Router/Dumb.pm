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
  lazy => 1,
  init_arg => undef,
  builder  => '_build_routes',
  traits   => [ 'Hash' ],
  handles  => {
    routes      => 'values',
    route_named => 'get',
  },
);

# should be doing per-route validation:
#   do not allow :name to occur multiple times for one name
#   do not allow * to occur other than as the very last part

sub _build_routes {
  my ($self) = @_;
  my %map;

  my $root = $self->root_dir;
  my @files = `find $root -type f`;
  chomp @files;

  for my $file (@files) {
    my $path = $file =~ s{/INDEX$}{/}gr;
    $path =~ s{$root}{};
    $path =~ s{^/}{};

    confess "can't use colon in file names"    if $path =~ /:/;
    confess "can't use asterisk in file names" if $path =~ /\*/;

    my @parts = split m{/}, $path;

    my $route = Router::Dumb::Route->new({
      parts  => \@parts,
      target => $file,
    });

    $map{ $route->path } = $route;
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

      $map{ $route->path } = $route;
    }
  }

  return \%map;
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

  if (my $route = $self->route_named($str)) {
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
    sort { $b->part_count <=> $a->part_count } @candidates
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
