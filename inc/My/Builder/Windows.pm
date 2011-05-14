package My::Builder::Windows;

use strict;
use warnings;
use base 'My::Builder';

use File::Spec::Functions qw(catdir catfile rel2abs);
use File::Path qw(make_path remove_tree);
use File::Copy;

use ExtUtils::Command;
use Config;

sub build_binaries {
  my( $self, $build_out, $build_src ) = @_;
  my $bp = $self->notes('build_params');
  my $target = ($bp->{precision} eq 'double') ? 'releasedoublelib' : 'releasesinglelib';

  print "BUILDING '" . $bp->{dirname} . "'...\n";
  my $srcdir = catfile($build_src, $bp->{dirname});
  my $prefixdir = rel2abs($build_out);
  $self->config_data('build_prefix', $prefixdir); # save it for future Alien::ODE::ConfigData

  print "Gonna run premake\n";
  chdir catdir($self->base_dir(), $srcdir, 'build');
  $self->do_system(qw(.\premake4 --all-collis-libs --cc=gcc --os=windows gmake)) or die "###ERROR### [$?] during premake ... ";

  print "Gonna run make: config=$target\n";
  chdir catdir($self->base_dir(), $srcdir, 'build', 'gmake');
  $self->do_system($self->get_make, "config=$target", 'CC=gcc') or die "###ERROR### [$?] during make ... ";

  print "Gonna install dev files\n";
  chdir catdir($self->base_dir(), $srcdir);
  my $inc = catdir("$prefixdir", 'include', 'ode');
  my $lib = catdir("$prefixdir", 'lib');
  make_path($inc);
  make_path($lib);
  copy($_, $inc) foreach (glob('include\ode\*.h'));
  if ($bp->{precision} eq 'double') {
    copy('lib\ReleaseDoubleLib\libode_double.a', "$lib\\libode.a");
  }
  else {
    copy('lib\ReleaseSingleLib\libode_single.a', "$lib\\libode.a");
  }
  
  print "Gonna read version info\n";
  open(DAT, 'configure') || die;
  my @raw=<DAT>;
  close(DAT);
  my ($version) = grep(/^ODE_RELEASE=[0-9\.]+/, @raw);
  if ($version =~ /ODE_RELEASE=([0-9\.]+)/) {
    print STDERR "Got version=$1\n";
    $self->notes('build_ode_version', $1);
  }

  chdir $self->base_dir();
  return 1;
}

sub get_make {
  my ($self) = @_;
  my $devnull = File::Spec->devnull();
  my @try = ( $Config{gmake}, 'mingw32-make', 'gmake', 'make');
  foreach my $name ( @try ) {
    next unless $name;
    return $name if `$name --help 2> $devnull`;
  }
  return 'make';
}

sub get_path {
  my ( $self, $path ) = @_;
  $path = '"' . $path . '"';
  return $path;
}

1;
