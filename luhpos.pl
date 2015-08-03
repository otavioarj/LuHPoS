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

use POSIX ":sys_wait_h";
$SIG{CHLD}= "IGNORE";
$SIG{PIPE} = "IGNORE";


my $port = 8080;
my $UA_MAX:shared =$ARGV[0]  ||  10;
my $MAX_Threads = $ARGV[1] || $UA_MAX;
my $Timeout=$ARGV[2] || 15;
$| = 1;


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
 my ($p_test,$pk,@threads,@param,$size);

 srand(time());
 
 $i = 0;
 @param=@_;
  #@threads= initThreads(); 
 for (0..$MAX_Threads) {push @threads, async 
  {
    while($i<$UA_MAX)
     {
	if(@read_ua!=0)
	 {
	  lock(@read_ua);
	  $pk=int(rand(@read_ua));	  	  
          $p_test=$read_ua[$pk];	  
	  $read_ua[$pk]=$read_ua[0];
	  shift(@read_ua);
	  $size=@read_ua;	  	  	
         }
	else 
         {
           print "[-] Only [". int($i+1) ."] good proxies found! Continuing anyway ...                \r";
	   lock($UA_MAX);
           $UA_MAX=$i+1;		
	   last;
         }
        if($param[1] )
         {
           $p_test=~ s/^\s+//;
           $p_test=~ s/\s+$//;
           if( $p_test!~ /http/ && $p_test!~ /socks/)
            {
              $p_test= "http://" . $p_test; 
            }    
           if(!&proxy_test($p_test))
            {   
              print "[". $i ."/$UA_MAX] Good Proxies . [-] $p_test rejected!             \r";
              $p_test=0;
              redo;
            }
           print "[". int($i+1) ."/$UA_MAX] Good Proxies\r"; 
          }
	 lock(@ua);push(@ua,$p_test); 
	 lock($i); $i++;     
   }
  };   
 }
 $_->join for @threads;
 #foreach(@threads){$_->join();}     	
 close(FILE);
 return @ua;
}

sub dproxy {
my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
my $d = HTTP::Daemon->new( 
	LocalHost => "localhost", 				   
	LocalPort => $port
) || die "[-] Can't bind on port $port! Erro: $!\n";
print "[*] Local proxy URL: ", $d->url ," \n";
my ($ex_proxy, $size,$response,@ua_l,@proxy_l,@pid, $s_in,$s_out);
@ua_l=@{$_[0]};
@proxy_l=@{$_[1]};
$s_in=0;$s_out=0;

while (my $c = $d->accept) 
{
	
	$ex_proxy=$proxy_l[int(rand($UA_MAX))];
	
        push(@pid, fork());
	$size=@pid;        
        if(!$size) {die "fork() failed: $!";}
#	$ex_proxy	
        if ($pid[$size -1]==0) 
	{
	     while (my $request = $c->get_request)
		{  
			$ua->proxy(['http', 'https','socks'], $ex_proxy);
			$ua->timeout($Timeout); 
			#print $c->sockhost . ": " . $request->uri->as_string . "\n"; User_Agen0t
			$request->remove_header("User-Agent");
			$request->push_header( User_Agent   => $ua_l[int(rand($UA_MAX))]);
			#$request->push_header( Via => "HTTP/1.1 GWA" );
			
			$response = $ua->simple_request( $request );
			while ($response->code == 408 || $response->code == 504 || $response->code == 500)
			 {
			   print "[!] Proxy $ex_proxy timeout!\r";
   			   $ua->proxy(['http', 'https','socks'], $proxy_l[int(rand($UA_MAX))]);			   
			   $ua->timeout($Timeout+5);
			   $response = $ua->simple_request( $request );
			 }
		#	$response->remove_header(qw( Set-Cookie Set-Cookie2 ));
			$s_out+=length($request->as_string("\n")); $s_in+=length($response->as_string("\r"));
			print "[*] In: $s_in bytes . Out: $s_out bytes.           \r";
			$c->send_response( $response );
		}
		exit(0);
	}
	srand(time()+$pid[$size -1]);
        while(!@pid){
	waitpid (pop(@pid), WNOHANG);}
		
	$c->close;
	undef($c);
        
	
}
$d->shutdown(2);
}

## Main :3

my (@ua,@proxy);

print "\n" .
'    __                  ___        __    
   / /  _   _   /\  /\ / _ \ ___  / _\   
  / /  | | | | / /_/ // /_)// _ \ \ \    
 / /___| |_| |/ __  // ___/| (_) |_\ \   
 \____/ \__,_|\/ /_/ \/     \___/ \__/ v.s 1.2' . "\n    At: www.github.com/otavioarj/luhpos\n\n";                                        
print "[*] LuHPoS - Luck's Http Proxy Obfuscator Soup\n";
@ua=&file_fetcher("ua.txt");
print "[+] User Agents loaded\n";
print "[*] Testing proxy list...\n";
@proxy=&file_fetcher("proxies.txt",1);
print "\n[+] Working Proxy loaded!\n";
&dproxy(\@ua,\@proxy);
