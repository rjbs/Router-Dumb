use 5.14.0;
package Router::Dumb::Route;
use Moose;

use Router::Dumb::Match;

use namespace::autoclean;

has target => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has parts => (
  isa => 'ArrayRef[Str]',
  required => 1,
  traits   => [ 'Array' ],
  handles  => {
    parts      => 'elements',
    part_count => 'count',
    get_part   => 'get',
  },
);

sub path {
  my ($self) = @_;
  my $path = join q{/}, $self->parts;
  return $path // '';
}

sub normalized_path {
  my ($self) = @_;

  return '' unless my @parts = $self->parts;

  my $i = 1;
  return join q{/}, map { /^:/ ? (':' . $i++) : $_ } @parts;
}

has is_slurpy => (
  is   => 'ro',
  isa  => 'Bool',
  lazy => 1,
  init_arg => undef,
  default  => sub { $_[0]->part_count && $_[0]->get_part(-1) eq '*' },
);

has has_params => (
  is   => 'ro',
  isa  => 'Bool',
  lazy => 1,
  init_arg => undef,
  default  => sub { !! (grep { /^:/ } $_[0]->parts) },
);

has constraints => (
  isa => 'HashRef',
  default => sub {  {}  },
  traits  => [ 'Hash' ],
  handles => {
    constraint_names => 'keys',
    constraint_for   => 'get',
  },
);

sub BUILD {
  my ($self) = @_;

  confess "multiple asterisk parts in route"
    if (grep { $_ eq '*' } $self->parts) > 1;

  my %seen;
  $seen{$_}++ for grep { $_ =~ /^:/ } $self->parts;
  my @repeated = grep { $seen{$_} > 1 } keys %seen;
  confess "some path match names were repeated: @repeated" if @repeated;

  my @bad_constraints;
  for my $key ($self->constraint_names) {
    push @bad_constraints, $key unless $seen{ ":$key" };
  }

  if (@bad_constraints) {
    confess "constraints were given for unknown names: @bad_constraints";
  }
}

sub _match {
  my ($self, $matches) = @_;
  $matches //= {};

  return Router::Dumb::Match->new({
    route   => $self,
    matches => $matches,
  });
}

sub check {
  my ($self, $str) = @_;

  return $self->_match if $str eq join(q{/}, $self->parts);

  my %matches;

  my @in_parts = split m{/}, $str;
  my @my_parts = $self->parts;

  PART: for my $i (keys @my_parts) {
    my $my_part = $my_parts[ $i ];

    if ($my_part ne '*' and $my_part !~ /^:/) {
      return unless $my_part eq $in_parts[$i];
      next PART;
    }

    if ($my_parts[$i] eq '*') {
      $matches{REST} = join q{/}, @in_parts[ $i .. $#in_parts ];
      return $self->_match(\%matches);
    }

    confess 'unreachable condition' unless $my_parts[$i] =~ /^:(.+)/;

    my $name  = $1;
    my $value = $in_parts[ $i ];
    if (my $constraint = $self->constraint_for($name)) {
      return unless $constraint->check($value);
    }
    $matches{ $name } = $value;
  }

  return $self->_match(\%matches);
}

1;
