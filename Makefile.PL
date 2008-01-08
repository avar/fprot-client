use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'FProt::Client',
    AUTHOR        => 'Ævar Arnfjörð Bjarmason <avar@cpan.org>',
    ABSTRACT_FROM => 'Client.pm',
    VERSION_FROM  => 'Client.pm',
    LICENSE       => 'perl',
    PREREQ_PM     => {
        # Client.pm
        'IO::Socket::INET'         => 0,

        # t/
        'Test::More' => 0,

        # t/scan_file.t
        'File::Temp'            => 0,
        'File::stat'            => 0,
        'Cwd'                   => 0,
        'File::Spec::Functions' => 0,
    },
);
