# t/002_config.t - test config() functionality

use Test::More tests => 3;
use Alien::ODE;

### test some config strings
like( Alien::ODE->config('version'), qr/([0-9]+\.)*[0-9]+/, "Testing config('version')" );
like( Alien::ODE->config('prefix'), qr/.+/, "Testing config('prefix')" );

### check if prefix is a real directory
my $p = Alien::ODE->config('prefix');
is( (-d Alien::ODE->config('prefix')), 1, "Testing existence of 'prefix' directory" );

diag( "VERSION=" . Alien::ODE->config('version') );
diag( "PREFIX=" . Alien::ODE->config('prefix') );
diag( "CFLAGS=" . Alien::ODE->config('cflags') );
diag( "LIBS=" . Alien::ODE->config('libs') );
