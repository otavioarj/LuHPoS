#!/usr/bin/perl -w
# This file is part of LuHPoS project. This software may be used and distributed
# according to the terms of the GNU General Public License version 2, incorporated herein by reference, at repository: https://github.com/otavioarj/LuHPoS
# =] 

use strict;
use warnings;
use HTTP::Daemon;
use LWP::UserAgent;
use threads;
use threads::shared;
use Getopt::Std;
$| = 1;

$SIG{PIPE} = "IGNORE";

my %options=();
getopts("p:m:t:o:h", \%options);
my (@ua,@proxy);
my $port = $options{p} || 8080;
my $UA_MAX = $options{m}  ||  10;
my $P_MAX:shared = $options{m}  ||  10;
my $MAX_Threads = $options{t} || $P_MAX*2;
my $Timeout=$options{o} || 10;


sub proxy_test
{
 my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
 $ua->timeout($Timeout);
 $ua->agent("Mozilla/5.0 (Linux) Gecko Iceweasel (Debian) Mnenhy");
 $ua->proxy(['http', 'https','socks'], $_[0]);
 my $response = $ua->get("http://duckduckgo.com");
 if ($response->is_success || $response->status_line =~ /403/)
  { return 1; }
 else { return 0; }
 
}

sub file_fetcher
{
 open FILE, $_[0] or die "[-] Can't load  $_[0] . Error: $!\n";
 my @read_ua:shared =<FILE>;
 chomp(@read_ua);
 
 my (@ua,$i):shared;
 my ($p_test,$pk,@threads,@param);
 srand(time());
 
 $i = 0;
 if($_[1])
 {
 for (0..$MAX_Threads) {push (@threads, threads->create(sub  
  {
    while($i<$P_MAX)
     {
	if(@read_ua!=0)
	 {
	  lock(@read_ua);
	  $pk=int(rand(@read_ua));	  	  
          $p_test=$read_ua[$pk];	  
	  $read_ua[$pk]=$read_ua[0];
	  shift(@read_ua);	  	  	  	
         }
	else 
         {
           print "[-] Only [". $i ."] good proxies found! Continuing anyway ...                \r";
	   lock($P_MAX);
           $P_MAX=$i;		
	   last;
         }
        $p_test=~ s/^\s+//;
        $p_test=~ s/\s+$//;
        if( $p_test!~ /http/ && $p_test!~ /socks/)
         {
           $p_test= "http://" . $p_test; 
         }    
        if(!&proxy_test($p_test))
         {   
           print "[". $i ."/$P_MAX] Good Proxies . [-] $p_test rejected!             \r";
	   lock($i);
           if($i<$P_MAX) {redo;}
	   else {last;}
         }
	lock($i);
        if($i>=$P_MAX) {last;}	         
        lock(@ua);push(@ua,$p_test); 
	$i++;   
	print "[". int($i) ."/$P_MAX] Good Proxies\r";  
      }
   }));   
 }
 foreach(@threads) {$_->join();}
 }
 else
  { 
    while($i!=$UA_MAX)
     {
      $pk=int(rand(@read_ua));	  	  
      $p_test=$read_ua[$pk];	  
      $read_ua[$pk]=$read_ua[0];
      shift(@read_ua);	
      push(@ua,$p_test); 
      $i++ 
     }
   }
 close(FILE);
 return @ua;
}

sub dproxy 
 {
   my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
   my $d = HTTP::Daemon->new( 
	LocalHost => "localhost", 				   
	LocalPort => $port
     ) || die "[-] Can't bind on port $port! Erro: $!\n";
   print "[*] Local proxy URL: ", $d->url ," \n";
   my ($ex_proxy, $size,$response,@ua_l,@proxy_l,@pid );
   my ($s_in,$s_out):shared;
   @ua_l=@{$_[0]};
   @proxy_l=@{$_[1]};
   $s_in=0;$s_out=0;
   srand(time()); 
   while (my $c = $d->accept) 
   { 
     threads->create(sub
      {	
	$ex_proxy=$proxy_l[int(rand($P_MAX))];
	while (my $request = $c->get_request)
	 {  
	   $ua->proxy(['http', 'https','socks'], $ex_proxy);
	   $ua->timeout($Timeout); 
	   $request->remove_header("User-Agent");
	   $request->push_header( User_Agent   => $ua_l[int(rand($UA_MAX))]);
	   $request->push_header( Via => "HTTP/1.1 GWA" );
	   $response = $ua->simple_request( $request );
	   while ($response->code == 408 || $response->code == 504 || $response->code == 500)
	    {
	      print "[!] Proxy $ex_proxy timeout!            \r";
   	      $ua->proxy(['http', 'https','socks'], $proxy_l[int(rand($P_MAX))]);			   
	      $ua->timeout($Timeout+5);
	      $response = $ua->simple_request( $request );
	    }
	   #$response->remove_header(qw( Set-Cookie Set-Cookie2 ));
	   #lock($s_out); lock($s_in);
	   #$s_out+=length($request->as_string("\n")); $s_in+=length($response->as_string("\r"));
	   #print "[*] In: $s_in bytes . Out: $s_out bytes.           \r";
	   $c->send_response( $response );
	 }
	$c->close;
	threads->exit(0); 
       })->detach;         
   }
 $d->shutdown(2);
 }

## Main :3



print "\n" .
'    __                  ___        __    
   / /  _   _   /\  /\ / _ \ ___  / _\   
  / /  | | | | / /_/ // /_)// _ \ \ \    
 / /___| |_| |/ __  // ___/| (_) |_\ \   
 \____/ \__,_|\/ /_/ \/     \___/ \__/ v.s 1.8' . "\n    At: www.github.com/otavioarj/luhpos\n\n";                                        
print "[*] LuHPoS - Luck's Http Proxy Obfuscator Soup\n";

if(defined $options{h})
{
 print "-p(ort)    : Port number to bind.[default 8080]\n-m(ax)     : Max number of entries for User Agent and Proxies.[default 10]\n-t(hreads) : Max number of threads to run at proxy testing. [default 2*m(ax)]\n-o(timeout): Timeout for proxies, in seconds. [default 10]\n";
 exit(0);
}
else {print "[*] Using default options, try -h for help\n";}
@ua=&file_fetcher("ua.txt");
print "[+] User Agents loaded\n";
print "[*] Testing proxy list...\n";
@proxy=&file_fetcher("proxies.txt",1);
print "\n[+] Working Proxy loaded!\n";
&dproxy(\@ua,\@proxy);
