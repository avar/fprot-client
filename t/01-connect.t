use Test::More tests => 1;
use FProt::Client;

my $fpc = FProt::Client->new;

ok($fpc => "connected successfully");
