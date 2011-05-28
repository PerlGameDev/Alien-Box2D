package Alien::Box2D;
use strict;
use warnings;
use Alien::Box2D::ConfigData;
use File::ShareDir qw(dist_dir);
use File::Spec;
use File::Find;
use File::Spec::Functions qw(catdir catfile rel2abs);

=head1 NAME

Alien::Box2D - Build and make available Box2D library - L<http://box2d.org/>

=head1 VERSION

Version 0.102

=cut

our $VERSION = '0.102';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

Alien::Box2D during its installation does one of the following:

=over

=item * Builds I<ODE> binaries from source codes and installs dev 
files (headers: *.h, static library: *.a) into I<share>
directory of Alien::Box2D distribution.

=back

Later you can use Alien::Box2D in your module that needs to link with I<libode>
like this:

    # Sample Build.pl
    use Module::Build;
    use Alien::Box2D;

    my $build = Module::Build->new(
      module_name => 'Any::Box2D::Module',
      # + other params
      build_requires => {
                    'Alien::Box2D' => 0,
                    # + others modules
      },
      configure_requires => {
                    'Alien::Box2D' => 0,
                    # + others modules
      },
      extra_compiler_flags => Alien::Box2D->config('cflags'),
      extra_linker_flags   => Alien::Box2D->config('libs'),
    )->create_build_script;

NOTE: Alien::Box2D is required only for building not for using 'Any::Box2D::Module'.

=head1 DESCRIPTION

In short C<Alien::Box2D> can be used to detect and get configuration
settings from an already installed Box2D. It offers also an option to
download Box2D source codes and build binaries from scratch.

=head1 METHODS

=head2 config()

This function is the main public interface to this module:

    Alien::Box2D->config('prefix');
    Alien::Box2D->config('version');
    Alien::Box2D->config('libs');
    Alien::Box2D->config('cflags');

=head1 BUGS

Please post issues and bugs at L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Alien-Box2D>

=head1 AUTHOR

KMX, E<lt>kmx at cpan.orgE<gt>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

### get config params
sub config
{
  my ($package, $param) = @_;
  return _box2d_config_via_config_data($param) if(Alien::Box2D::ConfigData->config('config'));
}

### internal functions
sub _box2d_config_via_config_data
{
  my ($param) = @_;
  my $share_dir = dist_dir('Alien-Box2D');
  my $subdir = Alien::Box2D::ConfigData->config('share_subdir');
  return unless $subdir;
  my $real_prefix = catdir($share_dir, $subdir);
  return unless ($param =~ /[a-z0-9_]*/i);
  my $val = Alien::Box2D::ConfigData->config('config')->{$param};
  return unless $val;
  # handle @PrEfIx@ replacement
  $val =~ s/\@PrEfIx\@/$real_prefix/g;
  return $val;
}

1;
