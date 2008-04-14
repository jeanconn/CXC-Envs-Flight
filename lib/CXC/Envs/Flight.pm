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

my $version = '$Id: Flight.pm,v 1.22 2008-04-14 18:13:52 aldcroft Exp $';  # '
my $VERSION = '1.9';

my %DEFAULT = (SKA => $ENV{SKA_RE} || '/proj/sot/ska',
		TST => '/proj/sot/tst',
		MST => '/proj/axaf',
		SYBASE => '/soft/sybase',
	       );

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;

##***************************************************************************
sub shell_cmds {
# Print shell commands to set new Ska environment variables
##***************************************************************************
    unless (@_ >= 2) {
	carp "CXC::Envs::Flight::shell_cmds - Usage: shell_cmds(<shell>, <Flt_env>, ...";
	return;
    }
    my $shell = shift;
    my ($var, $val);
    my $cmds;

    my %new = map { flt_environment($_) } @_;
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
    unless (@_ >= 1) {
	carp "CXC::Envs::Flight::env - Usage: env(<Flt_env>, ...";
	return %ENV;
    }

    my %env;
    foreach (@_) {
	%env = (%env, flt_environment($_));
    }
    return (%ENV, %env);
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
	       PERLLIB => 'lib/perl',
	      );

    # Look for a file ".${flt}_envs" in the current directory which will override all 
    # defaults and current Env vars
    if (-r ".${flt}_envs") {
	open(ENV, ".${flt}_envs") or die "Unexpected read failure for .${flt}_envs: $!";
	while (<ENV>) {
	    next if (/\A \s* \#/x);
	    next unless (my ($key, $val) = /(\S+) \s* = (.+)/x); 
	    ($env{$key} = $val) =~ s/\A\s+|\s+\Z//g ;
	}
	close ENV;
    }

    # Now fill in values for anything that is not yet defined
    $env{$FLT} = $env{$FLT} || $ENV{$FLT} || $DEFAULT{$FLT};
    foreach (keys %new) {
	$env{"${FLT}_$_"} = $env{"${FLT}_$_"} || $ENV{"${FLT}_$_"} || "$env{$FLT}/$new{$_}";
    }

    $env{SYBASE} = $ENV{SYBASE} || $DEFAULT{SYBASE};
    $env{AXAF_ROOT} = $ENV{AXAF_ROOT} || $DEFAULT{MST};
    $env{MST_PERLLIB} = $ENV{MST_PERLLIB} || "$DEFAULT{MST}/simul/lib/perl";


    # Set Perl library path.  Start with SKA_PERLLIB, then /proj/sot/ska/lib/perl, then MST_PERLLIB
    my @perl5lib = ($env{"${FLT}_PERLLIB"},
		    $env{"${FLT}_PERLLIB"} . '/lib',
		    $DEFAULT{SKA} . "/lib/perl",
		    $DEFAULT{SKA} . "/lib/perl/lib");

    $env{PERL5LIB} = add_unique_path($ENV{PERL5LIB},
				     @perl5lib);

    # Find a version of sysarch and run it to determine the system architecture
    my %sysarch;
    for my $sysarch_path ($env{"${FLT}_BIN"}, "$DEFAULT{SKA}/bin") {
	my $sysarch = "$sysarch_path/sysarch";
	if (-x $sysarch) {
	    my $sysarch_values = `$sysarch -perl_hash`;
	    %sysarch = eval "( $sysarch_values )";
	}
    }
    chomp (my $OS = $sysarch{OS} || `uname -s`);

    my @sys_path;
    @sys_path = qw(/usr/ccs/bin /usr/ucb /usr/bin /usr/local/bin /opt/local/bin) if ($OS eq 'SunOS');
    @sys_path = qw(/bin /usr/bin /usr/local/bin) if ($OS eq 'Linux');

    $env{PATH} = add_unique_path($ENV{PATH},
				 $env{"${FLT}_BIN"},
				 "$env{$FLT}/$sysarch{platform_os_generic}/bin",
				 "$env{$FLT}/$sysarch{platform_generic}/bin",
				 @sys_path);

    $env{LD_LIBRARY_PATH} = add_unique_path($ENV{LD_LIBRARY_PATH},
					    "$env{$FLT}/$sysarch{platform_os_generic}/lib/pgplot",
					    "$env{$FLT}/$sysarch{platform_generic}/lib/pgplot",
					    );
					    

    $env{PGPLOT_DIR} = add_unique_path($ENV{PGPLOT_DIR},
				       "$env{$FLT}/$sysarch{platform_os_generic}/lib/pgplot",
				       "$env{$FLT}/$sysarch{platform_generic}/lib/pgplot");
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

  local %ENV = CXC::Envs::Flight::env('ska','tst'); # Adds Ska and TST env to existing ENV
  $cmds = CXC::Envs::Flight::shell_cmds('tcsh','ska');     # Return tcsh commands to set environment
                                            # Allowed options are tcsh, csh, sh

=head1 DESCRIPTION

This module sets environment variables for "Flight" software, which 
currently includes aspect operations tools (Ska) and TST tools (TST).

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

It also puts SKA_BIN at the head of the PATH and puts SKA_PERLLIB and MST_PERLLIB
at the head of the PERL5LIB path.

If the file .ska_envs is present in the run directory, CXC::Envs::Flight will use these 
values to override any defaults or environment variables.  This file consists
of name-value pairs, one on each line:
  
   <VAR> = <VALUE>

Spaces are not important, and lines preceded by # are ignored.  Variable substitution
(e.g. SKA_LIB = $SKA/my_lib) is not allowed.

Likewise, the TST environment sets all the corresponding variables with SKA => TST, where
the default TST root directory is

                   Default
    TST            /proj/sot/tst

=head1 FUNCTIONS

The following functions are provided

=over 8

=item env(<Flt_env>, ...)

Generates the environment variables for the specified flight environments.
Allowed values of <Flt_env> are 'ska' and 'tst'.  If multiple values
are specified, they are added from left to right, so libraries/paths from the
last one will take precedence.

=item shell_cmds(<shell_type>, <Flt_env>, ...)

Generates the shell commands to set environment variables for the specified
flight environments.  The supported shells are sh, ksh, csh, and tcsh. 
Allowed values of <Flt_env> are 'ska' and 'tst'.  If multiple values are
specified, they are added from left to right, so libraries/paths from the last
one will take precedence.

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
