use Test::More;
use FProt::Client;

my $fpc = FProt::Client->new;

$fpc->ping
    ? plan tests => 5
    : plan skip_all => "fpscand must be running on $fpc->{host}:$fpc->{port}";

my %help = $fpc->info;

like $help{fpscand}, qr/^[0-9.]+$/, "FPSCAND format";
like $help{engine}, qr/^[0-9.]+$/, "ENGINE format";
like $help{protocol}, qr/^[0-9.]+$/, "PROTOCOL format";
like $help{signature}, qr/^[0-9]{4} [0-9]{2} [0-9]{2} [0-9a-f]{36}$/ix, "SIGNATURE format";
like $help{uptime}, qr/^[0-9:.]+$/i, "UPTIME format";



