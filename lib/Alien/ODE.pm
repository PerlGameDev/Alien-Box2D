package Alien::ODE;
use strict;
use warnings;
use Alien::ODE::ConfigData;
use File::ShareDir qw(dist_dir);
use File::Spec;
use File::Find;
use File::Spec::Functions qw(catdir catfile rel2abs);

=head1 NAME

Alien::ODE - Build and make available ODE library - L<http://ode.org/>

=head1 VERSION

Version 1.0

=cut

our $VERSION = '1.0';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

Alien::ODE during its installation does one of the following:

=over

=item * Builds I<ODE> (The Open Dynamics Engine) binaries from source codes
and installs dev files (headers: *.h, static library: *.a) into I<share>
directory of Alien::ODE distribution.

=item * Tries to locate an already installed ODE via 'ode-config' script.

=back

Later you can use Alien::ODE in your module that needs to link with I<libode>
like this:

    # Sample Build.pl
    use Module::Build;
    use Alien::ODE;

    my $build = Module::Build->new(
      module_name => 'Any::ODE::Module',
      # + other params
      build_requires => {
                    'Alien::ODE' => 0,
                    # + others modules
      },
      configure_requires => {
                    'Alien::ODE' => 0,
                    # + others modules
      },
      extra_compiler_flags => Alien::ODE->config('cflags'),
      extra_linker_flags   => Alien::ODE->config('libs'),
    )->create_build_script;

NOTE: Alien::ODE is required only for building not for using 'Any::ODE::Module'.

=head1 DESCRIPTION

In short C<Alien::ODE> can be used to detect and get configuration
settings from an already installed ODE. It offers also an option to
download ODE source codes and build binaries from scratch.

=head1 METHODS

=head2 config()

This function is the main public interface to this module. Basic
functionality works in a very similar maner to 'ode-config' script:

    Alien::ODE->config('prefix');   # gives the same string as 'ode-config --prefix'
    Alien::ODE->config('version');  # gives the same string as 'ode-config --version'
    Alien::ODE->config('libs');     # gives the same string as 'ode-config --libs'
    Alien::ODE->config('cflags');   # gives the same string as 'ode-config --cflags'

=head1 BUGS

Please post issues and bugs at L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Alien-ODE>

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
  return _ode_config_via_script($param) if(Alien::ODE::ConfigData->config('script'));
  return _ode_config_via_config_data($param) if(Alien::ODE::ConfigData->config('config'));
}

### internal functions
sub _ode_config_via_script
{
  my ($param) = @_;
  my $devnull = File::Spec->devnull();
  my $script = Alien::ODE::ConfigData->config('script');
  return unless ($script && ($param =~ /[a-z0-9_]*/i));
  my $val = `$script --$param 2>$devnull`;
  $val =~ s/[\r\n]*$//;
  return $val;
}

sub _ode_config_via_config_data
{
  my ($param) = @_;
  my $share_dir = dist_dir('Alien-ODE');
  my $subdir = Alien::ODE::ConfigData->config('share_subdir');
  return unless $subdir;
  my $real_prefix = catdir($share_dir, $subdir);
  return unless ($param =~ /[a-z0-9_]*/i);
  my $val = Alien::ODE::ConfigData->config('config')->{$param};
  return unless $val;
  # handle @PrEfIx@ replacement
  $val =~ s/\@PrEfIx\@/$real_prefix/g;
  return $val;
}

1;
