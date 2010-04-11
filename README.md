Google Wave WFE protocol client implementation
==============================================

Version 0.1 alpha 0

The utility set implements current client part of Google Wave communication-over-http undocumented protocol (WFE).
Useful for developers looking for implementation of Google Wave desktop utilities such as notifiers.

Could be used as a hack tool to explore and experiment with the undocumented Google Wave's WFE protocol.
Ruby knowledge is highly recommended for anyone trying to make use of this code.

Based on
--------

- documentation by P. van Ginkel on http://sourceforge.net/projects/wave-protocol/
- reverse engineering with [Firebug](http://getfirebug.com "A firefox extension")
  and  [Burp proxy](http://portswigger.net/proxy/) software
- Google BrowserChannel [source code](http://closure-library.googlecode.com/svn/docs/closure_goog_net_browserchannel.js.source.html)
  from the Closure javascript library

What it does
------------

- logs into google wave account using google client login procedure
- gets the account main page and saves to a file
- parses the main page and saves information in yaml format
- establishes a **BrowserChannel** and wfe link with the Google Wave server
- allows the user to prepare and send wfe requests and receive wfe responses


Requirements
------------

- ruby 1.8.7 (will not run "as is" in 1.8.6 nor 1.9)
- gems (of course)
- highline ruby library 1.5.2
- httpclient 2.1.5.2 
- json   1.2.4

I did not test the scripts on Windows yet. Ubuntu linux 9.04 or later is recommended.

How to use
----------

1. Log into google wave account
           $ ./login.rb
   Specify  username (without _@googlewave.com_ ) and password for google wave account. On success
   utility responds with
           302 Moved Temporarily
           ["https://wave.google.com/wave/?nouacheck"]

2. Get the page with
          $ ./getwave.rb
   Page is saved to _wavepage.html_ file.

3. Parse the page with
          $ ./parsewavepage.rb

4. Start wfe requests templates edit utility
          $ ./wfereqsbuilder.rb
   Modify and write wfe request templates interactively to _wfereqs_ file. This is a rather primitive
   menu-based json objects editor. You may write another utility, if you like,
   or even use _echo [request text] >> wfereqs_ instead.

5. Start wave protocol communication utility simultaneously in another console window

         $ ./talktowave.rb

   This utility periodically polls _wfereqs_ file, reading new templates when they are ready, substitutes expressions
   and sends resulting wfe requests to the server, while listening to wfe responses.
   Press **Ctrl-C** when you are bored :-)


Predefined macros in wfe request templates
------------------------------------------

talktowave.rb uses ruby double-quoted strings expression substitution syntax for _macro_ expansion in the templates
read from _wfereqs_ file. That is **#{** _expression_ **}**. Typical expression is just a variable/method/constant name.
E.g. **#{sessionid}** .

_Documented_ macros are:

- **nqid** - autoincremented query identifier for 2602 _subscribe to query_ request
- **PQID** - query identifier for the predefined "r":"^d1" request
- **qid**  - currently active query identifier.
- **r**    - request message number  ("r" parameter  value)
- **rndstr**  - generate random string with length 8
- **sessionid**  - wfe session id  ("a" parameter value)
- **un**      - full user id ( _username_ ) of the current user with @googlewave.com suffix

For more details see source code of  **Wfe::RequestTemplateInterface** .


Options for the scripts
-----------------------------------

-d : **login.rb** , **getwave.rb** and **talktowave.rb**  take **-d** option to display HTTP traffic on stderr.
-w : **talktowave.rb**  **-w** option makes the utility dump the information when the resource leak is detected on stderr.


Problems and ways to improve the toolset
----------------------------------------

**wfereqsbuilder.rb** is an awful piece of hacking. Interface is inconsistent, I often mistype selections myself.
The only good thing, it is supposed to be platform-independent.

**talktowave.rb** makes use of jcode for UTF-8 manipulation and therefore is not compatible with ruby 1.9. This could be fixed.

Also, talktowave suffers from resource leak, which I believe is due to bug in  _httpclient_  2.1.5.2 gem.
Use **-w** option to observe the leak. Because of the leak, the time to run the script is rather limited.
One hour is ok, though.

**Ctrl-C** signal handler and **BrowserChannel** shutdown code would be nice improvements for  **talktowave.rb** code.


Acknowledgements
----------------

 James Edward Gray II wrote an original [json parser code](http://rubyquiz.com/quiz155.html "Parsing JSON") on the
 ruby quiz site,  which was easy to adapt for this project.

 Pieter van Ginkel  wrote the first documentation of the google wave client protocol on the web. My
 communication with Pieter had prodded me to explore the WFE protocol further and write these scripts as the result.


Contact me
----------

Yuri Baranov,

- G-Wave: baranovu@googlewave.com
- E-Mail: baranovu+gh@gmail.com
- Blog:   blog.urbylog.info


Happy Hacking !
===============