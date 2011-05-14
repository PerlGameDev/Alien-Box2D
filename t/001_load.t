# t/001_load.t - test module loading and basic functionality

use Test::More tests => 1;

BEGIN { use_ok( 'Alien::ODE' ); }

diag( "Testing Alien::ODE $Alien::ODE::VERSION, Perl $], $^X" );

diag( "Build type: " . (Alien::ODE::ConfigData->config('build_params')->{buildtype} || 'n.a.') );
diag( "Detected ode-config script: " . (Alien::ODE::ConfigData->config('build_params')->{script} || 'n.a.') );
diag( "Build option used:\n\t" . (Alien::ODE::ConfigData->config('build_params')->{title} || 'n.a.') );
diag( "URL: " . (Alien::ODE::ConfigData->config('build_params')->{url} || 'n.a.') );
diag( "SHA1: " . (Alien::ODE::ConfigData->config('build_params')->{sha1sum} || 'n.a.') );
