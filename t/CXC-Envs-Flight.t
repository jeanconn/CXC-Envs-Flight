# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl CXC-Envs-Flight.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 7;
BEGIN { use_ok('CXC::Envs::Flight') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Data::Dumper;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

$test = 2;

{
    local %ENV = CXC::Envs::Flight::env('ska');
#   map { print STDERR "$_ = $ENV{$_}\n" } keys %ENV;
    ok($ENV{SKA_DATA} eq '/proj/sot/ska/data', "Default environment\n");
    $test++;
}

{
    local %ENV = %ENV;
    $ENV{SKA} = '/proj/junk';
    %ENV = CXC::Envs::Flight::env('ska');
#   map { print STDERR "$_ = $ENV{$_}\n" if /SKA|TST|AXAF|MST|PERL/ } keys %ENV;
    ok($ENV{SKA_DATA} eq '/proj/junk/data', "*** SKA = /proj/junk\n");
    $test++;
}

{
    local %ENV = %ENV;
    $ENV{SKA_LIB} = '/proj/junk/lib';
    %ENV = CXC::Envs::Flight::env('ska','tst');
#   map { print STDERR "$_ = $ENV{$_}\n" if /SKA|TST|AXAF|MST|PERL/ } keys %ENV;
    ok(($ENV{SKA_DATA} eq '/proj/sot/ska/data'
       and $ENV{SKA_LIB} eq '/proj/junk/lib'),
       "Set SKA_LIB = /proj/junk/lib\n");
    $test++;
}

{
    local %ENV = %ENV;
    %ENV = CXC::Envs::Flight::env('tst');
#    map { print STDERR "$_ = $ENV{$_}\n" if /SKA|TST|AXAF|MST|PERL/ } keys %ENV;
    ok((not defined $ENV{SKA_DATA}
       and $ENV{TST_DATA} eq '/proj/sot/tst/data'), "Set TST environment\n");
    $test++;
}

{
    local %ENV = %ENV;
    my $flt_envs = '.ska_envs';
    open ENV, "> $flt_envs" or die "Could not open $flt_envs";
    print ENV "SKA = /proj/.ska_envs\n";
    print ENV "SKA_DATA=/proj/ska_data/test\n";
    close ENV;
    %ENV = CXC::Envs::Flight::env('ska');
#    map { print STDERR "$_ = $ENV{$_}\n" if /SKA|TST|AXAF|MST|PERL/ } keys %ENV;
    unlink $flt_envs or die "Could not unlink $flt_envs";
    ok(($ENV{SKA_DATA} eq '/proj/ska_data/test'
       and $ENV{SKA} eq '/proj/.ska_envs'), "Use .flt_envs file");
    $test++;
}

{
    $cmds_sh = CXC::Envs::Flight::shell_cmds('sh','tst');
    $cmds_tcsh =  CXC::Envs::Flight::shell_cmds('tcsh','ska');
    $cmds_csh = CXC::Envs::Flight::shell_cmds('csh','tst','ska');
    ok(($cmds_sh =~ m|TST_DATA=/proj/sot/tst/data|
       and $cmds_csh =~ m|SKA_DATA /proj/sot/ska/data|
       and $cmds_tcsh =~ m|SKA_DATA /proj/sot/ska/data|),
       "Shell commands\n");
    $test++;
}

