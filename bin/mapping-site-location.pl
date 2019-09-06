#!/usr/bin/env perl
use strict;
use warnings qw(FATAL utf8);   # encoding errors raise exceptions
# use utf8;                    # source is in UTF-8
use open qw(:utf8 :std);       # default open mode, `backticks`, and std{in,out,err} are in UTF-8

use Function::Parameters qw( :strict );
use File::Slurp;
use YAML::XS;
use Encode qw( decode_utf8 );
use Cpanel::JSON::XS;;
use POSIX qw( strftime );
use Text::CSV::Slurp;
use Data::Dumper;

# $YAML::XS::UseCode=1;

my $yaml = read_file($ARGV[0]);
my @array = Load $yaml;

my @new_csv;

my $old_site = 'old_site';
my $new_site = 'new_site';
for my $item (@array) {

    my $item_ref = ref($item);
    my $row;
    my $slug = $item->{attributes}{slug};

    if ($item_ref =~ m{^ruby\/object:(CanpubArticle|EvtEvent)$} ) {
        my $prefix = ($1 eq "EvtEvent" ? "events/event" : "/articles/article");
        $row->{$old_site} = "$prefix/$slug";
        $row->{$new_site} = "/$slug/";
        push @new_csv, $row;
    }
}

my @heading_order = ( $old_site, $new_site );

write_csv('/app/data/site_mapping.csv', \@new_csv, \@heading_order);

fun write_csv($filename, $data, $order) {
    my $csv = Text::CSV::Slurp->create(input => $data, field_order => $order);

    open my $fh, '>', $filename;
    print $fh $csv;
    close $fh;
}
