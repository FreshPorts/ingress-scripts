#
# $Id: README.txt,v 1.4 2006-12-17 12:03:58 dan Exp $
#
#
# Copyright (c) 2001-2003 DVL Software
#
When installing the scripts, be sure to modify the "use lib" entry
in load_xml_into_db.pl to point to the directory in which 
load_xml_into_db.pl resides.

The following packages are needed to run these scripts:

# We no longer use File-PathConvert.  We use Cwd instead.
# And as of 2013.08.28 we started used realpath(1) instead.
#
#http://search.cpan.org/search?dist=File-PathConvert
#http://www.cpan.org/authors/id/R/RB/RBS/File-PathConvert-0.85.tar.gz

textproc/p5-XML-Node
http://search.cpan.org/search?dist=XML-Node
http://www.cpan.org/authors/id/C/CH/CHANG-LIU/XML-Node-0.10.tar.gz

textproc/p5-XML-Writer
http://search.cpan.org/search?dist=XML-Writer
http://www.cpan.org/authors/id/DMEGG/XML-Writer-0.4.tar.gz

mail/p5-Mail-Sender

adjust this line in load_xml_into_db.pl:
use lib '/home/lists/scripts';



And you also need to run procmail/create_dirs.sh


If you need to add an archive contents to FreshPorts, you can start
with this:

Create this file

$ less file.sh
#!/bin/sh

cat > tmp/2003.10.17.DNS.problems.${FILENO}.txt.raw



Then do this:
cat cvs-ports+archive | formail -s ./file.sh

Then copy the files over to the incoming queue.
