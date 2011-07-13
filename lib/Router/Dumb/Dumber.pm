use 5.14.0;
package Router::Dumb::Dumber;
use Moose;
extends 'Router::Dumb';

use Router::Dumb::Route;

use Moose::Util::TypeConstraints qw(find_type_constraint);

use namespace::autoclean;

has simple_root => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has simple_munger => (
  reader  => '_simple_munger',
  isa     => 'CodeRef',
  default => sub {  sub { $_[1] }  },
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

  my $dir = $self->simple_root;
  my @files = `find $dir -type f`;
  chomp @files;

  for my $file (@files) {
    my $path = $file =~ s{/INDEX$}{/}gr;
    $path =~ s{$dir}{};
    $path =~ s{^/}{};

    my @parts = split m{/}, $path;

    confess "can't use placeholder-like name in route files"
      if grep {; /^:/ } @parts;

    confess "can't use asterisk in file names" if grep {; $_ eq '*' } @parts;

    my $route = Router::Dumb::Route->new({
      parts  => \@parts,
      target => $self->_simple_munger->( $self, $file ),
    });

    $self->add_route($route);
  }

  if ($self->has_extras_file) {
    $self->_add_routes_from_file( $self->extras_file );
  }
}

sub _add_routes_from_file {
  my ($self, $file) = @_;

  my @lines = `cat $file`;
  chomp @lines;

  # ignore comments, blanks
  @lines = grep { /\S/ }
           map  { s/#.*\z//r } @lines;

  my $curr;

  for my $i (0 .. $#lines) {
    my $line = $lines[$i];

    if ($line =~ /^\s/) {
      confess "indented line found out of context of a route" unless $curr;
      confess "couldn't understand line <$line>"
        unless my ($name, $type) = $line =~ /\A\s+(\S+)\s+isa\s+(\S+)\s*\z/;

      $curr->{constraints}->{$name} = find_type_constraint($type);
    } else {
      my ($path, $target) = split /\s*=>\s*/, $line;
      s{^/}{} for $path, $target;
      my @parts = split m{/}, $path;

      $curr = {
        parts  => \@parts,
        target => $target,
      };
    }

    if ($curr and ($i == $#lines or $lines[ $i + 1 ] =~ /^\S/)) {
      $self->add_route( Router::Dumb::Route->new($curr) );
      undef $curr;
    }
  }
}

1;
