use 5.14.0;
package Router::Dumb::Helper::FileMapper;
use Moose;
# ABSTRACT: something to build routes out of a dumb tree of files

use File::Find::Rule;
use Router::Dumb::Route;

use Moose::Util::TypeConstraints qw(find_type_constraint);

use namespace::autoclean;

=head1 OVERVIEW

The FileMapper helper looks over a tree of files and adds routes to a
L<Router::Dumb> object based on those files.

For example, imagine the following file hierarchy:

  templates
  templates/pages
  templates/pages/help
  templates/pages/images
  templates/pages/images/INDEX
  templates/pages/INDEX
  templates/pages/legal
  templates/pages/legal/privacy
  templates/pages/legal/tos

With the following code...

  use Path::Class qw(dir);

  my $r = Router::Dumb->new;

  Router::Dumb::Helper::FileMapper->new({
    root => 'templates/pages',
    target_munger => sub {
      my ($self, $filename) = @_;
      dir('pages')->file( file($filename)->relative($self->root) )
                  ->stringify;
    },
  })->add_routes_to($r);

...the router will have a route so that:

  $r->route( '/legal/privacy' )->target eq 'pages/legal/privacy';

These routes never have placeholders, and if files in the tree have colons at
the beginning of their names, an exception will be thrown.  Similarly, slurpy
routes will never be added, and files named C<*> are forbidden.

Files named F<INDEX> are special:  they cause a route for the directory's name
to exist.

=cut

=attr root

This is the name of the root directory to scan when adding routes.

=cut

has root => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

=attr target_munger

This attribute (which has a default no-op value) must be a coderef.  It is
called like a method, with the first non-self argument being the file
responsible for the route.  It should return the target for the route to be
added.

=cut

has target_munger => (
  reader  => '_target_munger',
  isa     => 'CodeRef',
  default => sub {  sub { $_[1] }  },
);

=attr parts_munger

This attribute (which has a default no-op value) must be a coderef.  It is
called like a method, with the first non-self argument being an arrayref of the
path components of the file responsible for the route.  It should return the
parts for the route to be added.

=cut

has parts_munger => (
  reader  => '_parts_munger',
  isa     => 'CodeRef',
  default => sub {  sub { $_[1] }  },
);

=method add_routes_to

  $helper->add_routes_to( $router );

This message tells the helper to scan its directory root and add routes to the
given router.  The helper can be used over and over.

=cut

sub add_routes_to {
  my ($self, $router) = @_;

  my $dir = $self->root;
  my @files = File::Find::Rule->file->in($dir);

  for my $file (@files) {
    my $path = $file =~ s{/INDEX$}{/}gr;
    $path =~ s{$dir}{};
    $path =~ s{^/}{};

    my @parts = split m{/}, $path;

    confess "can't use placeholder-like name in route files"
      if grep {; /^:/ } @parts;

    confess "can't use asterisk in file names" if grep {; $_ eq '*' } @parts;

    my $route = Router::Dumb::Route->new({
      parts  => $self->_parts_munger->( $self, \@parts ),
      target => $self->_target_munger->( $self, $file ),
    });

    $router->add_route($route);
  }
}

1;
