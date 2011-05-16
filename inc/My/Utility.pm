package My::Utility;
use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(check_prebuilt_binaries check_src_build find_Box2D_dir find_file sed_inplace);
use Config;
use File::Spec::Functions qw(splitdir catdir splitpath catpath rel2abs);
use File::Find qw(find);
use File::Copy qw(cp);
use Cwd qw(realpath);

our $cc = $Config{cc};

my $prebuilt_binaries = [
    {
      title    => "Binaries Win/32bit Box2D-2.1.2",
      url      => 'http://froggs.de/libbox2d/Win32_Box2D-2.1.2_20110516.zip',
      version  => '2.1.2',
      sha1sum  => '451dc65f3a1719945336b592f113ce8474ac358e',
      arch_re  => qr/^MSWin32-x86-multi-thread$/,
      os_re    => qr/^MSWin32$/,
      cc_re    => qr/cc/,
    },
];

my $source_packs = [
## the first set for source code build will be a default option
  {
    title   => "Source code build: Box2D 2.1.2 (needs cmake)",
    dirname => 'Box2D_v2.1.2/Box2D/Box2D',
    url => 'http://box2d.googlecode.com/files/Box2D_v2.1.2.zip',
    sha1sum  => 'b1f09f38fc130ae6c17e1767747a3a82bf8e517f',
    patches => [ ],
  },
## you can add another src build set
];

sub check_prebuilt_binaries
{
  print "Gonna check availability of prebuilt binaries ...\n";
  print "(os=$^O cc=$cc archname=$Config{archname})\n";
  my @good = ();
  foreach my $b (@{$prebuilt_binaries}) {
    if ( ($^O =~ $b->{os_re}) &&
         ($Config{archname} =~ $b->{arch_re}) &&
         ($cc =~ $b->{cc_re}) ) {
      $b->{buildtype} = 'use_prebuilt_binaries';

      push @good, $b;
    }
  }
  #returning ARRAY of HASHREFs (sometimes more than one value)
  return \@good;
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

sub find_Box2D_dir {
  my $root = shift;
  my ($prefix, $incdir, $libdir);
  return unless $root;

  # try to find Box2D.h
  my ($found) = find_file($root, qr/Box2D\.h$/i ); # take just the first one
  return unless $found;
  
  # get prefix dir
  my ($v, $d, $f) = splitpath($found);
  my @pp = reverse splitdir($d);
  shift(@pp) if(defined($pp[0]) && $pp[0] eq '');
  shift(@pp) if(defined($pp[0]) && $pp[0] eq 'Box2D');
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
