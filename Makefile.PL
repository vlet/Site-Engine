use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Site::Engine',
    VERSION_FROM      => 'lib/Site/Engine.pm', # finds $VERSION
    PREREQ_PM         => {
        CGI => 0,
        DBI => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Site/Engine.pm', # retrieve abstract from module
       AUTHOR         => 'Vladimir Lettiev <thecrux@gmail.com>') : ()),
);
