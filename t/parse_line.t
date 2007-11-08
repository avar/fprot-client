use Test::More tests => 5;
use FProt::Client;

my $file = "/omg/teh/virus.exe";
my $object  = "PP97M/Darby.B";
my $subobject = "zomg.exe";

my @test = (
    "0 <clean> $object",
    [ qw(0 clean), $object ],

    "4 <interrupted> $object",
    [ qw(4 interrupted), $object ],

    "1 <infected: PP97M/Darby.B> $object",
    [ "1", "infected: PP97M/Darby.B", $object ],

    "1 <contains infected objects: EICAR_Test_File> $object->$subobject",
    [ "1", "contains infected objects: EICAR_Test_File", $object, $subobject ],

    "16 <Stream is too long>",
    [ "16", "Stream is too long" ],
);

while (my ($line, $exp) = splice @test, 0, 2) {
    my @res = FProt::Client->parse_line($line);
    is_deeply $exp, \@res, "Parsing for '$line'";
}













