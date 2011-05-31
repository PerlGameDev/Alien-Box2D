package My::Builder;

use strict;
use warnings;
use base 'Module::Build';

use lib "inc";
use File::Spec::Functions qw(catdir catfile splitpath catpath rel2abs abs2rel);
use File::Path;
use File::Copy qw(cp);
use File::Fetch;
use File::Find;
use File::ShareDir;
use Archive::Extract;
use Digest::SHA qw(sha1_hex);
use Text::Patch;
use Config;

sub ACTION_build {
  my $self = shift;
  # as we want to wipe 'sharedir' during 'Build clean' we has
  # to recreate 'sharedir' at this point if it does not exist
  mkdir 'sharedir' unless(-d 'sharedir');
  $self->add_to_cleanup('sharedir');
  $self->SUPER::ACTION_build;
}

sub ACTION_install {
  my $self = shift;
  my $sharedir = eval {File::ShareDir::dist_dir('Alien-Box2D')};  
  $self->clean_dir($sharedir) if $sharedir; # remove previous versions
  return $self->SUPER::ACTION_install(@_);
}

sub ACTION_code {
  my $self = shift;

  my $bp = $self->notes('build_params');
  die "###ERROR### Cannot continue build_params not defined" unless defined($bp);

  # we are deriving the subdir name from VERSION as we want to prevent
  # troubles when user reinstalls the newer version of Alien::Tidyp
  my $share_subdir = $self->{properties}->{dist_version};
  my $build_out = catfile('sharedir', $share_subdir);

  # check marker
  if (! $self->check_build_done_marker) {

    # important directories
    my $download     = 'download';
    my $build_src    = 'build_src';
    $self->add_to_cleanup($build_src, $build_out);

    # save some data into future Alien::Box2D::ConfigData
    $self->config_data('build_prefix', $build_out);
    $self->config_data('build_params', $bp);
    $self->config_data('config', {}); # just to be sure

    $self->fetch_sources($download);
    $self->extract_sources($download, $build_src);    
    $self->clean_dir($build_out);
    $self->build_binaries($build_out, $build_src);
    $self->set_config_data($build_out);

    # mark sucessfully finished build
    $self->touch_build_done_marker;
  }
  
  #### as we are building just a static library the following is not (perhaps) necessary
  #if($^O eq 'darwin') {
  #  my $sharedir     = eval {File::ShareDir::dist_dir('Alien-Box2D')} || '';
  #  my $dlext        = 'so|dylib|bundle';
  #  my ($libname)    = $self->find_file("$build_out/lib", qr/\.$dlext[\d\.]+$/);
  #  if($self->invoked_action() eq 'test') {
  #    my $cmd = "install_name_tool -id $libname $libname";
  #    print "Changing lib id ...\n(cmd: $cmd)\n";
  #    $self->do_system($cmd);
  #  }
  #  elsif($self->invoked_action() eq 'install') {
  #    $libname         = $1 if $libname =~ /([^\\\/]+)$/;
  #    my $cmd = "install_name_tool -id $sharedir/$share_subdir/lib/$libname sharedir/$share_subdir/lib/$libname";
  #    print "Changing lib id ...\n(cmd: $cmd)\n";
  #    $self->do_system($cmd);
  #  }
  #}

  $self->SUPER::ACTION_code;
}

sub fetch_file {
  my ($self, $url, $sha1sum, $download) = @_;
  die "###ERROR### _fetch_file undefined url\n" unless $url;
  die "###ERROR### _fetch_file undefined sha1sum\n" unless $sha1sum;
  my $ff = File::Fetch->new(uri => $url);
  my $fn = catfile($download, $ff->file);
  if (-e $fn) {
    print "Checking checksum for already existing '$fn'...\n";
    return 1 if $self->check_sha1sum($fn, $sha1sum);
    unlink $fn; #exists but wrong checksum
  }
  print "Fetching '$url'...\n";
  my $fullpath = $ff->fetch(to => $download);
  die "###ERROR### Unable to fetch '$url'" unless $fullpath;
  if (-e $fn) {
    print "Checking checksum for '$fn'...\n";
    return 1 if $self->check_sha1sum($fn, $sha1sum);
    die "###ERROR### Checksum failed '$fn'";
  }
  die "###ERROR### _fetch_file failed '$fn'";
}

sub fetch_sources {
  my ($self, $download) = @_;
  my $bp = $self->notes('build_params');
  $self->fetch_file($bp->{url}, $bp->{sha1sum}, $download);
}

sub extract_sources {
  my ($self, $download, $build_src) = @_;
  my $bp = $self->notes('build_params');

  my $srcdir = catfile($build_src, $bp->{dirname});
  my $unpack = 'y';
  $unpack = $self->prompt("Dir '$srcdir' exists, wanna replace with clean sources?", "n") if (-d $srcdir);
  if (lc($unpack) eq 'y') {
    $self->clean_dir($srcdir);
    my $archive = catfile($download, File::Fetch->new(uri => $bp->{url})->file);
    print "Extracting sources...\n";
    my $ae = Archive::Extract->new( archive => $archive );
    die "###ERROR###: cannot extract $bp ", $ae->error unless $ae->extract(to => $build_src);
    $self->apply_patch($build_src, $_) foreach (@{$bp->{patches}});
  }
  return 1;
}

sub set_config_data {
  my( $self, $build_out ) = @_;

  # try to find Box2D root dir
  my $prefix = rel2abs($build_out);
  $self->config_data('share_subdir', $self->{properties}->{dist_version});

  # set defaults
  my $cfg = {
    # defaults (used on MS Windows build)
    version     => $self->notes('build_box2d_version'),
    prefix      => '@PrEfIx@',
    libs        => '-L' . $self->quote_literal('@PrEfIx@/lib') . ' -lBox2D',
    cflags      => '-I' . $self->quote_literal('@PrEfIx@/include'),
    shared_libs => [ ],
  };
  
  if($^O =~ /(bsd|linux)/) {
    $cfg->{libs} = '-L' . $self->quote_literal('@PrEfIx@/lib') . ' -Wl,-rpath,' . $self->quote_literal('@PrEfIx@/lib') . ' -lBox2D -lm',
  }

  # write config
  $self->config_data('config', $cfg);
}

sub build_binaries {
  my( $self, $build_out, $build_src ) = @_;
  my $bp = $self->notes('build_params');

  print "BUILDING '" . $bp->{dirname} . "'...\n";
  my $srcdir = catfile($build_src, $bp->{dirname});
  my $prefixdir = rel2abs($build_out);  
  $self->config_data('build_prefix', $prefixdir); # save it for future Alien::Box2D::ConfigData
  
  # some platform specific stuff
  my $makefile = $^O eq 'MSWin32' ? rel2abs('patches/Makefile.mingw') : rel2abs('patches/Makefile.unix'); 
  my $cxxflags = '-O3';
  $cxxflags .= ' -fPIC' if $Config{cccdlflags} =~ /-fPIC/;
  # MacOSX related flags
  $cxxflags .= ' -arch x86_64' if $Config{ccflags} =~ /-arch x86_64/;
  $cxxflags .= ' -arch i386' if $Config{ccflags} =~ /-arch i386/;
  $cxxflags .= ' -arch ppc' if $Config{ccflags} =~ /-arch ppc/;

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
  my @cmd = ($Config{make}, '-f', $makefile, "PREFIX=$prefixdir", 'install');
  push @cmd, "CXXFLAGS=$cxxflags" if $cxxflags;
  #push @cmd, "CXX=g++"; ### the default in makefile.unix is 'c++' - here you can override it
  printf("(cmd: %s)\n", join(' ', @cmd));
  $self->do_system(@cmd) or die "###ERROR### [$?] during make ... ";
  chdir $self->base_dir();
  
  return 1;
}

sub clean_dir {
  my( $self, $dir ) = @_;
  if (-d $dir) {
    File::Path::rmtree($dir);
    File::Path::mkpath($dir);
  }
}

sub check_build_done_marker {
  my $self = shift;
  return (-e 'build_done');
}

sub touch_build_done_marker {
  my $self = shift;
  require ExtUtils::Command;
  local @ARGV = ('build_done');
  ExtUtils::Command::touch();
  $self->add_to_cleanup('build_done');
}

sub clean_build_done_marker {
  my $self = shift;
  unlink 'build_done' if (-e 'build_done');
}

sub check_sha1sum {
  my ($self, $file, $sha1sum) = @_;
  my $sha1 = Digest::SHA->new;
  my $fh;
  open($fh, $file) or die "###ERROR## Cannot check checksum for '$file'\n";
  binmode($fh);
  $sha1->addfile($fh);
  close($fh);
  return ($sha1->hexdigest eq $sha1sum) ? 1 : 0
}

sub find_file {
  my ($self, $dir, $re) = @_;
  my @files;
  $re ||= qr/.*/;
  find({ wanted => sub { push @files, rel2abs($_) if /$re/ }, follow => 1, no_chdir => 1 , follow_skip => 2}, $dir);
  return @files;
}

sub quote_literal {
    my ($self, $txt) = @_;
    if ($^O eq 'MSWin32') {
      $txt =~ s|"|\\"|g;
      return qq("$txt");
    }
    return $txt;    
}

# pure perl implementation of patch functionality
sub apply_patch {
  my ($self, $dir_to_be_patched, $patch_file) = @_;
  my ($src, $diff);

  undef local $/;
  open(DAT, $patch_file) or die "###ERROR### Cannot open file: '$patch_file'\n";
  $diff = <DAT>;
  close(DAT);
  $diff =~ s/\r\n/\n/g; #normalise newlines
  $diff =~ s/\ndiff /\nSpLiTmArKeRdiff /g;
  my @patches = split('SpLiTmArKeR', $diff);

  print STDERR "Applying patch file: '$patch_file'\n";
  foreach my $p (@patches) {
    my ($k) = map{$_ =~ /\n---\s*([\S]+)/} $p;
    # doing the same like -p1 for 'patch'
    $k =~ s|\\|/|g;
    $k =~ s|^[^/]*/(.*)$|$1|;
    $k = catfile($dir_to_be_patched, $k);
    print STDERR "- gonna patch '$k'\n" if $self->notes('build_debug_info');

    open(SRC, $k) or die "###ERROR### Cannot open file: '$k'\n";
    $src  = <SRC>;
    close(SRC);
    $src =~ s/\r\n/\n/g; #normalise newlines

    my $out = eval { Text::Patch::patch( $src, $p, { STYLE => "Unified" } ) };
    if ($out) {
      open(OUT, ">", $k) or die "###ERROR### Cannot open file for writing: '$k'\n";
      print(OUT $out);
      close(OUT);
    }
    else {
      warn "###WARN### Patching '$k' failed: $@";
    }
  }
}

1;
