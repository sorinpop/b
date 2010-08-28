#!/usr/bin/perl


use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Cookies;
use Data::Dumper;

my $DEBUG = 0;

my $ua = LWP::UserAgent->new(timeout => 10);
$ua->cookie_jar( HTTP::Cookies->new( file => "/tmp/cookies.txt" ) );
my $response;

#welcome page

$response = $ua->get('http://webhelpdesk.mdx.ac.uk/helpdesk/WebObjects/Helpdesk');
die "Can't reach login page" . $response->content() unless $response->is_success();


$response->content() =~ m#<form[^>]*action="(/helpdesk/WebObjects/Helpdesk.woa/wo/[^\"]+)"[^>]*>#;

#Login

my $action = $1;
_debug("Login action : $action");
    
my @path = split(/\//,$action);
    
pop @path;
my $magick_code = pop @path; 
    
_debug("Magick code :  $magick_code");

$response = $ua->post( 'http://webhelpdesk.mdx.ac.uk' . $action,
            {
                '11.1.5.11.11.1' => '11.1.5.11.11.1',
                '11.1.5.11.13.0.0' => 'DUMMY',
                'MDSForm__AltKeyPressed' => 0,
                'MDSForm__EnterKeyPressed' => 0,
                'MDSForm__ShiftKeyPressed' => 0,
                'MDSSubmitLink11.1.5.11.16.1.0.0' => 'DUMMY',
                'MDSSubmitLink11.1.5.11.18.0.1.0.0' => 'DUMMY',
                'password' => 'iphone',
                'userName' => 'gary@boopsie.com',
            } );
die "Login process returned an error !" unless $response->is_success();

#go to FAQ

$response->content() =~ m#<a[^>]*href="([^"]+)"[^>]*><div class="buttonLabel">FAQs</div></a>#;
my $faq_link = $1;

die "Cannot find FAQ link".$response->content() unless $faq_link;

_debug("FAQ Link : $faq_link");

$response = $ua->get( 'http://webhelpdesk.mdx.ac.uk' . $faq_link);

#get cathegories and browse

my %data = ($response->content() =~ m#<option value="(\d+)">([^<]+)</option>#gs );

_debug("Found sections : " . Dumper(\%data));

$response->content() =~ /(<select .*?<\/select>)/gs;

_debug("$1");

my ($parent,$child);

if ($response->content() =~ /(ParentPopup\d+)/) {
	$parent = $1;
}

if ($response->content() =~ /(ChildPopup\d+)/) {
	$child = $1;
}

#print $response->content() . "\n\n$parent\n$child\n\n";
#<>;

my $count = 2;
my $time = 1281649969910;
foreach (sort keys %data) {

    _debug("Parsing $data{$_}...");

#URL=http://webhelpdesk.mdx.ac.uk:8081/helpdesk/WebObjects/Helpdesk.woa/ajax/PVgkvm12DNYHSkXhh4fGLg/3.17.4.3?__updateID=ProblemTypeSelectorDiv&1281649969910

    my $post;
    
    if (! defined $parent) {
	$post = {
	    $child => $_,
	    '17.1.3.1.7' => '',
	    '17.1.3.1.19' => '',
	    'AJAX_SUBMIT_BUTTON_NAME' => '17.1.3.1.3.1',
	};
    }else {
	$post = {
	    $parent => $_,
	    $child => "WONoSelectionString",
	    '17.1.3.1.7' => '',
	    '17.1.3.1.19' => '',
	    'AJAX_SUBMIT_BUTTON_NAME' => '17.1.3.1.3.1',
	};
    }

    $response = $ua->post( "http://webhelpdesk.mdx.ac.uk/helpdesk/WebObjects/Helpdesk.woa/ajax/$magick_code/$count.17.1.3?__updateID=ProblemTypeSelectorDiv&".$time,
            	$post
            );

	$time += rand(100);
    
    die "Cannot get page !" unless $response->is_success();
    
    if ($response->content() =~ /(ParentPopup\d+)/) {
    	$parent = $1;
	}
    if ($response->content() =~ /(ChildPopup\d+)/) {
    	$child = $1;
	}
    
    #print $response->content();
    
    #<>;
    
    $response = $ua->get("http://webhelpdesk.mdx.ac.uk/helpdesk/WebObjects/Helpdesk.woa/ajax/$magick_code/$count.17.1.5?__updateID=SearchContentDiv&".$time);

  	$time += rand(100);

    #print $response->content();
    
    #<>;
    
    die "Cannot get results page!" unless $response->is_success();
    
    _debug("Done");
    
    #print $response->content();

	$count +=2;
	
	die "no answers header" if ($response->content() !~ /Question \| Answer/);
	
	
	my @list = $response->content() =~ /<table cellspacing="0" cellpadding="0" border="0">\s+<tr>\s+<td>\s+<\/td>\s+<td valign="top">\s+<\/td>\s+<td>([^<]+)<\/td>\s+<\/tr>\s+<\/table>/gs;
	my @urls = $response->content() =~ /class="FaqUpdateContainer" updateUrl="([^\"]+)">/gs;
	my @questions = $response->content() =~ /<div class="FaqQuestionStyle">\s+(.*?)\s+<\/div>/gs;
	my @answers;
	my @sublist;
	
	my $content = $response->content();
	
	foreach my $item (@list) {
		if ( $content =~ /<td>$item<\/td>\s+<\/tr>\s+<\/table>\s+<\/td>\s+<\/tr>\s+<tr>\s+<td>\s+<table cellspacing="0" cellpadding="0" border="0">\s+<tr>\s+<td>\s+&nbsp;&nbsp;\s+<\/td>\s+<td valign="top">\s+&#8226;&nbsp;\s+<\/td>\s+<td>([^<]+)<\/td>/s ) {
			push @sublist,$1;
			$content =~ s/<td>$item<\/td>\s+<\/tr>\s+<\/table>\s+<\/td>\s+<\/tr>\s+<tr>\s+<td>\s+<table cellspacing="0" cellpadding="0" border="0">\s+<tr>\s+<td>\s+&nbsp;&nbsp;\s+<\/td>\s+<td valign="top">\s+&#8226;&nbsp;\s+<\/td>\s+<td>$1<\/td>//s;
		}else{
			push @sublist,"";
		}
	}
	
	
	foreach my $url (@urls) {
		$response = $ua->get("http://webhelpdesk.mdx.ac.uk".$url.".1?__updateID=div_47&".$time);
		#print "\n\n\n!!!!!!!!!!!!!\n\n" . $response->content() . "\n\n\n!!!!!!!!!!!!!\n\n";
		$time += rand(100);
		
		if ($response->content() =~ /<div class="FaqAnswerStyle">\s+(.*?)\s+<\/div>/s) {
			my $x = $1;
			$x =~ s/[\n\r]//g;
			push @answers,$x;
		}else {
			push @answers,"";
		}
		
	}
	open( my $fh, '>>', 'output' );
	for (my $j=0; $j <= $#questions; $j++) {
	    print $fh join("\t", $list[$j], $sublist[$j], $urls[$j], $questions[$j], $answers[$j])."\n";
	}
	close($fh);
	
	$count += scalar(@urls);

}

sub _debug { print "@_\n" if $DEBUG; }

=h1

URL=http://webhelpdesk.mdx.ac.uk:8081/helpdesk/WebObjects/Helpdesk.woa/ajax/flYYo3yGCR62BkXRv8mjJg/4.17.3.3?__updateID=ProblemTypeSelectorDiv&1281099186605
ParentPopup62394140=0
ChildPopup6239414=WONoSelectionString
17.3.3.1.7=
17.3.3.1.19=
AJAX_SUBMIT_BUTTON_NAME=17.3.3.1.3.1


URL=http://webhelpdesk.mdx.ac.uk:8081/helpdesk/WebObjects/Helpdesk.woa/ajax/flYYo3yGCR62BkXRv8mjJg/4.17.3.3?__updateID=ProblemTypeSelectorDiv&1281098653429
ParentPopup62394140=1
ChildPopup6239414=WONoSelectionString
17.3.3.1.7=
17.3.3.1.19=
AJAX_SUBMIT_BUTTON_NAME=17.3.3.1.3.1


URL=http://webhelpdesk.mdx.ac.uk:8081/helpdesk/WebObjects/Helpdesk.woa/ajax/flYYo3yGCR62BkXRv8mjJg/4.17.3.3?__updateID=ProblemTypeSelectorDiv&1281099364237
ParentPopup62394140=14
ChildPopup6239414=WONoSelectionString
17.3.3.1.7=
17.3.3.1.19=
AJAX_SUBMIT_BUTTON_NAME=17.3.3.1.3.1



URL=http://webhelpdesk.mdx.ac.uk:8081/helpdesk/WebObjects/Helpdesk.woa/ajax/flYYo3yGCR62BkXRv8mjJg/4.17.3.5?__updateID=SearchContentDiv&1281098653927
URL=http://webhelpdesk.mdx.ac.uk:8081/helpdesk/WebObjects/Helpdesk.woa/ajax/flYYo3yGCR62BkXRv8mjJg/4.17.3.5?__updateID=SearchContentDiv&1281099187323
URL=http://webhelpdesk.mdx.ac.uk:8081/helpdesk/WebObjects/Helpdesk.woa/ajax/flYYo3yGCR62BkXRv8mjJg/4.17.3.5?__updateID=SearchContentDiv&1281099364721


<div  id="div_39" class="FaqUpdateContainer" updateUrl="/helpdesk/WebObjects/Helpdesk.woa/ajax/flYYo3yGCR62BkXRv8mjJg/36.17.3.5.1.5.0.3.7">


<select name="ParentPopup62394140" id="ProblemType_157988728708458" style="margin-bottom: 10px; display: inline-block; float: left;">
<option value="0">Accomodation</option>
<option value="1">Athens</option>
<option value="2">CCSS</option>
<option value="3">DLSU</option>
<option value="4">Final Year Student Queries</option>
<option value="5">Inter Library Loans</option>
<option value="6">International Student Support</option>
<option value="7">Library catalogue</option>
<option value="8">Mdx Live Email</option>
<option value="9">Misc</option>
<option value="10">MISIS</option>
<option value="11">Network</option>
<option value="12">New Student Queries</option>
<option value="13">Oasisplus</option>
<option value="14" selected="">Passwords</option></select>

=cut

