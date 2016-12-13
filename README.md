# LuHPoS
```    
    __                  ___        __    
   / /  _   _   /\  /\ / _ \ ___  / _\   
  / /  | | | | / /_/ // /_)// _ \ \ \    
 / /___| |_| |/ __  // ___/| (_) |_\ \   
 \____/ \__,_|\/ /_/ \/     \___/ \__/ 

 
LuHPoS - Luck's Http Proxy Obfuscator Soup v3.0-alpha

One local proxy to multi-chaining-proxies, with local Sock5 proxy-server and remote-client proxies 
supporting:
  => HTTP through HTTPS 
  => HTTP/S through Sock4/5 proxies
  => HTTPS->connect with HTTPS clients/proxies

 Help?
 
./luhpos.pl -h

    __                  ___        __    
   / /  _   _   /\  /\ / _ \ ___  / _\   
  / /  | | | | / /_/ // /_)// _ \ \ \    
 / /___| |_| |/ __  // ___/| (_) |_\ \   
 \____/ \__,_|\/ /_/ \/     \___/ \__/ v.s 3.0-alpha
    At: www.github.com/otavioarj/luhpos

[*] LuHPoS - Luck's Http Proxy Obfuscator Soup
-p(ort)    : Port to bind.[default 8080]
-m(ax)     : Max number of entries for User Agent and Proxies.[default 10]
-t(hreads) : Max number of threads to run at proxy testing. [default 3*m(ax)]
-o(timeout): Timeout for proxies, in seconds. [default 10]
-a(non)    : Anonymiser both HTTP request and response(removes Cookies, Refer, From, Via..)[default not anon]
-d(elay)   : Delay between each connection to proxies
-x(target) : Target site to test connection trougth proxies
-l(list)   : File with proxy list[default proxies.txt]
-s(tatics) : Bytes I/O trought proxy.
-r(etries)   : Conn. retries to test proxy[default 2].
 ```
