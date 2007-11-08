use Test::More;
use FProt::Client;

my $fpc = FProt::Client->new;

$fpc->ping
    ? plan tests => 2
    : plan skip_all => "fpscand must be running on $fpc->{host}:$fpc->{port}";

ok($fpc->ping, "Pinged the fpscand");

$fpc = FProt::Client->new(port => 10201);
ok(!$fpc->ping, "Failed to ping non-existing fpscand");
