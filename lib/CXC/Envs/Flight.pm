package CXC::Envs::Flight;

use 5.008000;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader qw(AUTOLOAD);
use Data::Dumper;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use CXC::Envs::Flight ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $version = '$Id: Flight.pm,v 1.5 2004-10-04 21:36:58 aldcroft Exp $';  # '
our $VERSION = '1.5';

our %DEFAULT = (SKA => '/proj/sot/ska',
		TST => '/proj/sot/tst',
		MST => '/proj/axaf',
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
    
    my %new = (LIB => 'lib',
	       BIN => 'bin',
	       DATA => 'data',
	       SHARE => 'share',
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

    $env{AXAF_ROOT} = $ENV{AXAF_ROOT} || $DEFAULT{MST};
    $env{MST_PERLLIB} = $ENV{MST_PERLLIB} || "$DEFAULT{MST}/simul/lib/perl";

    # Set PATH

    $env{PERL5LIB} = add_unique_path($ENV{PERL5LIB}, $env{"${FLT}_PERLLIB"}, $env{MST_PERLLIB});


    my $OS = `uname`;
    my @sys_path;
    @sys_path = qw(/usr/bin /usr/local/bin /opt/local/bin /usr/ccs/bin /usr/ucb) if ($OS eq 'SunOS');
    @sys_path = qw(/usr/bin /bin /usr/local/bin) if ($OS eq 'Linux');
    $env{PATH} = add_unique_path($ENV{PATH}, @sys_path, $env{"${FLT}_BIN"});

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
    map { unshift @path, $_ } reverse @new;
    
    # Build up a new path which eliminates any duplicates
    my %new_path;
    my @new_path;
    foreach (@path) {
	next if $new_path{$_};
	push @new_path, $_;
	$new_path{$_} = 1;
    }

    # Return the colon-separated path
    return join(':', @new_path);
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
