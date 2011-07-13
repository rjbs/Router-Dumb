use 5.14.0;
package Router::Dumb::Route;
use Moose;

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
  default  => sub { grep { /^:/ } $_[0]->parts },
);

# should be doing per-route validation:
#   do not allow :name to occur multiple times for one name
#   do not allow * to occur other than as the very last part

sub matches {
  my ($self, $str) = @_;

  return {} if $str eq join(q{/}, $self->parts);

  my %matches;

  my @in_parts = split m{/}, $str;
  my @my_parts = $self->parts;

  PART: for my $i (keys @my_parts) {
    my $my_part = $my_parts[ $i ];

    if ($my_part ne '*' and $my_part !~ /^:/) {
      next TRY unless $my_part eq $in_parts[$i];
      next PART;
    }

    if ($my_parts[$i] eq '*') {
      $matches{REST} = join q{/}, @in_parts[ $i .. $#in_parts ];
      return \%matches;
    }

    confess 'unreachable condition' unless $my_parts[$i] =~ /^:(.+)/;

    $matches{ $1 } = $in_parts[$i];
  }

  return \%matches;
}

1;
