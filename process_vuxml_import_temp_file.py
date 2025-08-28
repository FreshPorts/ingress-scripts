#!/usr/local/bin/python

# take a file and load it into a temp table.


import psycopg2
import psycopg2.extras
import configparser # for config.ini parsing
import re           # for escaping the database passwords
import syslog       # for logging
import sys
import getopt

import os




def main(argv):
   inputfile = ''
   try:
      opts, args = getopt.getopt(argv,"hi:o:",["ifile="])
   except getopt.GetoptError:
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
         print (__file__  + ' -i <inputfile>')
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg


   syslog.syslog(syslog.LOG_NOTICE, 'copying in from ' + inputfile)

   config = configparser.ConfigParser()
   config.read('/usr/local/etc/freshports/config.ini')


   DSN = 'host=' + config['database']['HOST'] + ' dbname=' + config['database']['DBNAME'] + ' user=' + config['database']['COMMITS_DBUSER'] + ' password=' + re.escape(config['database']['COMMITS_PASSWORD']) + ' sslcertmode=disable sslmode=require'


   dbh = psycopg2.connect(DSN)
   curs = dbh.cursor(cursor_factory=psycopg2.extras.DictCursor)

#
# someone else does the truncate: no, it's a delete. See PackagesRawDeleteForABIPackageSet() in sp.txt
# It is invoked by UpdatePackagesFromRawPackages() on a ABI/set basis.
#
   curs.execute("select freshports_branch_set('head')")
   with open(inputfile, 'r') as f:
      curs.copy_from(f, 'vuxml_import', sep = '\t', columns = ['vid', 'checksum'] )

   row_count = curs.rowcount
   dbh.commit()
   dbh.close();
   syslog.syslog(syslog.LOG_NOTICE, 'copying completed. %d rows copied.' % row_count)
   
   return row_count

syslog.openlog(ident=os.path.basename(__file__), facility=syslog.LOG_LOCAL3)
syslog.syslog(syslog.LOG_NOTICE, 'Starting up')

if __name__ == "__main__":
   row_count = main(sys.argv[1:])

syslog.syslog(syslog.LOG_NOTICE, 'Finishing')

print ('COPY %d' % row_count)
