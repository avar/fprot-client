use Test::More;
use FindBin qw($Bin);
use File::Spec::Functions qw(catfile);
use FProt::Client;

my $eicar_txt = catfile($Bin => qw(data eicar.txt));
my $eicar_com = catfile($Bin => qw(data eicar.com));
my $eicar_zip = catfile($Bin => qw(data eicar.zip));

my $fpc = FProt::Client->new;

$fpc->ping
    ? plan tests => 10
    : plan skip_all => "fpscand must be running on $fpc->{host}:$fpc->{port}";

my @r; # ret

#@r = $fpc->scan_file($eicar_txt);
#cmp_ok $r[0], '==', 0, "$eicar_txt status is clean";
#cmp_ok $r[1], 'eq', 'clean', "$eicar_txt message is clean";
#cmp_ok $r[2], 'eq', $eicar_txt, "$eicar_txt path";

@r = $fpc->scan_file($eicar_com);
cmp_ok $r[0], '==', 1, "$eicar_com is infected";
cmp_ok $r[1], 'eq', 'infected: EICAR_Test_File', "$eicar_com is clean";
cmp_ok $r[2], 'eq', $eicar_com, "$eicar_com path";

@r = $fpc->scan_file($eicar_zip);
cmp_ok $r[0], '==', 1, "$eicar_zip is an infected archive";
cmp_ok $r[1], 'eq', 'contains infected objects: EICAR_Test_File', "$eicar_com is clean";
cmp_ok $r[2], 'eq', $eicar_zip, "$eicar_zip path";
cmp_ok $r[3], 'eq', 'eicar.com', "$eicar_zip contains eicar.com";

# Test scan options

my %opt = (
    scanlevel => 3,
    heurlevel => 3,
);

@r = $fpc->scan_file(\%opt, $eicar_com);
cmp_ok $r[0], '==', 1, "$eicar_com is infected";
cmp_ok $r[1], 'eq', 'infected: EICAR_Test_File', "$eicar_com is clean";
cmp_ok $r[2], 'eq', $eicar_com, "$eicar_com path";
