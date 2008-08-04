package CXC::Envs::Flight;

use 5.005000;
use strict;
use Carp;

require Exporter;
use AutoLoader qw(AUTOLOAD);
use Data::Dumper;

my @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use CXC::Envs::Flight ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
my %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

my @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

my @EXPORT = qw(
	
);

our $VERSION = '1.94';

my %DEFAULT = (SKA => '/proj/sot/ska',
		TST => '/proj/sot/tst',
		MST => '/proj/axaf',
		SYBASE => '/soft/SYBASE_OCS15',  # Eventually change back to /soft/sybase
	       );

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;

##***************************************************************************
sub shell_cmds {
# Print shell commands to set new Ska environment variables
##***************************************************************************
    unless (@_ == 2) {
	carp "CXC::Envs::Flight::shell_cmds - Usage: shell_cmds(<shell>, <Flt_env>)";
	return;
    }
    my $shell = shift;
    my ($var, $val);
    my $cmds;

    my %new = flt_environment($_[0]);
    while (($var, $val) = each %new) {
	if ($shell eq 'sh' or $shell eq 'ksh') {
	    $cmds .= "$var=$val; export $var;\n";
	} elsif ($shell eq 'csh' or $shell eq 'tcsh') {
	    $cmds .= "setenv $var $val;\n";
	}
    }

    return $cmds;
}

##***************************************************************************
sub env {
# Return complete new ENV variable including Flight values
##***************************************************************************
    unless (@_ == 1) {
	carp "CXC::Envs::Flight::env - Usage: env(<Flt_env>)";
	return %ENV;
    }

    return (%ENV, flt_environment($_[0]));
}

##***************************************************************************
sub flt_environment {
# Return new Flight environment variables
##***************************************************************************
    my %env;
    local $_;
    my $flt = shift;
    my $FLT = uc $flt;
    
    my %new = (LIB     => 'lib',
	       BIN     => 'bin',
	       DATA    => 'data',
	       SHARE   => 'share',
	       IDL     => 'idl',
               ARCH    => 'arch',
	       PERLLIB => 'lib/perl',
	      );

    # Fill in values for anything that is not yet defined
    $env{$FLT} = $ENV{$FLT} || $DEFAULT{$FLT};
    foreach (keys %new) {
	$env{"${FLT}_$_"} = $ENV{"${FLT}_$_"} || "$env{$FLT}/$new{$_}";
    }

    $env{SYBASE} = $ENV{SYBASE} || $DEFAULT{SYBASE};
    $env{AXAF_ROOT} = $ENV{AXAF_ROOT} || $DEFAULT{MST};
    $env{MST_PERLLIB} = $ENV{MST_PERLLIB} || "$DEFAULT{MST}/simul/lib/perl";


    # Set Perl library path.  Start with SKA_PERLLIB, then /proj/sot/ska/lib/perl, then MST_PERLLIB
    my @perl5lib = ($env{"${FLT}_PERLLIB"},
		    $env{"${FLT}_PERLLIB"} . '/lib');

    $env{PERL5LIB} = add_unique_path($ENV{PERL5LIB},
				     @perl5lib);

    # Find a version of sysarch and run it to determine the system architecture
    my %sysarch;
    for my $path ($env{"${FLT}_BIN"}, "$DEFAULT{SKA}/bin") {
        if (-x "$path/sysarch") {
            %sysarch = eval "(" . `$path/sysarch -perl_hash` . ")";
            last;
        }
    }
    chomp (my $OS = $sysarch{OS} || `uname -s`);

    $env{"${FLT}_ARCH_OS"} = $env{"${FLT}_ARCH"} . "/" . $sysarch{platform_os_generic};
    my $flt_arch_os = $env{"${FLT}_ARCH_OS"};

    my @sys_path;
    @sys_path = qw(/usr/ccs/bin /usr/ucb /usr/bin /usr/local/bin /opt/local/bin) if ($OS eq 'SunOS');
    @sys_path = qw(/bin /usr/bin /usr/local/bin) if ($OS eq 'Linux');

    my @ld_lib_path = ("$flt_arch_os/pgplot");
    push @ld_lib_path, "/usr/local/lib" if ($OS eq 'SunOS');

    $env{PATH} = add_unique_path($ENV{PATH},
				 $env{"${FLT}_BIN"},
				 "$flt_arch_os/bin",
				 @sys_path);

    $env{LD_LIBRARY_PATH} = add_unique_path($ENV{LD_LIBRARY_PATH},
					    @ld_lib_path,
					    );
					    

    $env{PGPLOT_DIR} = add_unique_path("$flt_arch_os/pgplot",
                                       $ENV{PGPLOT_DIR},
				       );
    # Take just the first path value
    if (defined $env{PGPLOT_DIR}) {
	$env{PGPLOT_DIR} = (split(':', $env{PGPLOT_DIR}))[0];
    }

    # Clean out any new ENV vars that are not defined (i.e. no such paths existed)
    foreach (keys %env) {
	delete $env{$_} unless defined $env{$_};
    }
    
    return %env;
}

##***************************************************************************
sub add_unique_path {
# Add values to a ':' separated path
##***************************************************************************
    my ($path, @new) = @_;
    local $_;
    $path = "" unless defined $path;
    my @path = split ':', $path;
    
    # Put the new path elements at the front
    @path = (@new, @path);
    
    # Build up a new path which eliminates any duplicates
    my %new_path;
    my @new_path;
    foreach (@path) {
	next unless defined $_;
	next if $new_path{$_};
	next unless -d $_;
	push @new_path, $_;
	$new_path{$_} = 1;
    }

    # Return the colon-separated path
    return @new_path ? join(':', @new_path) : undef;
}

__END__

=head1 NAME

CXC::Envs::Flight - Perl extension to set environment variables for Aspect operations tools

=head1 SYNOPSIS

  use CXC::Envs::Flight;

  local %ENV = CXC::Envs::Flight::env('ska'); # Adds Ska env to existing ENV
  $cmds = CXC::Envs::Flight::shell_cmds('tcsh','ska');     # Return tcsh commands to set environment
                                            # Allowed options are tcsh, csh, sh, ksh

=head1 DESCRIPTION

This module sets environment variables for "Flight" software, which 
currently includes aspect operations tools (Ska).  

If the "ska" environoment is requested, the following environment variables are
set unless already defined:

                   Default
    SKA            /proj/sot/ska
    SKA_LIB        $SKA/lib
    SKA_BIN        $SKA/bin
    SKA_DATA       $SKA/data
    SKA_SHARE      $SKA/share
    SKA_IDL        $SKA/idl
    SKA_PERLLIB    $SKA/lib/perl
    MST_ROOT       /proj/axaf
    MST_PERLLIB    ${MST_ROOT}/simul/lib/perl
    SYBASE         /soft/SYBASE_OCS15

It also updates PATH, LD_LIBRARY_PATH, PERL5LIB, and PGPLOT_DIR to make the Ska
environment (tools and libraries) available and functional.

=head1 FUNCTIONS

The following functions are provided

=over 8

=item env(<Flt_env>)

Generates the environment variables for the specified flight environments.
Allowed values of <Flt_env> are 'ska'.  Support for additional environments
is possible in the future.

=item shell_cmds(<shell_type>, <Flt_env>)

Generates the shell commands to set environment variables for the specified
flight environments.  The supported shells are sh, ksh, csh, and tcsh. 
Allowed values of <Flt_env> are 'ska'.

=head1 SEE ALSO

MST_Envs

http://jeeves.cfa.harvard.edu/Commons/bin/view/OpsSoftOrg/AspectOpsReorg

=head1 AUTHOR

Tom Aldcroft, E<lt>aldcroft@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Tom Aldcroft

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
