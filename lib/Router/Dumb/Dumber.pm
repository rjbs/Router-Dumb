use 5.14.0;
package Router::Dumb::Dumber;
use Moose;
extends 'Router::Dumb';

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

1;
