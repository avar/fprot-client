use inc::Module::Install;

name 'FProt-Client';
author 'Ævar Arnfjörð Bjarmason <avar@f-prot.com>';

abstract_from 'Client.pm';
version_from  'Client.pm';
license_from  'Client.pm';

requires 'IO::Socket::INET';

# t/
build_requires 'Test::More';

# t/scan_file.t
build_requires 'File::Temp';
build_requires 'File::stat';
build_requires 'Cwd';
build_requires 'File::Spec::Functions';

# Don't install this for now
#install_script  glob 'script/*';

auto_install;

tests 't/*.t';

WriteAll;
