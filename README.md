# SQL Server Monitor

This is a super old SQL Server monitor tool I wrote back around 2007 to monitor SQL Server 2008+.  You run it as a site and it will show you all the running SPIDs, what SQL they're executing, and how long they've been running.  It's great to keep tabs on processes that may come from soures other than your web app.  What it's really good at is showing when one SPID is blocking other SPIDs as it nests the output on the page so you can easily visualize who is blocking who.  Also, the "show locks" option will reveal every lock each process has obtained or is waiting on which will tell you eactly why one SPID may be blocking another.  The execution plan link will download an XML file that SSMS will open to show the execution plan of the currently executing query.

## Usage

* Start up a server in this folder as the web root
* Add a datasource for a Sql Server with ADMIN rights 
* Edit the dropdown around line 200 of `index.cfm` to set the name of your DSN to the options
* Hit the site and you can see all the running processes on the DB server
* All the SeeFusion stuff is super old and doesn't do anything if you don't use SeeFusion
* The logged in user stuff all depends on SeeFusion, so it's probably worthless to you
* The "show all processes" and "show locks" options work fine

The performance overhead of this is pretty small, but it may take a while to load if your server is under heavy use. The "show all processes" option can also be a little slow as it pulls back a lot of info. 