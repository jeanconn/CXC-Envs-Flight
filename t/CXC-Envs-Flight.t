# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl CXC-Envs-Flight.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 5;
BEGIN { use_ok('CXC::Envs::Flight') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use Data::Dumper;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

ok((defined $ENV{SKA} and -d $ENV{SKA} and -d "$ENV{SKA}/lib/perl"),
   "SKA env var is a valid SKA runtime environment root");

%SKAENV = CXC::Envs::Flight::env('ska');

ok($SKAENV{SKA_DATA} eq "$ENV{SKA}/data", "SKA_DATA = $ENV{SKA}/data");

ok($SKAENV{PATH} =~ "$ENV{SKA}/bin", "PATH includes $ENV{SKA}/bin");

$cmds_sh = CXC::Envs::Flight::shell_cmds('sh','ska');
$cmds_tcsh =  CXC::Envs::Flight::shell_cmds('tcsh','ska');
$cmds_csh = CXC::Envs::Flight::shell_cmds('csh','ska');
ok(($cmds_sh =~ m|SKA_DATA=$ENV{SKA}/data|
   and $cmds_csh =~ m|SKA_DATA $ENV{SKA}/data|
   and $cmds_tcsh =~ m|SKA_DATA $ENV{SKA}/data|),
   "Shell commands");



