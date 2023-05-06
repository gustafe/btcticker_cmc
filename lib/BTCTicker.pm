package BTCTicker;
use Modern::Perl '2015';
use Exporter;
use Number::Format;
use Config::Simple;
use DateTime;
use DBI;

use open qw/ :std :encoding(utf8) /;
use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;

$VERSION = 1.00;
@ISA     = qw/Exporter/;
@EXPORT  = ();
@EXPORT_OK
    = qw/get_dbh large_num past_events nformat changelog epoch_to_parts commify/;

# %EXPORT_TAGS=(DEFAULT=>[qw/&get_dbh/]);

### DBH

my $cfg = Config::Simple->new('/home/gustaf/prj/NewBTCTicker/btcticker.ini');
my $driver   = $cfg->param('DB.driver');
my $database = $cfg->param('DB.database');
my $dbuser   = $cfg->param('DB.user');
my $dbpass   = $cfg->param('DB.password');

my $dsn = "DBI:$driver:dbname=$database";

sub get_dbh {

    my $dbh = DBI->connect( $dsn, $dbuser, $dbpass, { PrintError => 0 } )
        or croak $DBI::errstr;
    $dbh->{sqlite_unicode} = 1;
    return $dbh;
}

sub nformat {
    my ($in) = @_;

    my $nf = new Number::Format;
    return $nf->format_number( $in, 2, 2 );
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

sub large_num {    # return numbers in K, M, B based on size
    my ($x) = @_;
    my $negative = 1 if $x < 0;
    $x = -$x if $negative;
    return $negative ? -$x : $x if $x < 1_000;
    return sprintf( "%.02fk", $negative ? -$x / 1_000 : $x / 1_000 )
        if ( $x >= 1_000 and $x < 1_000_000 );
    return sprintf( "%.02fM", $negative ? -$x / 1_000_000 : $x / 1_000_000 )
        if ( $x >= 1_000_000 and $x < 1_000_000_000 );
    return sprintf( "%.02fB",
        $negative ? -$x / 1_000_000_000 : $x / 1_000_000_000 )
        if ( $x >= 1_000_000_000 );
}

sub past_events {
    my ($last) = @_;
    my $draper = {
        coins             => 29656.51306529,
        price_at_purchase => 600,
        purchase_value    => 600 * 29656.51306529,
        current_value     => $last * 29656.51306529,
        win_loss          => ( $last - 600 ) * 29656.51306529
    };
    my @draper      = map { $draper->{$_} } qw/coins price_at_purchase/;
    my @past_events = (

   # {
   #     header  => "Price of a 2017 Lamborghini LP 750-4 SV Roadster",
   #     content => [
   #         "The price of this car is USD&nbsp;535,500. The price in BTC is "
   #           . sprintf( "%.05f BTC.", 535500 / $last )
   # 	       ],
   #  anchor=>'lambo',
   # },
		       {header=>"Balaji Srinavasan's H Y P E R B I T C O I N I Z A T I O N bet",
			content=>[
  "On 17 Mar 2023 VC \@balajis made a public
  bet that the USD would hyperinflate within 90 days (15 Jun 2023) and
  one BTC would sell for 1M USD. The current difference between that target
  and the price now is ".
  sprintf("USD <span style=\"color:%s\">%s</span>.",
  $last-1_000_000<0?'red':'black',nformat($last-1_000_000)) ,
  sprintf("%s: %d.", DateTime->compare(DateTime->now(),DateTime->new(year=>2023,month=>6,day=>15)) <0  ?  "Days left until bet expires":"Days since bet expired" , DateTime->new(year=>2023,month=>6,day=>15)->delta_days(DateTime->now())->delta_days)
				 ],
		       anchor=>'balajis',},

        {   header  => "Tim Draper's coins from Silk Road",
            content => [
                sprintf(
                    "On 27 Jun 2014, investor Tim Draper paid approximately USD&nbsp;%.02f/coin for %s BTC seized from Silk Road. ",
                    $draper[1], $draper[0]
                ),
                sprintf( "Purchase price: USD&nbsp;%s",
                    large_num( $draper[0] * $draper[1] ) ),
                sprintf( "Price now: USD&nbsp;%s",
                    large_num( $draper[0] * $last ) ),
                sprintf( "Draper's win/loss: USD&nbsp;%s",
                    large_num( $draper[0] * ( $last - $draper[1] ) ) ),
            ],
            anchor => 'draper',
        },

        {   header  => "The Bitcoin pizza",
            content => [
                "On 22nd May 2010, Bitcoin enthusiast Laszlo Hanyec bought a pizza for 10,000 bitcoins. More specifically, he sent the coins to someone else who purchased the pizza for him.",
                sprintf(
                    "The Bitcoin pizza is currently worth USD&nbsp;%s (%s).",
                    nformat( 10_000 * $last ),
                    large_num( 10_000 * $last )
                ),
                "See the <a href='https://twitter.com/bitcoin_pizza'>\@bitcoin_pizza</a> Twitter account for up-to-date values!",
            ],
            anchor => 'pizza',
        },

        {   header  => "The white Mini Cooper",
            content => [
                sprintf(
                    "On 7 Jun 2014, Andreas M. Antonopoulos offered a white Mini Cooper for sale for 14 BTC. At the time, the VWAP was USD&nbsp;652.76, so the sales price (assuming it went through) was USD&nbsp;%s.",
                    nformat( 14 * 652.76 ) ),
                sprintf( "Today, the same car is worth USD&nbsp;%s.",
                    nformat( 14 * $last ) ),
                "(Source: <a href='https://twitter.com/aantonop/status/475048024453152768'>\@aantonop tweet</a>.)"
            ],
            anchor => 'mini',
        },
        {   header  => "2016 Bitfinex hack",
            content => [
                "On 2 Aug 2016, the exchange Bitfinex announced they had suffered a security breach and that 119,756 BTC were stolen.",
                sprintf(
                    "Current value of the stolen coins is USD&nbsp;%s (%s).",
                    nformat( 119_756 * $last ),
                    large_num( 119_756 * $last )
                )
            ],
            anchor => 'bitfinex',
        },

#         {
#             header  => "Price of a Leica Noctilux-M 75mm f/1.25 ASPH lens",
#             content => [
# "The price of this lens was USD&nbsp;12,795 at announcement. The price of this lens in BTC is "
#                   . sprintf( "%.05f BTC.", 12795 / $last )
# 		       ],
# 	 anchor=>'leica',
#         },
        {   header  => "Value of the drug-dealer's fishing rod cap",
            content => [
                "The convicted drug dealer Clifton Collins <a href='https://www.theguardian.com/world/2020/feb/21/irish-drug-dealer-clifton-collins-l46m-bitcoin-codes-hid-fishing-rod-case'>hid the codes to 6,000 BTC in a fishing rod cap that was thrown away when he was in jail</a>. The coins are now worth USD&nbsp;"
                    . sprintf( "%s (%s).",
                    nformat( 6_000 * $last ),
                    large_num( 6_000 * $last ) )
            ],
            anchor => 'fishing-rod',
        },
    );
    return \@past_events;
}

sub changelog {
    my @log;
    while (<DATA>) {
        chomp;
        push @log, $_;
    }
    return [ reverse @log ];
}
my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @wdays  = qw/Sun Mon Tue Wed Thu Fri Sat/;

sub epoch_to_parts {

    # EX format_utc
    # in: epoch seconds,
    # output: hashref with named fields
    # std: <weekday day mon year HH:MI:SS>
    # iso: YYYY-MM-DD HH:MM:SS
    # ymd: YYYY-MM-DD
    # hms: HH:MM:SS
    # jd: Julian TODO

    my ( $e, $flag ) = @_;

    my $out;

    #  0    1    2     3     4    5     6     7     8
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst )
        = gmtime($e);
    if ( $e > ( 1436044942 + 500 * 365 * 24 * 3600 ) ) {   # far in the future
        $out->{std} = sprintf( "In the year %d", $year + 1900 );
    }
    else {
        $out->{std} = sprintf(
            "%s %02d %s %04d %02d:%02d:%02d",
            $wdays[$wday], $mday, $months[$mon], $year + 1900,
            $hour, $min, $sec
        );
    }
    my $dt = DateTime->from_epoch( epoch => $e );
    $out->{iso} = sprintf(
        "%04d-%02d-%02d %02d:%02d:%02d",
        $year + 1900,
        $mon + 1, $mday, $hour, $min, $sec
    );
    $out->{ymd} = sprintf( "%04d-%02d-%02d", $year + 1900, $mon + 1, $mday );
    $out->{hms} = sprintf( "%02d:%02d:%02d", $hour,        $min,     $sec );
    $out->{jd}  = $dt->jd();
    return $out;
}

1;

__DATA__
2014-09-04: Initial release
2014-09-05: Added column "Price x Volume".
2014-09-07: added "3 days ago" row, renamed "All Time High" to "Record high".
2014-09-08: added "Red anniversary" section.
2014-09-12: minor date formatting changes.
2014-09-14: added data for exponential and linear extrapolation of historic trends, "About" page.
2014-09-16: added dates for linear trend since peak
2014-09-21: Added "Market Cap" field
2014-09-22: added a table showing how the volumes of different exchanges contribute to the price.
2014-11-17: added simple conversion between USD and "bits".
2014-11-23: rearranged info at top of page
2014-11-30: added 365 day rolling high and low
2014-12-10: added spread between 24h high and low
2015-03-30: improved calculation of number of bitcoins, and thereby aggregated value for different dates
2015-07-03: changed start date for linear extrapolation to 2015-01-14, converted display to table format
2015-07-04: had to reformat date display for dates more than 500 years in the future
2015-08-24: Added a section for the famous "Bitcoin pizza"
2015-08-26: Changed recent linear trend to last 90 days
2015-11-16: Added section on the white Mini Cooper
2016-06-16: Historical number of coins moved to DB instead of hardcoded values in script
2016-08-03: Added information about the Aug 2016 Bitfinex hack
2017-06-08: Shut down of first version service
2017-06-14: <b>New API interface in development</b>
2017-06-22: Official relaunch using new API and some new features, such as coin market cap data.
2021-05-16: The tracker is on hiatus while a new source of data is found.
2021-05-22: Tracker relaunched with data from CoinMarketCap.
2023-03-21: added a little section about an unhinged VC bet
2023-04-03: added Eth and Doge
