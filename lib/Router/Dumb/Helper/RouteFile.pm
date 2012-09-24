use 5.14.0;
package Router::Dumb::Helper::RouteFile;
use Moose;
# ABSTRACT: something to read routes out of a dumb text file

=head1 OVERVIEW

  my $r = Router::Dumb->new;
  
  Router::Dumb::Helper::RouteFile->new({ filename => 'routes.txt' })
                                 ->add_routes_to( $r );

...and F<routes.txt> looks like...

  # These are some great routes!

  /citizen/:num/dob  =>  /citizen/dob
    num isa Int

  /blog/*            =>  /blog

Then routes are added, doing just what you'd expect.  This helper is pretty
dumb, but the whole Router::Dumb system is, too.

=cut

use Router::Dumb::Route;

use Moose::Util::TypeConstraints qw(find_type_constraint);

use namespace::autoclean;

has filename => (is => 'ro', isa => 'Str', required => 1);

sub add_routes_to {
  my ($self, $router, $arg) = @_;
  $arg ||= {};

  my $file = $self->filename;

  my @lines;
  {
    open my $fh, '<', $file or die "can't open $file for reading: $!";

    # ignore comments, blanks
    @lines = grep { /\S/ }
             map  { chomp; s/#.*\z//r } <$fh>
  }

  my $add_method = $arg->{ignore_conflicts}
                 ? 'add_route_unless_exists'
                 : 'add_route';

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
      $router->$add_method( Router::Dumb::Route->new($curr) );
      undef $curr;
    }
  }
}

1;
