#!/usr/bin/env perl
use strict;
use warnings qw(FATAL utf8);   # encoding errors raise exceptions
# use utf8;                    # source is in UTF-8
use open qw(:utf8 :std);       # default open mode, `backticks`, and std{in,out,err} are in UTF-8

use File::Slurp;
use YAML::XS;
use Data::Structure::Util qw( unbless );
use Encode qw( decode_utf8 );
use Data::Dumper;

# $YAML::XS::UseCode=1;

my $yaml = read_file('data/backup.yml');
my @array = Load $yaml;
