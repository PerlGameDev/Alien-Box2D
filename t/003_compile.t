# t/002_config.t - test config() functionality

use Test::More;
use Alien::ODE;

plan skip_all => "This test is broken on cygwin" if ($^O eq 'cygwin');

eval "use ExtUtils::CBuilder 0.2703";
plan skip_all => "ExtUtils::CBuilder 0.2703 required for this test" if $@;

plan tests => 3;
my $cb = ExtUtils::CBuilder->new(quiet => 0);
my $obj = $cb->compile( source => 't/test1.c', 'C++' => 1, extra_compiler_flags => Alien::ODE->config('cflags'));
is( defined $obj, 1, "Compiling test1.c" );
my $exe = $cb->link_executable( objects => [ $obj ], extra_linker_flags => Alien::ODE->config('libs'));
is( defined $exe, 1, "Linking test1.c" );
my $rv = system($exe);
is( $rv, 0, "Executing test1" );
