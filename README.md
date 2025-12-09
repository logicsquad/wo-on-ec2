[![License](https://img.shields.io/badge/License-BSD-blue.svg)](https://opensource.org/licenses/BSD-2-Clause)

WO-on-EC2
=========

What is this?
-------------
These are a minimal set of shell scripts and resources to set up a
WebObjects appserver on an EC2 instance running Amazon Linux 2023.

Getting started
---------------
1. Launch an EC2 instance running Amazon Linux 2023 64-bit on x86.
2. Clone this repository.
3. Run `make-appserver.sh` supplying the local path to your PEM key
   and the hostname of the instance:

        make-appserver.sh -i ~/some.pem -h ec2-3-45-6-78.ap-southeast-2.compute.amazonaws.com

4. The `appserver-setup.sh` script and the contents of `artefacts`
   will be uploaded to the instance, and `appserver-setup.sh` will
   run.
5. On completion, wotaskd and JavaMonitor will be running, and you can
   log in to confirm this:

        ssh -i ~/some.pem -L 56789:localhost:56789 ec2-user@ec2-3-45-6-78.ap-southeast-2.compute.amazonaws.com

   The `-L` option creates a tunnel from port 56789 on your local machine
   to _the EC2 instance's_ `localhost`—that is, _itself_.
   
6. Open a browser _on your local machine_ and navigate to
   `http://localhost:56789/`. (This tunnels from port 56789 on your
   local machine, via SSH to port 56789 on the EC2 instance, where
   JavaMonitor will be listening.)
7. You will still need to set up Apache: see the `ssl.conf.proto` and
   `vhosts.conf.proto` files for further information: make appropriate
   changes and restart Apache with `systemctl restart httpd.service`.

Remaining steps
---------------
At the end of the section above, all you have is a WebObjects
appserver with Apache. You still need to:

* Set up the database layer. Adding PostgreSQL to the same instance is
  fairly straightforward, and then you'll have a hybrid application-,
  web- and database-server all in one. Similarly, connecting to RDS
  only requires a few additional steps.
* Create a mechanism to install your applications in
  `/opt/WOApplications/`. This is highly dependent on your continuous
  integration or other build process. For example, you might fetch the
  application and webserver-resources bundle from a Maven repository,
  and unpack those into the appropriate places.

Questions
---------
* _Why is there a binary `mod_WebObjects.so` in `artefacts`?_ Because
  you either need to compile it on the fly during installation, which
  would add a lot of steps and potential for breakage, or you download
  it from somewhere, in which case it may as well be in this
  repo. This binary was compiled on Amazon Linux (64-bit x86) in 2022,
  and _includes_ [a security fix made in August
  2022](https://github.com/wocommunity/wonder/pull/992).

Contributing
------------
By all means, open issue tickets and pull requests if you have
something to contribute.

Credit
------
This work is (now fairly loosely) based on a script by Simon McLean,
posted to the WebObjects Development mailing list
(`webobjects-dev@lists.apple.com`) in 2010, and assumed to be in the
public domain.
