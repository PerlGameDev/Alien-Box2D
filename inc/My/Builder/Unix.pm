package My::Builder::Unix;

use strict;
use warnings;
use base 'My::Builder';

use File::Spec::Functions qw(catdir catfile rel2abs);
use File::ShareDir;
use Config;
use My::Utility qw(find_file get_dlext);

sub ACTION_install
{
  if($^O eq 'darwin') {
    my $self         = shift;
    my $sharedir     = eval {File::ShareDir::dist_dir('Alien-SDL')} || '';
    my $share_subdir = $self->{properties}->{dist_version} . '_' . substr(sha1_hex($self->notes('build_params')->{title}), 0, 8);
    my $dlext        = get_dlext();
    my ($libname)    = find_file("sharedir/$share_subdir/lib", qr/\.$dlext[\d\.]+$/);
    $self->do_system('install_name_tool', "-id $sharedir/lib/$libname", "sharedir/$share_subdir/lib/$libname");
    warn "install_name_tool -id $sharedir/lib/$libname sharedir/$share_subdir/lib/$libname";
  }
  exit;

  $self->SUPER::ACTION_install;
}

sub build_binaries {
  my( $self, $build_out, $build_src ) = @_;
  my $bp = $self->notes('build_params');

  print "BUILDING '" . $bp->{dirname} . "'...\n";
  my $srcdir = catfile($build_src, $bp->{dirname});
  my $prefixdir = rel2abs($build_out);
  $self->config_data('build_prefix', $prefixdir); # save it for future Alien::Box2D::ConfigData

  print "Gonna read version info from $srcdir/Common/b2Settings.cpp\n";
  open(DAT, "$srcdir/Common/b2Settings.cpp") || die;
  my @raw=<DAT>;
  close(DAT);
  my ($version) = grep(/version\s?=\s?\{[\d\s,]+\}/, @raw);
  if ($version =~ /version\s?=\s?\{(\d+)[^\d]+(\d+)[^\d]+(\d+)\}/) {
    print STDERR "Got version=$1.$2.$3\n";
    $self->notes('build_box2d_version', "$1.$2.$3");
  }

  chdir $srcdir;
  
  # do 'cmake ...'
  my $cmd = $self->get_cmake_cmd($prefixdir);
  print "CMaking ...\n";
  print "(cmd: $cmd)\n";
  $self->do_system($cmd);# or die "###ERROR### [$?] during cmake ... ";

  # do 'make install'
  my @cmd = ($self->get_make, 'install');
  print "Running make install ...\n";
  print "(cmd: ".join(' ',@cmd).")\n";
  $self->do_system(@cmd) or die "###ERROR### [$?] during make ... ";

  chdir $self->base_dir();
  return 1;
}

sub get_cmake_cmd {
  my ($self, $prefixdir) = @_;

  my $cmd = sprintf('cmake -DCMAKE_INSTALL_PREFIX="%s" -DBOX2D_INSTALL=ON -DBOX2D_BUILD_SHARED=ON ..',
    $self->config_data('build_prefix'));

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
