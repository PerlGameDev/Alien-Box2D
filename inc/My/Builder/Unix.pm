package My::Builder::Unix;

use strict;
use warnings;
use base 'My::Builder';

use File::Spec::Functions qw(catdir catfile rel2abs);
use Config;

sub build_binaries {
  my( $self, $build_out, $build_src ) = @_;
  my $bp = $self->notes('build_params');

  print "BUILDING '" . $bp->{dirname} . "'...\n";
  my $srcdir = catfile($build_src, $bp->{dirname});
  my $prefixdir = rel2abs($build_out);
  $self->config_data('build_prefix', $prefixdir); # save it for future Alien::ODE::ConfigData

  chdir $srcdir;

  # do './configure ...'
  my $run_configure = 'y';
  $run_configure = $self->prompt("Run ./configure again?", "n") if (-f "config.status");
  if (lc($run_configure) eq 'y') {
    my $cmd = $self->get_configure_cmd($prefixdir);
    print "Configuring ...\n";
    print "(cmd: $cmd)\n";
    $self->do_system($cmd) or die "###ERROR### [$?] during ./configure ... ";
  }

  # do 'make install'
  my @cmd = ($self->get_make, 'install');
  print "Running make install ...\n";
  print "(cmd: ".join(' ',@cmd).")\n";
  $self->do_system(@cmd) or die "###ERROR### [$?] during make ... ";

  chdir $self->base_dir();
  return 1;
}

sub get_configure_cmd {
  my ($self, $prefixdir) = @_;
##  my $extra_cflags = "-I$prefixdir/include";
##  my $extra_ldflags = "-L$prefixdir/lib";
  my $extra = ($self->notes('build_params')->{precision} eq 'double') ? '--enable-double-precision' : '';

  # prepare configure command
  my $cmd = "./configure --prefix=$prefixdir --enable-static=yes --enable-shared=no $extra" .
         " --disable-demos --disable-dependency-tracking";
##	 .
##         " CFLAGS=\"$extra_cflags\" LDFLAGS=\"$extra_ldflags\"";

  return $cmd;
}

sub get_make {
  my ($self) = @_;
  my $devnull = File::Spec->devnull();
  my @try = ($Config{gmake}, 'gmake', 'make', $Config{make});
  my %tested;
  print "Gonna detect GNU make:\n";
  foreach my $name ( @try ) {
    next unless $name;
    next if $tested{$name};
    $tested{$name} = 1;
    print "- testing: '$name'\n";
    my $ver = `$name --version 2> $devnull`;
    if ($ver =~ /GNU Make/i) {
      print "- found: '$name'\n";
      return $name
    }
  }
  print "- fallback to: 'make'\n";
  return 'make';
}

1;
