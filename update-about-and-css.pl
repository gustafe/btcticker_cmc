#! /usr/bin/env perl
use Modern::Perl '2015';
###

use Template;
use FindBin;
use Config::Simple;
use lib "$FindBin::Bin/lib";

use BTCTicker
    qw/changelog/;

my $cfg = new Config::Simple("$FindBin::Bin/btcticker.ini");
my $tt = Template->new(
    { INCLUDE_PATH => "$FindBin::Bin/templates", ENCODING => 'UTF-8' } );
my %data = (content => {changelog=>changelog(),},);
$tt->process('stylesheet.tt',\%data,    $cfg->param('HTML.stylesheet'),
    { binmode => ':utf8' }
) || die $tt->error;

$tt->process('about.tt',\%data,$cfg->param('HTML.about_page'),
    { binmode => ':utf8' }
) || die $tt->error;

