use Test::More;
use FProt::Client;

my $fpc = FProt::Client->new;

$fpc->ping
    ? plan tests => 3
    : plan skip_all => "fpscand must be running on $fpc->{host}:$fpc->{port}";

{
    no strict 'refs';
    cmp_ok
        *{"FProt::Client::quit"}{CODE},
        '==',
        *{"FProt::Client::DESTROY"}{CODE},
        "DESTROY is aliased to quit";
}

$fpc->ping; # Force it to open a socket

ok(defined $fpc->{socket}, "socket opened");

$fpc->quit;

ok(!defined($fpc->{socket}), "socket closed");
