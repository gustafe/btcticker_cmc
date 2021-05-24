#! /usr/bin/env perl
use Modern::Perl '2015';
###

use Mojo::UserAgent;
use Config::Simple;
use Template;

use List::Util qw/maxstr/;
use Data::Dump qw/dump dd/;
use Date::Parse;
use JSON;
use FindBin;
use lib "$FindBin::Bin/lib";
###

use BTCTicker
    qw/get_dbh large_num past_events nformat changelog epoch_to_parts commify/;


my $cfg = new Config::Simple("$FindBin::Bin/btctracker.ini");
my ( $url_base, $api_key ) = (
        'https://pro-api.coinmarketcap.com/v1/cryptocurrency/',
        $cfg->param('CoinMarketCap.api_key'));



# Request a resource and make sure there were no connection errors
my $ua = Mojo::UserAgent->new;
my $tx
    = $ua->get( $url_base
        . 'quotes/latest?id=1,1831,3602,825' =>
        { Accept => 'application/json', 'X-CMC_PRO_API_KEY' => $api_key } );
my $res = $tx->result;

# Decide what to do with its representation
my $info;
if ( $res->is_error ) {
    say $res->body;
    die;
}
elsif ( $res->is_success ) {
    $info = decode_json( $res->body );

    #    dd $info;
}
else {
    dump $res;
    die;
}

my %tickers = %{ $info->{data} };
my $dbh     = get_dbh();
my $sth
    = $dbh->prepare(
    "insert into ticker (cmc_id,circulating_supply,last_updated,price,volume_24h,market_cap,percent_change_1h,percent_change_24h,percent_change_7d,percent_change_30d,percent_change_60d,percent_change_90d) values (?,?,?,?, ?,?,?,?,?,?, ?,?)"
    );
my @timestamps;
my @rows;
my @table_data;
my $btc_price;
my $satoshis = 100_000_000;

for my $id ( sort { $tickers{$a}->{cmc_rank} <=> $tickers{$b}->{cmc_rank} }
    keys %tickers )
{
    my %quote_data = %{ $tickers{$id}->{quote}->{USD} };
    $btc_price = $quote_data{price} if $id == 1;
    my $circ_supply = $tickers{$id}->{circulating_supply};
    push @timestamps, $quote_data{last_updated};
    push @rows,
        sprintf(
        " %2d %12s %12f % 4.2f%% %12f  %7s %18f",
        $tickers{$id}->{cmc_rank},
        $tickers{$id}->{name},
        $quote_data{price},
        $quote_data{percent_change_24h},
        $quote_data{price} / ( 1 + $quote_data{percent_change_24h} / 100 ),
        large_num( $quote_data{volume_24h} ),
        $circ_supply
        );

    #say "==> $id ", $tickers{$id}->{name};

    my @percentages
        = map { 'percent_change_' . $_ } qw/1h 24h 7d 30d 60d 90d/;

    $sth->execute(
        $id,
        $circ_supply,
        map { $tickers{$id}->{quote}->{USD}->{$_} } (
            "last_updated", "price", "volume_24h", "market_cap",
            @percentages
        )
    );
    push @table_data,
        [
        $tickers{$id}->{cmc_rank},
        $tickers{$id}->{name},
        nformat( $quote_data{price} ),
        commify(
            sprintf( "%.0f", $quote_data{price} / $btc_price * $satoshis )
        ),
        large_num( $quote_data{volume_24h} / $quote_data{price} ),
        map { sprintf( "%.2f", $quote_data{$_} ) } @percentages,
        ];
}
# open( my $fh, '>>', "$FindBin::Bin/log" )
#     or warn "can't open $FindBin::Bin/log: $!";
# my $now = maxstr @timestamps;
# my $pad = ' ' x int( ( 80 - ( 2 * 4 ) - length($now) ) / 2 );

# say $fh $pad . "==> $now <==";
# for my $r (@rows) {
#     say $fh $r;
# }
# close $fh;

#my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($now);
#my $updated = join(' ',($ss,$mm,$hh,$day,$month,$year,$zone));
my %data = (
    meta    => { title => "Even slower BTC ticker", },
    content => {
        rows        => \@rows,
        btc_latest  => nformat($btc_price),
        updated     => epoch_to_parts( str2time($now) )->{std},
        table_data  => \@table_data,
        past_events => past_events($btc_price),
        changelog   => changelog(),
    },
);

my $tt = Template->new(
    { INCLUDE_PATH => "$FindBin::Bin/templates", ENCODING => 'UTF-8' } );

$tt->process(
    'index.tt', \%data,
    $cfg->param('HTML.index_page'),
    { binmode => ':utf8' }
) || die $tt->error;
