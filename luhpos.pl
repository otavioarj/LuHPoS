#!/usr/bin/perl -w
# This file is part of LuHPoS project. This software may be used and distributed
# according to the terms of the GNU General Public License version 2, incorporated herein by reference, at repository: https://github.com/otavioarj/LuHPoS
# =] 

use strict;
use warnings;
#use HTTP::Daemon;
use IO::Socket::Socks qw(:constants $SOCKS_ERROR);
use LWP::Protocol::socks;
#use HTTP::Daemon::SSL;
use LWP::UserAgent;
use threads;
use threads::shared;
use Getopt::Std;
use LWP::Debug qw(+);
use HTTP::Request;
#@HTTP::Daemon::ISA = qw/ IO::Socket::SSL /;
#@HTTP::Daemon::ClientConn::ISA = qw/ IO::Socket::SSL /;


$| = 1;

$SIG{PIPE} = "IGNORE";

my %options=();
getopts("l:d:x:p:m:t:o:r:has", \%options);
my (@ua,@proxy);
my $port = $options{p} || 8080;
my $UA_MAX = $options{m}  ||  10;
my $P_MAX:shared = $options{m}  ||  10;
my $MAX_Threads = $options{t} || $P_MAX*3;
my $Timeout=$options{o} || 10;
my $target=$options{x} || "https://duckduckgo.com";
my $delay=$options{d} || 0;
my $retry=$options{r} || 2;
my $plist=$options{l} || "proxies.txt";


sub proxy_test
{
 my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
 $ua->timeout($Timeout);
 $ua->agent("Mozilla/5.0 (Linux) Gecko Iceweasel (Debian) Mnenhy");
 $ua->proxy(['http', 'https','socks'], $_[0]);
 
 my $response;
 my ($a,$i);
 $a=0;
 for($i=0;$i<$retry;$i++)
 {
   $response = $ua->get($target);
   $a++ if ($response->is_success);
   sleep($delay) if defined $options{d};
     
 }
   if($a>=($retry-1))
     { return 1; }
    else { return 0; } 
}

sub file_fetcher
{
 open FILE, $_[0] or die "[-] Can't load  $_[0] . Error: $!\n";
 my @read_ua:shared =<FILE>;
 chomp(@read_ua);
 
 my (@ua,$i):shared;
 my ($p_test,$pk,@threads,@param,$tam,$max);
 srand(time());
  
 $i = 0;
 $tam=@read_ua;
 $max= $MAX_Threads;
 $max = $tam if($MAX_Threads > $tam); 
 
 if($_[1])
 {
 for (1..$max) {push (@threads, threads->create(sub  
  {
    while($i<$P_MAX)
     {
    print "[*] Proxies: Good[". int($i) ."/$P_MAX]. Bad[". int($tam-@read_ua) ."].          \r";
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
           print "[-] Only [". $i ."] good proxies found! Continuing anyway ..\n";
	   lock($P_MAX);
           $P_MAX=$i;		
	   last;
         }
        $p_test=~ s/^\s+//;
        $p_test=~ s/\s+$//;
        if( $p_test!~ /http/ && $p_test!~ /socks/ && $p_test!~  /connect/)
         {
           $p_test= "http://" . $p_test; 
         }    
        if(!&proxy_test($p_test))
         {   
           #print "[". $i ."/$P_MAX] Good Proxies . [-] $p_test rejected!             \r";
	   lock($i);
           if($i<$P_MAX) {redo;}
	   else {last;}
         }	        	         
        lock(@ua);push(@ua,$p_test);
	lock($i);
	if($i>=$P_MAX) {last;} 
	$i++;
    print "    \--> Proxies: Good[". int($i) ."/$P_MAX]. Bad[". int($tam-@read_ua) ."].       \r";  
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
   my $server =  $_[2];   
   my ( $size,$response,@ua_l,@pid, $rnd,$ex_p,$ex_t);
   my ($s_in,$s_out,@proxy_l,$temp,@t_out):shared;
   @ua_l=@{$_[0]};  
   @proxy_l=@{$_[1]};
   @t_out=($Timeout)x scalar(@proxy_l); 
   $s_in=0;$s_out=0;$rnd=0;
   srand(time()); 
   while (1)
   { 
     my $c = $server->accept();
     unless($c){ warn "[-] Failed to accept: $! - $? ";next;} 
     threads->create(sub
      {	
 	   print "[!] No proxy! All proxies timedout!!!\r" if(@proxy_l<1);
	  {
        lock(@proxy_l);
	    lock(@t_out);
	    $rnd=int(rand($P_MAX));
	    $ex_t=$t_out[$rnd];
	    $ex_p=$proxy_l[$rnd];
      }    
    my ($cmd, $host, $port2) = @{$c->command()};
    # Well, right now the connection can be made... we don't know already with kind of connection this is (http or socks-only)
    if($cmd == CMD_CONNECT){ $c->command_reply(REPLY_SUCCESS, "localhost", $port); }
    else { $c->command_reply(REPLY_GENERAL_FAILURE, $host, $port); }
 
	while ($c->sysread(my $data, 1024))
	 {
       if($data =~ /HTTP\//)
       {	
	   $ua->proxy(['http', 'https','socks'], $ex_p);
	   $ua->timeout($ex_t);
       my $request = HTTP::Request->parse( $data );
	   $request->remove_header("User-Agent");
	   $request->push_header( User_Agent   => $ua_l[int(rand($UA_MAX))]);
	   $request->push_header( Via => "HTTP/1.1 GWA" ) if not defined $options{a};
	   $request->remove_header(qw( From Referer Cookie Cookie2 )) if defined $options{a};
       $request->uri("http://" . $request->header("Host")); 
       #print $request->as_string;
	   $response = $ua->simple_request( $request );
	   while ($response->code == 408 || $response->code == 504 || $response->code == 500 && @proxy_l>1)
	    {
	      print "[!] Proxy $ex_p timeout!            \n";
	      if($ex_t > 2*$Timeout)
           { 
	         lock(@proxy_l);
		     lock(@t_out);
             $temp=$proxy_l[0];
     		 $proxy_l[0]=$proxy_l[$rnd];
	    	 $proxy_l[$rnd]=$temp;
		     $temp=$t_out[0];
     		 $t_out[0]=$t_out[$rnd];
	     	 $t_out[$rnd]=$temp;
		     shift(@t_out);
    		 shift(@proxy_l);
	    	 $P_MAX--;
          }
 	      else {lock(@t_out); $t_out[$rnd]+=5;}
	      {
		   lock(@proxy_l);
		   lock(@t_out);
	        $rnd=int(rand($P_MAX));
	        $ex_p=$proxy_l[$rnd];
	        $ex_t=$t_out[$rnd];
	      }
	      $ua->proxy(['http', 'https','socks'], $ex_p);
	      $ua->timeout( $ex_t);
	      $response = $ua->simple_request( $request );
	    }
	   $response->remove_header(qw( Set-Cookie Set-Cookie2 )) if defined $options{a};
      if(defined($options{s}))      
	  {
	   lock($s_out); lock($s_in);
	   $s_out+=length($request->as_string("\n")); $s_in+=length($response->as_string("\r"));
	   print "[*] In: $s_in bytes . Out: $s_out bytes.           \r";
	  } 
     print $response->as_string; 
     $c->syswrite($response->as_string);    
    }
    elsif($ex_p !~ /socks/)
    {
       my $sock = IO::Socket::INET->new(PeerHost => $host, PeerPort => $port2, Timeout => 10);
       if($cmd == CMD_CONNECT){ $c->command_reply(REPLY_SUCCESS, $sock->sockhost, $sock->sockport); }
       else { $c->command_reply(REPLY_GENERAL_FAILURE, $host, $port2); }
        
       if($sock) {print "Data: $data /|\\ \n";$sock->syswrite($data);} else {print "Oooops\n";$sock->close();}
       my $readed = $sock->sysread($data, 1024);
       
       if($readed){print "Data2: $data /|\\ \n";$c->syswrite($data)} else {print "Ooops2\n";$sock->close();}  
            
    }
    
}
	$c->close();
     
       })->detach; 
      sleep($delay) if defined $options{d};	        
   }
}


## Main :3



print "\n" .
'    __                  ___        __    
   / /  _   _   /\  /\ / _ \ ___  / _\   
  / /  | | | | / /_/ // /_)// _ \ \ \    
 / /___| |_| |/ __  // ___/| (_) |_\ \   
 \____/ \__,_|\/ /_/ \/     \___/ \__/ v.s 3.0-alpha (aka coruja-poliglota)' . "\n    At: www.github.com/otavioarj/luhpos\n\n";                                        
print "[*] LuHPoS - Luck's Http Proxy Obfuscator Soup\n";

if(defined $options{h})
{
 print "-p(ort)    : Port to bind.[default 8080]\n-m(ax)     : Max number of entries for User Agent and Proxies.[default 10]\n-t(hreads) : Max number of threads to run at proxy testing. [default 3*m(ax)]\n-o(timeout): Timeout for proxies, in seconds. [default 10]\n-a(non)    : Anonymiser both HTTP request and response(removes Cookies, Refer, From, Via..).[default not anon]\n-d(elay)   : Delay between each connection to proxies\n-x(target) : Target site to test connection trougth proxies\n-l(list)   : File with proxy list[default proxies.txt]\n-s(tatics) : Bytes I/O trought proxy.\n-r(etries)   : Conn. retries to test proxy[default 2].\n";
 exit(0);
}
if(not %options ) {print "[*] Using default options, try -h for help\n";}
@ua=&file_fetcher("ua.txt");
print "[+] User Agents loaded\n";
print "[*] Testing proxy list...\n";
@proxy=&file_fetcher($plist,1);
die "[-] No good proxy found!\n" if(scalar(@proxy)<1);
print "\n[+] Working Proxy loaded!\n";

my $server = IO::Socket::Socks->new(SocksVersion => 5,
                                     ProxyAddr => 'localhost',
                                     ProxyPort =>  $port,
                                     SocksDebug => 0, #1 for debug :)
                                     Listen => 10) or die "[-] Can't bind on port $port! Error: $SOCKS_ERROR\n";  
print "[*] Proxy on port: ", $port ," \n";

#my $https= HTTP::Daemon::SSL->new( 
#	LocalHost => "localhost", 				   
#	LocalPort => $port+1,
#	SSL_cert_file => 'cert.pem',
#       SSL_key_file => 'key.pem',	
#	ReuseAddr => 1 ) || die "[-] Can't bind on port $port! Error: $!\n";

#if (!fork()){&dproxy(\@ua,\@proxy,$http);}
#else { &dproxy(\@ua,\@proxy,$https);}
&dproxy(\@ua,\@proxy,$server);








