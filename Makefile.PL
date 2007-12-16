use 5.006001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Func::XMLRPC',
    VERSION_FROM      => 'lib/Func/XMLRPC.pm', # finds $VERSION
    PREREQ_PM         => {
        'Params::Validate' => '0.84',
        'XMLRPC::Lite' => '0.60',
        'SOAP::Transport::HTTP' => '0.60',
        'Net::SSLeay' => '1.31',
        'PathTools' => '3.22' # for File::Spec
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Func/XMLRPC.pm', # retrieve abstract from module
       AUTHOR         => 'Al Tobey <tobert@gmail.com>') : ()),
);

