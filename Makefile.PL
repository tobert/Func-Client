use 5.006001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Func::Client',
    VERSION_FROM      => 'lib/Func/Client.pm', # finds $VERSION
    PREREQ_PM         => {
        'Params::Validate' => '0.84',
        'Crypt::SSLeay' => '0.47',
        'File::Spec' => '3.22',
        'Regexp::Common' => '1.9',
        'Test::More' => 0.01,
        'Test::Exception' => '0.25'
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Func/Client.pm', # retrieve abstract from module
       AUTHOR         => 'Al Tobey <tobert@gmail.com>') : ()),
);

