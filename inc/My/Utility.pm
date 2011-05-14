package My::Utility;
use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(check_config_script check_prebuilt_binaries check_src_build find_ODE_dir find_file sed_inplace);
use Config;
use File::Spec::Functions qw(splitdir catdir splitpath catpath rel2abs);
use File::Find qw(find);
use File::Copy qw(cp);
use Cwd qw(realpath);

my $source_packs = [
## the first set for source code build will be a default option
  {
    title   => "Source code build: ODE 0.11.1, single precision (RECOMMENDED)",
    precision => 'single',
    dirname => 'ode-0.11.1',
    url => 'http://downloads.sourceforge.net/opende/ode-0.11.1.tar.gz',
    sha1sum  => 'dcbfeec0091d16a9374a32cdac3758f4eee609f1',
    patches => [ ],
  },
## you can add another src build set
  {
    title   => "Source code build: ODE 0.11.1, double precision",
    precision => 'double',
    dirname => 'ode-0.11.1',
    url => 'http://downloads.sourceforge.net/opende/ode-0.11.1.tar.gz',
    sha1sum  => 'dcbfeec0091d16a9374a32cdac3758f4eee609f1',
    patches => [ ],
  },
];

sub check_config_script
{
  my $script = shift || 'ode-config';
  print "Gonna check config script...\n";
  print "(scriptname=$script)\n";
  my $devnull = File::Spec->devnull();
  my $version = `$script --version 2>$devnull`;
  return if($? >> 8);
  my $prefix = `$script --prefix 2>$devnull`;
  return if($? >> 8);
  $version =~ s/[\r\n]*$//;
  $prefix =~ s/[\r\n]*$//;
  #returning HASHREF
  return {
    title     => "Already installed ODE ver=$version path=$prefix",
    buildtype => 'use_config_script',
    script    => $script,
    prefix    => $prefix,
  };
}

sub check_src_build
{
  print "Gonna check possibility for building from sources ...\n";
  print "(os=$^O cc=$Config{cc})\n";
  foreach my $p (@{$source_packs}) {
    $p->{buildtype} = 'build_from_sources';
  }
  return $source_packs;
}

sub find_file {
  my ($dir, $re) = @_;
  my @files;
  $re ||= qr/.*/;
  find({ wanted => sub { push @files, rel2abs($_) if /$re/ }, follow => 1, no_chdir => 1 , follow_skip => 2}, $dir);
  return @files;
}

sub find_ODE_dir {
  my $root = shift;
  my ($prefix, $incdir, $libdir);
  return unless $root;

  # try to find ode.h
  my ($found) = find_file($root, qr/ode\.h$/i ); # take just the first one
  return unless $found;
  
  # get prefix dir
  my ($v, $d, $f) = splitpath($found);
  my @pp = reverse splitdir($d);
  shift(@pp) if(defined($pp[0]) && $pp[0] eq '');
  shift(@pp) if(defined($pp[0]) && $pp[0] eq 'ode');
  if(defined($pp[0]) && $pp[0] eq 'include') {
    shift(@pp);
    @pp = reverse @pp;
    return (
      catpath($v, catdir(@pp), ''),
      catpath($v, catdir(@pp, 'include'), ''),
      catpath($v, catdir(@pp, 'lib'), ''),
    );
  }
}

sub sed_inplace {
  # we expect to be called like this:
  # sed_inplace("filename.txt", 's/0x([0-9]*)/n=$1/g');
  my ($file, $re) = @_;
  if (-e $file) {
    cp($file, "$file.bak") or die "###ERROR### cp: $!";
    open INPF, "<", "$file.bak" or die "###ERROR### open<: $!";
    open OUTF, ">", $file or die "###ERROR### open>: $!";
    binmode OUTF; # we do not want Windows newlines
    while (<INPF>) {
     eval( "$re" );
     print OUTF $_;
    }
    close INPF;
    close OUTF;
  }
}

1;
