use Test::More tests => 9;
use FProt::Client;

my $fpc;

$fpc = FProt::Client->new;
isa_ok($fpc, "FProt::Client");

cmp_ok $fpc->{host}, 'eq', '127.0.0.1', 'default host = 127.0.0.1';
cmp_ok $fpc->{port}, 'eq', '10200', 'default port = 10200';

$fpc = FProt::Client->new(port => 1234);
cmp_ok $fpc->{host}, 'eq', '127.0.0.1', 'default host = 127.0.0.1';
cmp_ok $fpc->{port}, 'eq', '1234', 'custom port = 1234';

$fpc = FProt::Client->new(host => 'scan.aves.f-prot.com'); # fictional
cmp_ok $fpc->{host}, 'eq', 'scan.aves.f-prot.com', 'custom host = scan.aves.f-prot.com';
cmp_ok $fpc->{port}, 'eq', '10200', 'default port = 1234';

# Invalid usage

local $@;
eval { $fpc = FProt::Client->new(port => "abc"); };
like $@, qr/non-numeric/i, "Invalid port";

local $@;
eval { $fpc = FProt::Client->new(host => "127.0.0.1:10200"); };
like $@, qr/use the port argument for ports/i, "Invalid host argument";






