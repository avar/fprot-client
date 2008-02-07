use Test::More;

use File::stat;
use File::Temp qw(tempfile);

use FindBin qw($Bin);
use File::Spec::Functions qw(catfile);

use FProt::Client;

my $eicar_txt = catfile($Bin => qw(data eicar.txt));
my $eicar_com = catfile($Bin => qw(data eicar.com));
my $eicar_zip = catfile($Bin => qw(data eicar.zip));

my $fpc = FProt::Client->new;

$fpc->ping
    ? plan tests => 13
    : plan skip_all => "fpscand must be running on $fpc->{host}:$fpc->{port}";

my (@r, $st, $fh);

#open $fh, '<', $eicar_txt or die $!;
#@r = $fpc->scan_stream($eicar_txt, $fh, stat($eicar_txt)->size);
#cmp_ok $r[0], '==', 0, "$eicar_txt status is clean";
#cmp_ok $r[1], 'eq', 'clean', "$eicar_txt message is clean";
#cmp_ok $r[2], 'eq', $eicar_txt, "$eicar_txt path";

open $fh, '<', $eicar_com or die $!;
@r = $fpc->scan_stream($eicar_com, $fh, stat($eicar_com)->size);
cmp_ok $r[0], '==', 1, "$eicar_com is infected";
cmp_ok $r[1], 'eq', 'infected: EICAR_Test_File', "$eicar_com is clean";
cmp_ok $r[2], 'eq', $eicar_com, "$eicar_com path";

open $fh, '<', $eicar_zip or die $!;
@r = $fpc->scan_stream($eicar_zip, $fh, stat($eicar_zip)->size);
cmp_ok $r[0], '==', 1, "$eicar_zip is an infected archive";
cmp_ok $r[1], 'eq', 'contains infected objects: EICAR_Test_File', "$eicar_com is clean";
cmp_ok $r[2], 'eq', $eicar_zip, "$eicar_zip path";
cmp_ok $r[3], 'eq', 'eicar.com', "$eicar_zip contains eicar.com";

# Test scan options

my %opt = (
    scanlevel => 3,
    heurlevel => 3,
);

open $fh, '<', $eicar_zip or die $!;
@r = $fpc->scan_stream(\%opt, $eicar_zip, $fh, stat($eicar_zip)->size);
cmp_ok $r[0], '==', 1, "$eicar_zip is an infected archive";
cmp_ok $r[1], 'eq', 'contains infected objects: EICAR_Test_File', "$eicar_com is clean";
cmp_ok $r[2], 'eq', $eicar_zip, "$eicar_zip path";
cmp_ok $r[3], 'eq', 'eicar.com', "$eicar_zip contains eicar.com";

close $fh;

#
# Generate a 10MB which the daemon won't accept and offer it
#

$fh = File::Temp->new; $fh->unlink_on_destroy(1);
my $name = $fh->filename;

# Write 10MB to the file
print $fh "0" x (2**20*10);

@r = $fpc->scan_stream($name, $fh, stat($name)->size);
cmp_ok $r[0], '==', 16, "$name is too large to be sent over the wire";
cmp_ok $r[1], 'eq', 'Stream is too long', 'Error about file being too large';
